import Foundation
import Testing
@testable import TypeFree

@MainActor
struct DictationWorkflowActorTests {
    @Test
    func providerUnavailableReadinessShowsVisibleProviderFailureWithoutStartingCapture() async throws {
        let hudPresenter = IntegrationTestHUDPresenter(activationScreenID: "screen-a")
        let captureDriver = WorkflowTestCaptureDriver()
        let transcriptionDriver = WorkflowTestTranscriptionDriver()
        let clock = IntegrationTestWorkflowClock()
        let workflow = DictationWorkflowActor(
            hudPresenter: hudPresenter,
            tentativeCaptureDriver: captureDriver,
            transcriptionDriver: transcriptionDriver,
            clock: clock,
            readinessProvider: { .providerUnavailable }
        )

        await workflow.handle(.hotkeyDown(timestamp: 1.0))

        #expect(await captureDriver.startedCount() == 0)
        #expect(
            hudPresenter.presentedStates == [
                .providerFailed(
                    .configuration(
                        detail: "Check the Endpoint URL, model identifier, and API key in Provider settings."
                    )
                ),
            ]
        )
        #expect(hudPresenter.hideCallCount == 0)

        await clock.resumeNext()
        let resetCompleted = await eventually {
            await MainActor.run { hudPresenter.hideCallCount == 1 }
        }

        try #require(resetCompleted)
    }

    @Test
    func noSpeechOutcomeStaysVisibleUntilReset() async throws {
        let hudPresenter = IntegrationTestHUDPresenter(activationScreenID: "screen-a")
        let captureDriver = WorkflowTestCaptureDriver()
        let transcriptionDriver = WorkflowTestTranscriptionDriver(result: .success(.noSpeech))
        let clock = IntegrationTestWorkflowClock()
        let workflow = DictationWorkflowActor(
            hudPresenter: hudPresenter,
            tentativeCaptureDriver: captureDriver,
            transcriptionDriver: transcriptionDriver,
            clock: clock,
            readinessProvider: { .ready }
        )

        await workflow.handle(.hotkeyDown(timestamp: 1.0))
        await workflow.handle(.hotkeyUp(timestamp: 1.1))
        let reachedNoSpeechState = await eventually {
            await MainActor.run { hudPresenter.presentedStates.last == .noSpeech }
        }

        try #require(reachedNoSpeechState)

        #expect(hudPresenter.presentedStates == [.transcribing, .noSpeech])
        #expect(hudPresenter.hideCallCount == 0)

        await clock.resumeNext()
        let resetCompleted = await eventually {
            await MainActor.run { hudPresenter.hideCallCount == 1 }
        }

        try #require(resetCompleted)
    }

    @Test
    func providerErrorsMapToVisibleProviderFailure() async throws {
        let hudPresenter = IntegrationTestHUDPresenter(activationScreenID: "screen-a")
        let captureDriver = WorkflowTestCaptureDriver()
        let transcriptionDriver = WorkflowTestTranscriptionDriver(
            result: .success(
                .providerFailed(
                    .timeout(detail: "The request timed out. Check the service status and network connection.")
                )
            )
        )
        let clock = IntegrationTestWorkflowClock()
        let workflow = DictationWorkflowActor(
            hudPresenter: hudPresenter,
            tentativeCaptureDriver: captureDriver,
            transcriptionDriver: transcriptionDriver,
            clock: clock,
            readinessProvider: { .ready }
        )

        await workflow.handle(.hotkeyDown(timestamp: 1.0))
        await workflow.handle(.hotkeyUp(timestamp: 1.1))
        let reachedProviderFailed = await eventually {
            await MainActor.run { hudPresenter.presentedStates.count >= 2 }
        }
        try #require(reachedProviderFailed)
        #expect(
            hudPresenter.presentedStates == [
                .transcribing,
                .providerFailed(
                    .timeout(detail: "The request timed out. Check the service status and network connection.")
                ),
            ]
        )
        #expect(hudPresenter.hideCallCount == 0)

        await clock.resumeNext()
        let resetCompleted = await eventually {
            await MainActor.run { hudPresenter.hideCallCount == 1 }
        }

        try #require(resetCompleted)
    }

    @Test
    func insertionFailureOutcomeRemainsVisibleUntilReset() async throws {
        let hudPresenter = IntegrationTestHUDPresenter(activationScreenID: "screen-a")
        let captureDriver = WorkflowTestCaptureDriver()
        let transcriptionDriver = WorkflowTestTranscriptionDriver(
            result: .success(.insertionFailed(.targetNotEditable))
        )
        let clock = IntegrationTestWorkflowClock()
        let workflow = DictationWorkflowActor(
            hudPresenter: hudPresenter,
            tentativeCaptureDriver: captureDriver,
            transcriptionDriver: transcriptionDriver,
            clock: clock,
            readinessProvider: { .ready }
        )

        await workflow.handle(.hotkeyDown(timestamp: 1.0))
        await workflow.handle(.hotkeyUp(timestamp: 1.1))
        let reachedInsertionFailed = await eventually {
            await MainActor.run { hudPresenter.presentedStates.count >= 2 }
        }
        try #require(reachedInsertionFailed)
        #expect(hudPresenter.presentedStates == [.transcribing, .insertionFailed(.targetNotEditable)])
        #expect(hudPresenter.hideCallCount == 0)

        await clock.resumeNext()
        let resetCompleted = await eventually {
            await MainActor.run { hudPresenter.hideCallCount == 1 }
        }

        try #require(resetCompleted)
    }

    @Test
    func doublePressDuringTranscriptionStaysCanceledUntilReset() async throws {
        let hudPresenter = IntegrationTestHUDPresenter(activationScreenID: "screen-a")
        let captureDriver = WorkflowTestCaptureDriver()
        let transcriptionDriver = BlockingWorkflowTestTranscriptionDriver()
        let clock = IntegrationTestWorkflowClock()
        let workflow = DictationWorkflowActor(
            hudPresenter: hudPresenter,
            tentativeCaptureDriver: captureDriver,
            transcriptionDriver: transcriptionDriver,
            clock: clock,
            readinessProvider: { .ready }
        )

        await workflow.handle(.hotkeyDown(timestamp: 1.0))
        await workflow.handle(.hotkeyUp(timestamp: 1.1))
        let reachedTranscribing = await eventually {
            await MainActor.run { hudPresenter.presentedStates.contains(.transcribing) }
        }
        try #require(reachedTranscribing)
        await workflow.handle(.doublePress(timestamp: 1.2))
        let reachedCanceled = await eventually {
            await MainActor.run { hudPresenter.presentedStates.last == .canceled }
        }
        try #require(reachedCanceled)
        #expect(await transcriptionDriver.cancellationCount() == 1)
        #expect(hudPresenter.presentedStates == [.transcribing, .canceled])
        #expect(hudPresenter.hideCallCount == 0)

        await clock.resumeNext()
        let resetCompleted = await eventually {
            await MainActor.run { hudPresenter.hideCallCount == 1 }
        }

        try #require(resetCompleted)
    }
}

