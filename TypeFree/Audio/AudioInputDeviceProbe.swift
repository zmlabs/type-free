import AVFoundation
import Foundation

protocol AudioInputDeviceProbe: Sendable {
    nonisolated func hasAvailableInput() -> Bool
}

nonisolated struct SystemAudioInputDeviceProbe: AudioInputDeviceProbe {
    nonisolated func hasAvailableInput() -> Bool {
        AVCaptureDevice.default(for: .audio) != nil
    }
}
