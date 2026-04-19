import Testing
@testable import TypeFree

struct AudioInputDeviceProbeTests {
    @Test
    func hasAvailableInputReturnsTrueWhenProbeIsConfiguredAvailable() {
        let probe = TestAudioInputDeviceProbe(isAvailable: true)

        #expect(probe.hasAvailableInput() == true)
    }

    @Test
    func hasAvailableInputReturnsFalseWhenProbeIsConfiguredUnavailable() {
        let probe = TestAudioInputDeviceProbe(isAvailable: false)

        #expect(probe.hasAvailableInput() == false)
    }

    @Test
    func systemProbeAnswersHasAvailableInputWithoutCrashing() {
        let probe = SystemAudioInputDeviceProbe()

        _ = probe.hasAvailableInput()
    }
}
