import Testing
@testable import TypeFree

@MainActor
struct HUDViewModelTests {
    @Test(arguments: [
        (HUDState.recording, ""),
        (HUDState.transcribing, "Transcribing..."),
        (HUDState.canceled, "Canceled"),
        (HUDState.noSpeech, "No speech heard"),
        (HUDState.permissionBlocked, "Permission needed"),
        (HUDState.providerFailed(.configuration()), "Setup incomplete"),
        (HUDState.providerFailed(.unauthorized()), "Invalid API key"),
        (HUDState.providerFailed(.timeout()), "Timed out"),
        (HUDState.providerFailed(.unavailable()), "Service unreachable"),
        (HUDState.providerFailed(.invalidResponse()), "Unexpected response"),
        (HUDState.insertionFailed(.targetUnavailable), "No text field found"),
        (HUDState.insertionFailed(.targetNotEditable), "Field not editable"),
        (HUDState.insertionFailed(.writeFailed), "Input rejected"),
    ])
    func renderProducesExpectedMessage(state: HUDState, expectedMessage: String) {
        let viewModel = HUDViewModel()
        viewModel.render(state: state)
        #expect(viewModel.message == expectedMessage)
        #expect(viewModel.isVisible)
    }

    @Test
    func renderUsesCustomDetailWhenProviderFailureHasOne() {
        let viewModel = HUDViewModel()
        viewModel.render(state: .providerFailed(.timeout(detail: "Server returned 504")))
        #expect(viewModel.message == "Server returned 504")
    }

    @Test
    func hideClearsStateAndMessage() {
        let viewModel = HUDViewModel()
        viewModel.render(state: .transcribing)
        viewModel.hide()
        #expect(!viewModel.isVisible)
        #expect(viewModel.state == .hidden)
        #expect(viewModel.message == "")
        #expect(viewModel.audioLevel == 0)
    }

    @Test
    func updateAudioLevelDrivesIndependentBarLevelsWithSmoothing() {
        let viewModel = HUDViewModel()
        viewModel.updateAudioLevel(0.1)

        let bars = viewModel.barLevels
        #expect(bars.count == 9)
        #expect(bars.allSatisfy { $0 > 0 })
        #expect(bars[4] > bars[0])
        #expect(bars[4] > bars[8])

        viewModel.updateAudioLevel(0.1)
        let smoothedBars = viewModel.barLevels
        #expect(zip(bars, smoothedBars).allSatisfy { $1 > $0 })
    }

    @Test
    func resetAudioLevelClearsSmoothedValue() {
        let viewModel = HUDViewModel()
        viewModel.updateAudioLevel(0.8)
        viewModel.resetAudioLevel()
        #expect(viewModel.audioLevel == 0)
        #expect(viewModel.barLevels.allSatisfy { $0 == 0 })
    }
}
