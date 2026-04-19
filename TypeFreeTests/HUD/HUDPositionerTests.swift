import CoreGraphics
import Testing
@testable import TypeFree

@MainActor
struct HUDPositionerTests {
    @Test
    func placementPrefersTheScreenContainingThePointer() throws {
        let positioner = HUDPositioner(panelSize: CGSize(width: 300, height: 44), bottomMargin: 24)
        let screens = [
            HUDScreenDescriptor(
                identifier: "left",
                visibleFrame: CGRect(x: 0, y: 0, width: 800, height: 600)
            ),
            HUDScreenDescriptor(
                identifier: "right",
                visibleFrame: CGRect(x: 800, y: 0, width: 800, height: 600)
            ),
        ]

        let placement = positioner.placement(
            screens: screens,
            pointerLocation: CGPoint(x: 900, y: 200),
            sessionScreenID: nil
        )

        let resolvedPlacement = try #require(placement)
        #expect(resolvedPlacement.screenID == "right")
        #expect(resolvedPlacement.frame.midX == 1200)
        #expect(resolvedPlacement.frame.minY == 24)
    }

    @Test
    func placementRemainsAnchoredToTheSessionScreen() throws {
        let positioner = HUDPositioner(panelSize: CGSize(width: 300, height: 44), bottomMargin: 24)
        let screens = [
            HUDScreenDescriptor(
                identifier: "left",
                visibleFrame: CGRect(x: 0, y: 0, width: 800, height: 600)
            ),
            HUDScreenDescriptor(
                identifier: "right",
                visibleFrame: CGRect(x: 800, y: 0, width: 800, height: 600)
            ),
        ]

        let placement = positioner.placement(
            screens: screens,
            pointerLocation: CGPoint(x: 900, y: 200),
            sessionScreenID: "left"
        )

        let resolvedPlacement = try #require(placement)
        #expect(resolvedPlacement.screenID == "left")
        #expect(resolvedPlacement.frame.midX == 400)
    }
}
