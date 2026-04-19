import CoreGraphics
import Foundation

struct GlobalKeyEvent: Equatable {
    enum Kind: Equatable {
        case keyDown
        case keyUp
        case flagsChanged
    }

    let timestamp: TimeInterval
    let kind: Kind
    let keyCode: CGKeyCode
    let physicalKeyIdentifier: String
    let isPressed: Bool
    let modifierFlagsRawValue: UInt64
}
