import CoreGraphics
import Foundation

struct HotkeyConfiguration: Equatable, Codable {
    let identifier: String
    let displayName: String

    nonisolated static let `default` = Self(identifier: "fn", displayName: "Fn")
    nonisolated static let rightCommand = Self(
        identifier: "rightCommand",
        displayName: "Right Command"
    )
    nonisolated static let rightOption = Self(
        identifier: "rightOption",
        displayName: "Right Option"
    )
    nonisolated static let rightControl = Self(
        identifier: "rightControl",
        displayName: "Right Control"
    )
    nonisolated static let capsLock = Self(
        identifier: "capsLock",
        displayName: "Caps Lock"
    )

    nonisolated static let supported: [Self] = [
        .default,
        .rightCommand,
        .rightOption,
        .rightControl,
        .capsLock,
    ]

    nonisolated static func custom(keyCode: CGKeyCode, characters: String? = nil) -> Self {
        Self(
            identifier: physicalKeyIdentifier(for: keyCode),
            displayName: keyDisplayName(for: keyCode, characters: characters)
        )
    }

    nonisolated private static let keyCodeNames: [CGKeyCode: String] = [
        55: "Left Command", 56: "Left Shift", 58: "Left Option", 59: "Left Control",
        54: "Right Command", 60: "Right Shift", 61: "Right Option", 62: "Right Control",
        57: "Caps Lock", 63: "Fn",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15",
        49: "Space", 48: "Tab", 36: "Return", 51: "Delete", 53: "Escape",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    nonisolated static func keyDisplayName(for keyCode: CGKeyCode, characters: String? = nil) -> String {
        if let name = keyCodeNames[keyCode] {
            return name
        }
        if let char = characters?.uppercased(), !char.isEmpty {
            return char
        }
        return "Key \(keyCode)"
    }
}