private actor WorkflowTestCaptureDriver: TentativeCaptureDriving {
    private var startedSessionIDs: [UUID] = []

    func startTentativeCapture(sessionID: UUID, activationScreenID: String) async throws(TentativeCaptureError) {
        _ = activationScreenID
        startedSessionIDs.append(sessionID)
    }

    func finishTentativeCapture(sessionID: UUID) async throws(TentativeCaptureError) -> PreparedCapture {
        PreparedCapture(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("\(sessionID).wav"),
            duration: 0.5,
            sampleRate: 16000,
            channelCount: 1,
            activationScreenID: "screen-a"
        )
    }

    func cancelTentativeCapture(sessionID _: UUID) async {}

    func startedCount() -> Int {
        startedSessionIDs.count
    }
}

private actor WorkflowTestTranscriptionDriver: TranscriptionDriving {
    private let result: Result<SessionOutcome, any Error>

    init(result: Result<SessionOutcome, any Error> = .success(.completed(text: "ignored"))) {
        self.result = result
    }

    func startTranscribing(sessionID _: UUID, capture _: PreparedCapture) async throws -> SessionOutcome {
        try result.get()
    }
}

private actor BlockingWorkflowTestTranscriptionDriver: TranscriptionDriving {
    private var cancelCount = 0
    private var continuation: CheckedContinuation<SessionOutcome, Error>?

    func startTranscribing(sessionID _: UUID, capture _: PreparedCapture) async throws -> SessionOutcome {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        } onCancel: {
            Task {
                await self.cancelPendingRequest()
            }
        }
    }

    func cancellationCount() -> Int {
        cancelCount
    }

    private func cancelPendingRequest() {
        guard let continuation else {
            return
        }

        cancelCount += 1
        self.continuation = nil
        continuation.resume(throwing: CancellationError())
    }
}
