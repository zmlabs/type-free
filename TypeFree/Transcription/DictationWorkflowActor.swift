import Foundation

enum DictationWorkflowReadiness {
    case ready
    case permissionBlocked
    case audioInputUnavailable
    case providerUnavailable
}

actor DictationWorkflowActor {
    private let hudPresenter: any HUDPresenting
    private let tentativeCaptureDriver: any TentativeCaptureDriving
    private let transcriptionDriver: any TranscriptionDriving
    private let clock: any WorkflowClock
    private let readinessProvider: @MainActor @Sendable () async -> DictationWorkflowReadiness
    private let phaseObserver: @MainActor @Sendable (DictationPhase) async -> Void

    private var stateMachine = DictationStateMachine()
    private var preparedCapture: (sessionID: UUID, capture: PreparedCapture)?
    private var hudDelayTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?

    init(
        hudPresenter: any HUDPresenting,
        tentativeCaptureDriver: any TentativeCaptureDriving,
        transcriptionDriver: any TranscriptionDriving,
        clock: any WorkflowClock,
        readinessProvider: @escaping @MainActor @Sendable () async -> DictationWorkflowReadiness = { .ready },
        phaseObserver: @escaping @MainActor @Sendable (DictationPhase) async -> Void = { _ in }
    ) {
        self.hudPresenter = hudPresenter
        self.tentativeCaptureDriver = tentativeCaptureDriver
        self.transcriptionDriver = transcriptionDriver
        self.clock = clock
        self.readinessProvider = readinessProvider
        self.phaseObserver = phaseObserver
    }

    func handle(_ action: GlobalHotkeyAction) async {
        switch action {
        case let .hotkeyDown(timestamp):
            let activationScreenID = await hudPresenter.activationScreenID()
            let readiness = await readinessProvider()

            switch readiness {
            case .ready:
                await process(.hotkeyDown(timestamp: timestamp, activationScreenID: activationScreenID))
            case .permissionBlocked:
                await process(.startRejected(activationScreenID: activationScreenID, outcome: .permissionBlocked))
            case .audioInputUnavailable:
                await process(
                    .startRejected(
                        activationScreenID: activationScreenID,
                        outcome: .audioInputUnavailable
                    )
                )
            case .providerUnavailable:
                await process(
                    .startRejected(
                        activationScreenID: activationScreenID,
                        outcome: .providerFailed(
                            .configuration(detail: "请在 Provider 设置中检查 Endpoint URL、模型标识和 API Key。")
                        )
                    )
                )
            }
        case let .hotkeyUp(timestamp):
            await process(.hotkeyUp(timestamp: timestamp))
        case let .otherKeyWhileHeld(timestamp):
            await process(.otherKeyWhileHeld(timestamp: timestamp))
        case let .doublePress(timestamp):
            await process(.doublePress(timestamp: timestamp))
        }
    }

    private func process(_ event: DictationStateMachineEvent) async {
        let previousPhase = stateMachine.phase
        let commands = stateMachine.handle(event)

        if previousPhase != stateMachine.phase {
            await phaseObserver(stateMachine.phase)
        }

        await execute(commands)
    }

    private func execute(_ commands: [DictationStateMachineCommand]) async {
        for command in commands {
            let shouldContinue = await execute(command)
            guard shouldContinue else {
                break
            }
        }
    }

    private func execute(_ command: DictationStateMachineCommand) async -> Bool {
        switch command {
        case let .startTentativeCapture(sessionID, activationScreenID):
            return await executeStartTentativeCapture(sessionID: sessionID, activationScreenID: activationScreenID)
        case let .scheduleHUDDelay(sessionID, delay):
            await scheduleHUDDelay(sessionID: sessionID, delay: delay)
        case let .showHUD(state, sessionID, activationScreenID):
            await hudPresenter.present(state: state, sessionID: sessionID, activationScreenID: activationScreenID)
            if let delay = state.autoDismissDelay {
                await scheduleReset(sessionID: sessionID, delay: delay)
            }
        case let .finishTentativeCapture(sessionID):
            return await executeFinishTentativeCapture(sessionID: sessionID)
        case let .beginTranscribing(sessionID):
            await startTranscriptionTask(sessionID: sessionID)
        case let .cancelTentativeCapture(sessionID, _):
            await executeCancelTentativeCapture(sessionID: sessionID)
        case let .cancelTranscribing(sessionID):
            await cancelTranscriptionTask(sessionID: sessionID)
        case .hideHUD:
            await hudPresenter.hide()
        }

        return true
    }

    private func executeStartTentativeCapture(
        sessionID: UUID,
        activationScreenID: String
    ) async -> Bool {
        await cancelResetTask()

        do {
            try await tentativeCaptureDriver.startTentativeCapture(
                sessionID: sessionID,
                activationScreenID: activationScreenID
            )
            return true
        } catch {
            await cancelHUDDelayTask()
            let outcome: SessionOutcome = switch error {
            case .permissionDenied:
                .permissionBlocked
            case .engineFailure, .writerFailure:
                .providerFailed(.unavailable())
            }
            await process(.terminalOutcome(sessionID: sessionID, outcome: outcome))
            return false
        }
    }

    private func executeFinishTentativeCapture(sessionID: UUID) async -> Bool {
        await cancelHUDDelayTask()

        do {
            let capture = try await tentativeCaptureDriver.finishTentativeCapture(sessionID: sessionID)
            preparedCapture = (sessionID: sessionID, capture: capture)
            return true
        } catch {
            let outcome: SessionOutcome = switch error {
            case .permissionDenied:
                .permissionBlocked
            case .engineFailure, .writerFailure:
                .providerFailed(.unavailable())
            }
            await process(.terminalOutcome(sessionID: sessionID, outcome: outcome))
            return false
        }
    }

    private func executeCancelTentativeCapture(sessionID: UUID) async {
        await cancelHUDDelayTask()
        await tentativeCaptureDriver.cancelTentativeCapture(sessionID: sessionID)
        await discardPreparedCapture(sessionID: sessionID)
    }

    private func startTranscriptionTask(sessionID: UUID) async {
        guard let entry = preparedCapture, entry.sessionID == sessionID else {
            await process(.terminalOutcome(sessionID: sessionID, outcome: .providerFailed(.unavailable())))
            return
        }
        let preparedCapture = entry.capture

        transcriptionTask?.cancel()
        transcriptionTask = Task {
            do {
                let outcome = try await transcriptionDriver.startTranscribing(
                    sessionID: sessionID,
                    capture: preparedCapture
                )
                await self.handleTranscriptionOutcome(outcome, sessionID: sessionID)
            } catch is CancellationError {
                await self.discardPreparedCapture(sessionID: sessionID)
            } catch {
                await self.handleTranscriptionOutcome(
                    .providerFailed(.unavailable()),
                    sessionID: sessionID
                )
            }
        }
    }

    private func handleTranscriptionOutcome(
        _ outcome: SessionOutcome,
        sessionID: UUID
    ) async {
        transcriptionTask = nil
        await discardPreparedCapture(sessionID: sessionID)
        await process(.terminalOutcome(sessionID: sessionID, outcome: outcome))
    }

    private func cancelTranscriptionTask(sessionID: UUID) async {
        if let transcriptionTask {
            transcriptionTask.cancel()
            _ = await transcriptionTask.result
        }

        transcriptionTask = nil
        await discardPreparedCapture(sessionID: sessionID)
    }
}

