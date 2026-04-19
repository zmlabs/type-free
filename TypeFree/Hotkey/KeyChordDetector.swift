import Foundation

struct KeyChordDetector {
    private let hotkey: HotkeyConfiguration

    init(hotkey: HotkeyConfiguration) {
        self.hotkey = hotkey
    }

    func isChordCancellation(event: GlobalKeyEvent, isHotkeyHeld: Bool) -> Bool {
        guard isHotkeyHeld else {
            return false
        }

        guard event.physicalKeyIdentifier != hotkey.identifier else {
            return false
        }

        switch event.kind {
        case .keyDown:
            return event.isPressed
        case .flagsChanged:
            return event.isPressed
        case .keyUp:
            return false
        }
    }
}
