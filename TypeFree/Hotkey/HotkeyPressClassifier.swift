import Foundation

enum GlobalHotkeyAction: Equatable {
    case hotkeyDown(timestamp: TimeInterval)
    case hotkeyUp(timestamp: TimeInterval)
    case otherKeyWhileHeld(timestamp: TimeInterval)
    case doublePress(timestamp: TimeInterval)
}

struct HotkeyPressClassifier {
    private let hotkey: HotkeyConfiguration
    private let doublePressInterval: TimeInterval
    private let chordDetector: KeyChordDetector

    private var isHotkeyHeld = false
    private var lastCompletedHotkeyDownTimestamp: TimeInterval?

    init(
        hotkey: HotkeyConfiguration,
        doublePressInterval: TimeInterval
    ) {
        self.hotkey = hotkey
        self.doublePressInterval = doublePressInterval
        chordDetector = KeyChordDetector(hotkey: hotkey)
    }

    mutating func consume(_ event: GlobalKeyEvent) -> GlobalHotkeyAction? {
        if chordDetector.isChordCancellation(event: event, isHotkeyHeld: isHotkeyHeld) {
            isHotkeyHeld = false
            lastCompletedHotkeyDownTimestamp = nil
            return .otherKeyWhileHeld(timestamp: event.timestamp)
        }

        guard event.physicalKeyIdentifier == hotkey.identifier else {
            return nil
        }

        if event.isPressed {
            let isDoublePress = lastCompletedHotkeyDownTimestamp.map {
                event.timestamp - $0 <= doublePressInterval
            } ?? false
            lastCompletedHotkeyDownTimestamp = event.timestamp
            isHotkeyHeld = !isDoublePress
            if isDoublePress {
                return .doublePress(timestamp: event.timestamp)
            }
            return .hotkeyDown(timestamp: event.timestamp)
        }

        guard isHotkeyHeld else {
            return nil
        }

        isHotkeyHeld = false
        return .hotkeyUp(timestamp: event.timestamp)
    }
}
