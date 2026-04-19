import Testing
@testable import TypeFree

@MainActor
struct KeyChordDetectorTests {
    @Test
    func detectsOtherKeyPressWhileHotkeyIsHeld() {
        let detector = KeyChordDetector(hotkey: .default)
        let event = GlobalKeyEvent(
            timestamp: 1.0,
            kind: .keyDown,
            keyCode: 12,
            physicalKeyIdentifier: "keyCode:12",
            isPressed: true,
            modifierFlagsRawValue: 0
        )

        #expect(detector.isChordCancellation(event: event, isHotkeyHeld: true))
    }

    @Test
    func ignoresHotkeyEventsAndKeyUps() {
        let detector = KeyChordDetector(hotkey: .default)
        let hotkeyDown = GlobalKeyEvent(
            timestamp: 1.0,
            kind: .flagsChanged,
            keyCode: 63,
            physicalKeyIdentifier: "fn",
            isPressed: true,
            modifierFlagsRawValue: 0
        )
        let otherKeyUp = GlobalKeyEvent(
            timestamp: 1.1,
            kind: .keyUp,
            keyCode: 12,
            physicalKeyIdentifier: "keyCode:12",
            isPressed: false,
            modifierFlagsRawValue: 0
        )

        let otherKeyDown = GlobalKeyEvent(
            timestamp: 1.2,
            kind: .keyDown,
            keyCode: 12,
            physicalKeyIdentifier: "keyCode:12",
            isPressed: true,
            modifierFlagsRawValue: 0
        )

        #expect(!detector.isChordCancellation(event: hotkeyDown, isHotkeyHeld: true))
        #expect(!detector.isChordCancellation(event: otherKeyUp, isHotkeyHeld: true))
        #expect(!detector.isChordCancellation(event: otherKeyDown, isHotkeyHeld: false))
    }
}
