import Testing
@testable import TypeFree

@MainActor
struct HotkeyPressClassifierTests {
    @Test
    func consumeMapsConfiguredPhysicalKeyTransitions() {
        var classifier = HotkeyPressClassifier(hotkey: .default, doublePressInterval: 0.5)

        let down = GlobalKeyEvent(
            timestamp: 1.0,
            kind: .flagsChanged,
            keyCode: 63,
            physicalKeyIdentifier: "fn",
            isPressed: true,
            modifierFlagsRawValue: 0
        )
        let releaseEvent = GlobalKeyEvent(
            timestamp: 1.1,
            kind: .flagsChanged,
            keyCode: 63,
            physicalKeyIdentifier: "fn",
            isPressed: false,
            modifierFlagsRawValue: 0
        )

        #expect(classifier.consume(down) == .hotkeyDown(timestamp: 1.0))
        #expect(classifier.consume(releaseEvent) == .hotkeyUp(timestamp: 1.1))
    }

    @Test
    func consumeDetectsDoublePressWithinConfiguredInterval() {
        var classifier = HotkeyPressClassifier(hotkey: .default, doublePressInterval: 0.5)

        _ = classifier.consume(
            GlobalKeyEvent(
                timestamp: 1.0,
                kind: .flagsChanged,
                keyCode: 63,
                physicalKeyIdentifier: "fn",
                isPressed: true,
                modifierFlagsRawValue: 0
            )
        )
        _ = classifier.consume(
            GlobalKeyEvent(
                timestamp: 1.1,
                kind: .flagsChanged,
                keyCode: 63,
                physicalKeyIdentifier: "fn",
                isPressed: false,
                modifierFlagsRawValue: 0
            )
        )

        let secondDown = GlobalKeyEvent(
            timestamp: 1.3,
            kind: .flagsChanged,
            keyCode: 63,
            physicalKeyIdentifier: "fn",
            isPressed: true,
            modifierFlagsRawValue: 0
        )

        #expect(classifier.consume(secondDown) == .doublePress(timestamp: 1.3))
    }

    @Test
    func consumeIgnoresUnconfiguredPhysicalKeys() {
        var classifier = HotkeyPressClassifier(hotkey: .default, doublePressInterval: 0.5)

        let event = GlobalKeyEvent(
            timestamp: 1.0,
            kind: .keyDown,
            keyCode: 12,
            physicalKeyIdentifier: "keyCode:12",
            isPressed: true,
            modifierFlagsRawValue: 0
        )

        #expect(classifier.consume(event) == nil)
    }

    @Test
    func consumeMapsConfiguredRightCommandTransitions() {
        var classifier = HotkeyPressClassifier(
            hotkey: .rightCommand,
            doublePressInterval: 0.5
        )

        let down = GlobalKeyEvent(
            timestamp: 1.0,
            kind: .flagsChanged,
            keyCode: 54,
            physicalKeyIdentifier: HotkeyConfiguration.rightCommand.identifier,
            isPressed: true,
            modifierFlagsRawValue: 0
        )
        let releaseEvent = GlobalKeyEvent(
            timestamp: 1.1,
            kind: .flagsChanged,
            keyCode: 54,
            physicalKeyIdentifier: HotkeyConfiguration.rightCommand.identifier,
            isPressed: false,
            modifierFlagsRawValue: 0
        )

        #expect(classifier.consume(down) == .hotkeyDown(timestamp: 1.0))
        #expect(classifier.consume(releaseEvent) == .hotkeyUp(timestamp: 1.1))
    }
}
