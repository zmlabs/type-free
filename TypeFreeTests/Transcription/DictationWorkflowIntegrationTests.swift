import Foundation
import Testing
@testable import TypeFree

@MainActor
struct DictationWorkflowIntegrationTests {
    @Test
    func endToEndReleaseTranscribesAndForwardsTextToInserter() async throws {
        let hudPresenter = IntegrationTestHUDPresenter(activationScreenID: "screen-a")
        let audioService = TestAudioCaptureService(
            preparedCapture: .fixture(
                activationScreenID: "screen-a",
                fileURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("success-capture.wav")
            )
        )
        let provider = ImmediateTestProvider(
            output: .transcript(.init(text: "hello world"))
        )
        let inserter = RecordingTextInserter()
        let clock = IntegrationTestWorkflowClock()
        let workflow = DictationWorkflowActor(
            hudPresenter: hudPresenter,
            tentativeCaptureDriver: AudioTentativeCaptureDriver(audioCapture: audioService),
            transcriptionDriver: ProviderBackedTranscriptionDriver(
                activeProviderResolver: { provider },
                textInserter: inserter
            ),
            clock: clock,
            readinessProvider: { .ready }
        )

        await workflow.handle(.hotkeyDown(timestamp: 1.0))
        await clock.resumeNext()
        await workflow.handle(.hotkeyUp(timestamp: 1.2))
        let completed = await eventually { await MainActor.run { hudPresenter.hideCallCount == 1 } }
        try #require(completed)

        #expect(await audioService.startedSessionCount() == 1)
        #expect(await audioService.finishedSessionCount() == 1)
        #expect(await audioService.canceledSessionCount() == 0)
        #expect(await provider.transcribeCallCount() == 1)
        #expect(await inserter.insertedTexts() == ["hello world"])
        #expect(hudPresenter.presentedStates == [.recording, .transcribing])
        #expect(hudPresenter.hideCallCount == 1)
    }

    @Test
    func insertionFailureStaysVisibleUntilReset() async throws {
        let hudPresenter = IntegrationTestHUDPresenter(activationScreenID: "screen-a")
        let audioService = TestAudioCaptureService(preparedCapture: .fixture())
        let provider = ImmediateTestProvider(
            output: .transcript(.init(text: "cannot insert"))
        )
        let inserter = RecordingTextInserter(shouldFail: true)
        let clock = IntegrationTestWorkflowClock()
        let workflow = DictationWorkflowActor(
            hudPresenter: hudPresenter,
            tentativeCaptureDriver: AudioTentativeCaptureDriver(audioCapture: audioService),
            transcriptionDriver: ProviderBackedTranscriptionDriver(
                activeProviderResolver: { provider },
                textInserter: inserter
            ),
            clock: clock,
            readinessProvider: { .ready }
        )

        await workflow.handle(.hotkeyDown(timestamp: 1.0))
        await workflow.handle(.hotkeyUp(timestamp: 1.1))
        let reachedInsertionFailureState = await eventually {
            await MainActor.run {
                hudPresenter.presentedStates.last == .insertionFailed(.writeFailed)
            }
        }

        try #require(reachedInsertionFailureState)

        #expect(hudPresenter.presentedStates == [.transcribing, .insertionFailed(.writeFailed)])
        #expect(hudPresenter.hideCallCount == 0)

        await clock.resumeNext()
        let resetCompleted = await eventually {
            await MainActor.run { hudPresenter.hideCallCount == 1 }
        }

        try #require(resetCompleted)
    }

    @Test
    func doublePressDuringTranscriptionCancelsTheInFlightRequestAndSkipsInsertion() async throws {
        let hudPresenter = IntegrationTestHUDPresenter(activationScreenID: "screen-a")
        let audioService = TestAudioCaptureService(preparedCapture: .fixture())
        let provider = BlockingTestProvider()
        let inserter = RecordingTextInserter()
        let clock = IntegrationTestWorkflowClock()
        let workflow = DictationWorkflowActor(
            hudPresenter: hudPresenter,
            tentativeCaptureDriver: AudioTentativeCaptureDriver(audioCapture: audioService),
            transcriptionDriver: ProviderBackedTranscriptionDriver(
                activeProviderResolver: { provider },
                textInserter: inserter
            ),
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
            await MainActor.run { hudPresenter.presentedStates.count >= 2 }
        }
        try #require(reachedCanceled)
        #expect(await provider.transcribeCallCount() == 1)
        #expect(await provider.cancellationCount() == 1)
        #expect(await inserter.insertedTexts().isEmpty)
        #expect(hudPresenter.presentedStates == [.transcribing, .canceled])

        await clock.resumeNext()
        let resetCompleted = await eventually {
            await MainActor.run { hudPresenter.hideCallCount == 1 }
        }

        try #require(resetCompleted)
    }
}
