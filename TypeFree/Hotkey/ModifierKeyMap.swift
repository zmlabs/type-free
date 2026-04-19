import AppKit
import CoreGraphics

nonisolated func physicalKeyIdentifier(for keyCode: CGKeyCode) -> String {
    switch keyCode {
    case 54:
        HotkeyConfiguration.rightCommand.identifier
    case 57:
        HotkeyConfiguration.capsLock.identifier
    case 61:
        HotkeyConfiguration.rightOption.identifier
    case 62:
        HotkeyConfiguration.rightControl.identifier
    case 63:
        HotkeyConfiguration.default.identifier
    default:
        "keyCode:\(keyCode)"
    }
}

nonisolated func modifierKey(for keyCode: CGKeyCode) -> NSEvent.ModifierFlags? {
    switch keyCode {
    case 54, 55:
        .command
    case 56, 60:
        .shift
    case 58, 61:
        .option
    case 59, 62:
        .control
    case 57:
        .capsLock
    case 63:
        .function
    default:
        nil
    }
}

nonisolated func isModifierKeyPress(keyCode: CGKeyCode, modifierFlags: NSEvent.ModifierFlags) -> Bool {
    guard let expected = modifierKey(for: keyCode) else {
        return false
    }
    return modifierFlags.contains(expected)
}