private extension DictationWorkflowActor {
    func scheduleHUDDelay(sessionID: UUID, delay: Duration) async {
        await cancelHUDDelayTask()
        hudDelayTask = Task { [clock] in
            do {
                try await clock.sleep(for: delay)
                await self.hudDelayDidElapse(sessionID: sessionID)
            } catch is CancellationError {
            } catch {}
        }
    }

    func scheduleReset(sessionID: UUID, delay: Duration) async {
        await cancelResetTask()
        resetTask = Task { [clock] in
            do {
                try await clock.sleep(for: delay)
                await self.resetDelayDidElapse(sessionID: sessionID)
            } catch is CancellationError {
            } catch {}
        }
    }

    func hudDelayDidElapse(sessionID: UUID) async {
        hudDelayTask = nil
        await process(.hudDelayElapsed(sessionID: sessionID))
    }

    func resetDelayDidElapse(sessionID: UUID) async {
        resetTask = nil
        await process(.reset(sessionID: sessionID))
    }

    func cancelHUDDelayTask() async {
        guard let hudDelayTask else {
            return
        }

        hudDelayTask.cancel()
        _ = await hudDelayTask.result
        self.hudDelayTask = nil
    }

    func cancelResetTask() async {
        guard let resetTask else {
            return
        }

        resetTask.cancel()
        _ = await resetTask.result
        self.resetTask = nil
    }

    func discardPreparedCapture(sessionID: UUID) async {
        guard let entry = preparedCapture, entry.sessionID == sessionID else {
            return
        }

        preparedCapture = nil
        try? FileManager.default.removeItem(at: entry.capture.fileURL)
    }
}
