import Foundation

enum HUDCancellationPresentation: Equatable {
    case hidden
    case canceled
}

enum DictationStateMachineEvent: Equatable {
    case hotkeyDown(timestamp: TimeInterval, activationScreenID: String)
    case startRejected(activationScreenID: String, outcome: SessionOutcome)
    case hudDelayElapsed(sessionID: UUID)
    case hotkeyUp(timestamp: TimeInterval)
    case otherKeyWhileHeld(timestamp: TimeInterval)
    case doublePress(timestamp: TimeInterval)
    case terminalOutcome(sessionID: UUID, outcome: SessionOutcome)
    case reset(sessionID: UUID)
}

enum DictationStateMachineCommand: Equatable {
    case startTentativeCapture(sessionID: UUID, activationScreenID: String)
    case scheduleHUDDelay(sessionID: UUID, delay: Duration)
    case showHUD(state: HUDState, sessionID: UUID, activationScreenID: String)
    case finishTentativeCapture(sessionID: UUID)
    case beginTranscribing(sessionID: UUID)
    case cancelTentativeCapture(sessionID: UUID, presentation: HUDCancellationPresentation)
    case cancelTranscribing(sessionID: UUID)
    case hideHUD
}

struct DictationStateMachine {
    private(set) var phase: DictationPhase = .idle
    private(set) var activeSessionID: UUID?

    private var activationScreenID: String?

    nonisolated mutating func handle(
        _ event: DictationStateMachineEvent
    ) -> [DictationStateMachineCommand] {
        switch event {
        case let .hotkeyDown(_, activationScreenID):
            handleHotkeyDown(activationScreenID: activationScreenID)
        case let .startRejected(activationScreenID, outcome):
            handleStartRejected(activationScreenID: activationScreenID, outcome: outcome)
        case let .hudDelayElapsed(sessionID):
            handleHUDDelayElapsed(sessionID: sessionID)
        case .hotkeyUp:
            handleHotkeyUp()
        case .otherKeyWhileHeld:
            handleOtherKeyWhileHeld()
        case .doublePress:
            handleDoublePress()
        case let .terminalOutcome(sessionID, outcome):
            handleTerminalOutcome(sessionID: sessionID, outcome: outcome)
        case let .reset(sessionID):
            handleReset(sessionID: sessionID)
        }
    }

    nonisolated mutating func handleHotkeyDown(
        activationScreenID: String
    ) -> [DictationStateMachineCommand] {
        guard phase == .idle else {
            return []
        }

        let sessionID = UUID()
        activeSessionID = sessionID
        phase = .tentativeCapture
        self.activationScreenID = activationScreenID

        return [
            .startTentativeCapture(sessionID: sessionID, activationScreenID: activationScreenID),
            .scheduleHUDDelay(sessionID: sessionID, delay: .milliseconds(150)),
        ]
    }

    nonisolated mutating func handleStartRejected(
        activationScreenID: String,
        outcome: SessionOutcome
    ) -> [DictationStateMachineCommand] {
        guard phase == .idle,
              let hudState = outcome.workflowHUDState
        else {
            return []
        }

        let sessionID = UUID()
        activeSessionID = sessionID
        self.activationScreenID = activationScreenID
        phase = outcome.workflowPhase

        return [
            .showHUD(state: hudState, sessionID: sessionID, activationScreenID: activationScreenID),
        ]
    }

    nonisolated mutating func handleHUDDelayElapsed(
        sessionID: UUID
    ) -> [DictationStateMachineCommand] {
        guard phase == .tentativeCapture,
              activeSessionID == sessionID,
              let activationScreenID
        else {
            return []
        }

        phase = .recordingVisible
        return [
            .showHUD(state: .recording, sessionID: sessionID, activationScreenID: activationScreenID),
        ]
    }

    nonisolated mutating func handleHotkeyUp() -> [DictationStateMachineCommand] {
        guard let sessionID = activeSessionID,
              let activationScreenID,
              phase == .tentativeCapture || phase == .recordingVisible
        else {
            return []
        }

        phase = .transcribing
        return [
            .finishTentativeCapture(sessionID: sessionID),
            .showHUD(state: .transcribing, sessionID: sessionID, activationScreenID: activationScreenID),
            .beginTranscribing(sessionID: sessionID),
        ]
    }

    nonisolated mutating func handleOtherKeyWhileHeld() -> [DictationStateMachineCommand] {
        guard let sessionID = activeSessionID,
              phase == .tentativeCapture || phase == .recordingVisible
        else {
            return []
        }

        clearSession()
        return [
            .cancelTentativeCapture(sessionID: sessionID, presentation: .hidden),
            .hideHUD,
        ]
    }

    nonisolated mutating func handleDoublePress() -> [DictationStateMachineCommand] {
        guard let sessionID = activeSessionID,
              let activationScreenID
        else {
            return []
        }

        switch phase {
        case .tentativeCapture, .recordingVisible:
            phase = .canceled
            return [
                .cancelTentativeCapture(sessionID: sessionID, presentation: .canceled),
                .showHUD(state: .canceled, sessionID: sessionID, activationScreenID: activationScreenID),
            ]
        case .transcribing:
            phase = .canceled
            return [
                .cancelTranscribing(sessionID: sessionID),
                .showHUD(state: .canceled, sessionID: sessionID, activationScreenID: activationScreenID),
            ]
        default:
            return []
        }
    }

    nonisolated mutating func handleReset(
        sessionID: UUID
    ) -> [DictationStateMachineCommand] {
        guard activeSessionID == sessionID, shouldReset(phase: phase) else {
            return []
        }

        clearSession()
        phase = .idle
        return [.hideHUD]
    }

    nonisolated mutating func handleTerminalOutcome(
        sessionID: UUID,
        outcome: SessionOutcome
    ) -> [DictationStateMachineCommand] {
        guard activeSessionID == sessionID,
              canHandleTerminalOutcome(outcome),
              let activationScreenID
        else {
            return []
        }

        switch outcome {
        case .completed:
            clearSession()
            phase = .idle
            return [.hideHUD]
        default:
            guard let hudState = outcome.workflowHUDState else {
                return []
            }

            phase = outcome.workflowPhase
            return [
                .showHUD(state: hudState, sessionID: sessionID, activationScreenID: activationScreenID),
            ]
        }
    }

    nonisolated mutating func clearSession() {
        activeSessionID = nil
        activationScreenID = nil
        phase = .idle
    }
}
