import CoreGraphics
import Testing
@testable import TypeFree

struct NSEventMonitorSourceTests {
    @Test(arguments: [
        (CGKeyCode(54), "rightCommand"),
        (CGKeyCode(57), "capsLock"),
        (CGKeyCode(61), "rightOption"),
        (CGKeyCode(62), "rightControl"),
        (CGKeyCode(63), "fn"),
    ])
    func physicalKeyIdentifierMapsSupportedModifierKeys(
        keyCode: CGKeyCode,
        expectedIdentifier: String
    ) {
        #expect(physicalKeyIdentifier(for: keyCode) == expectedIdentifier)
    }
}
