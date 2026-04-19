import Foundation
import Testing
@testable import TypeFree

@MainActor
struct DictationWorkflowContractTests {
    @Test
    func hotkeyDownStartsTentativeCaptureImmediatelyAndShowsRecordingHUDAfterDelay() async throws {
        let hudPresenter = TestHUDPresenter(activationScreenID: "screen-a")
        let captureDriver = TestTentativeCaptureDriver()
        let transcriptionDriver = TestTranscriptionDriver()
        let clock = TestWorkflowClock()
        let workflow = DictationWorkflowActor(
            hudPresenter: hudPresenter,
            tentativeCaptureDriver: captureDriver,
            transcriptionDriver: transcriptionDriver,
            clock: clock,
            readinessProvider: { .ready }
        )

        await workflow.handle(.hotkeyDown(timestamp: 1.0))

        #expect(await captureDriver.startedCount() == 1)
        let delayScheduled = await eventually {
            await clock.recordedDurations() == [.milliseconds(150)]
        }
        try #require(delayScheduled)
        #expect(hudPresenter.presentedStates.isEmpty)

        await clock.resumeNext()
        let reachedRecording = await eventually {
            await MainActor.run { hudPresenter.presentedStates == [.recording] }
        }
        try #require(reachedRecording)
        #expect(await captureDriver.recordedActivationScreenIDs() == ["screen-a"])
    }

    @Test
    func hotkeyUpBeforeDelayTransitionsDirectlyToTranscribingAndCancelsThePendingRecordingHUD() async {
        let hudPresenter = TestHUDPresenter(activationScreenID: "screen-a")
        let captureDriver = TestTentativeCaptureDriver()
        let transcriptionDriver = TestTranscriptionDriver()
        let clock = TestWorkflowClock()
        let workflow = DictationWorkflowActor(
            hudPresenter: hudPresenter,
            tentativeCaptureDriver: captureDriver,
            transcriptionDriver: transcriptionDriver,
            clock: clock,
            readinessProvider: { .ready }
        )

        await workflow.handle(.hotkeyDown(timestamp: 1.0))
        await workflow.handle(.hotkeyUp(timestamp: 1.05))

        #expect(await captureDriver.finishedCount() == 1)
        #expect(await transcriptionDriver.startedCount() == 1)
        #expect(await clock.pendingCount() == 0)
        #expect(hudPresenter.presentedStates == [.transcribing])
    }

    @Test
    func chordCancellationHidesTheHUDAndReturnsToIdle() async {
        let hudPresenter = TestHUDPresenter(activationScreenID: "screen-a")
        let captureDriver = TestTentativeCaptureDriver()
        let transcriptionDriver = TestTranscriptionDriver()
        let clock = TestWorkflowClock()
        let workflow = DictationWorkflowActor(
            hudPresenter: hudPresenter,
            tentativeCaptureDriver: captureDriver,
            transcriptionDriver: transcriptionDriver,
            clock: clock,
            readinessProvider: { .ready }
        )

        await workflow.handle(.hotkeyDown(timestamp: 1.0))

        #expect(await captureDriver.startedCount() == 1)

        await workflow.handle(.otherKeyWhileHeld(timestamp: 1.05))

        #expect(await captureDriver.canceledCount() == 1)
        #expect(await clock.pendingCount() == 0)
        #expect(hudPresenter.presentedStates.isEmpty)
        #expect(hudPresenter.hideCallCount == 1)
    }

    @Test
    func doublePressCancelsTranscribingAndShowsCanceledFeedback() async throws {
        let hudPresenter = TestHUDPresenter(activationScreenID: "screen-a")
        let captureDriver = TestTentativeCaptureDriver()
        let transcriptionDriver = TestTranscriptionDriver()
        let clock = TestWorkflowClock()
        let workflow = DictationWorkflowActor(
            hudPresenter: hudPresenter,
            tentativeCaptureDriver: captureDriver,
            transcriptionDriver: transcriptionDriver,
            clock: clock,
            readinessProvider: { .ready }
        )

        await workflow.handle(.hotkeyDown(timestamp: 1.0))
        await workflow.handle(.hotkeyUp(timestamp: 1.05))
        let reachedTranscribing = await eventually {
            await MainActor.run { hudPresenter.presentedStates.contains(.transcribing) }
        }
        try #require(reachedTranscribing)
        await workflow.handle(.doublePress(timestamp: 1.2))
        let reachedCanceled = await eventually {
            await MainActor.run { hudPresenter.presentedStates.count >= 2 }
        }
        try #require(reachedCanceled)
        #expect(hudPresenter.presentedStates == [.transcribing, .canceled])
        #expect(await clock.recordedDurations() == [.milliseconds(150), .milliseconds(600)])

        await clock.resumeNext()
        let reachedIdle = await eventually {
            await MainActor.run { hudPresenter.hideCallCount == 1 }
        }
        try #require(reachedIdle)
    }

    @Test
    func blockedReadinessShowsVisibleFeedbackWithoutStartingCapture() async throws {
        let hudPresenter = TestHUDPresenter(activationScreenID: "screen-a")
        let captureDriver = TestTentativeCaptureDriver()
        let transcriptionDriver = TestTranscriptionDriver()
        let clock = TestWorkflowClock()
        let workflow = DictationWorkflowActor(
            hudPresenter: hudPresenter,
            tentativeCaptureDriver: captureDriver,
            transcriptionDriver: transcriptionDriver,
            clock: clock,
            readinessProvider: { .permissionBlocked }
        )

        await workflow.handle(.hotkeyDown(timestamp: 1.0))

        #expect(await captureDriver.startedCount() == 0)
        #expect(hudPresenter.presentedStates == [.permissionBlocked])
        #expect(await clock.recordedDurations() == [.seconds(3)])

        await clock.resumeNext()
        let reachedIdle = await eventually {
            await MainActor.run { hudPresenter.hideCallCount == 1 }
        }
        try #require(reachedIdle)
    }
}

private actor TestTentativeCaptureDriver: TentativeCaptureDriving {
    private var startedSessionIDs: [UUID] = []
    private var startedActivationScreenIDs: [String] = []
    private var finishedSessionIDs: [UUID] = []
    private var canceledSessionIDs: [UUID] = []

    func startTentativeCapture(sessionID: UUID, activationScreenID: String) async throws(TentativeCaptureError) {
        startedSessionIDs.append(sessionID)
        startedActivationScreenIDs.append(activationScreenID)
    }

    func finishTentativeCapture(sessionID: UUID) async throws(TentativeCaptureError) -> PreparedCapture {
        finishedSessionIDs.append(sessionID)
        return PreparedCapture(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("capture-\(sessionID).wav"),
            duration: 0.5,
            sampleRate: 16000,
            channelCount: 1,
            activationScreenID: startedActivationScreenIDs.last ?? "screen-a"
        )
    }

    func cancelTentativeCapture(sessionID: UUID) async {
        canceledSessionIDs.append(sessionID)
    }

    func startedCount() -> Int {
        startedSessionIDs.count
    }

    func recordedActivationScreenIDs() -> [String] {
        startedActivationScreenIDs
    }

    func finishedCount() -> Int {
        finishedSessionIDs.count
    }

    func canceledCount() -> Int {
        canceledSessionIDs.count
    }
}

private actor TestTranscriptionDriver: TranscriptionDriving {
    private var startedSessionIDs: [UUID] = []
    private var pendingContinuations: [CheckedContinuation<SessionOutcome, Error>] = []

    func startTranscribing(sessionID: UUID, capture _: PreparedCapture) async throws -> SessionOutcome {
        startedSessionIDs.append(sessionID)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pendingContinuations.append(continuation)
            }
        } onCancel: {
            Task { await self.cancelAllPending() }
        }
    }

    private func cancelAllPending() {
        while !pendingContinuations.isEmpty {
            pendingContinuations.removeFirst().resume(throwing: CancellationError())
        }
    }

    func startedCount() -> Int {
        startedSessionIDs.count
    }
}

private actor TestWorkflowClock: WorkflowClock {
    private struct PendingSleep {
        let id: UUID
        let duration: Duration
        let continuation: CheckedContinuation<Void, Error>
    }

    private var pendingSleeps: [PendingSleep] = []
    private var requested: [Duration] = []

    func sleep(for duration: Duration) async throws {
        let sleepID = UUID()
        requested.append(duration)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pendingSleeps.append(
                    PendingSleep(id: sleepID, duration: duration, continuation: continuation)
                )
            }
        } onCancel: {
            Task {
                await self.cancelSleep(id: sleepID)
            }
        }
    }

    func recordedDurations() -> [Duration] {
        requested
    }

    func pendingCount() -> Int {
        pendingSleeps.count
    }

    func resumeNext() async {
        while pendingSleeps.isEmpty {
            await Task.yield()
        }

        let sleep = pendingSleeps.removeFirst()
        sleep.continuation.resume()

        for _ in 0 ..< 10 {
            await Task.yield()
        }
    }

    private func cancelSleep(id: UUID) {
        guard let index = pendingSleeps.firstIndex(where: { $0.id == id }) else {
            return
        }

        let continuation = pendingSleeps.remove(at: index).continuation
        continuation.resume(throwing: CancellationError())
    }
}
