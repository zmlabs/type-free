import CoreGraphics

struct HUDScreenDescriptor: Equatable {
    let identifier: String
    let visibleFrame: CGRect
}

struct HUDPlacement: Equatable {
    let screenID: String
    let frame: CGRect
}

struct HUDPositioner {
    let panelSize: CGSize
    let bottomMargin: CGFloat

    func placement(
        screens: [HUDScreenDescriptor],
        pointerLocation: CGPoint,
        sessionScreenID: String?
    ) -> HUDPlacement? {
        let targetScreen = resolvedScreen(
            screens: screens,
            pointerLocation: pointerLocation,
            sessionScreenID: sessionScreenID
        )

        guard let targetScreen else {
            return nil
        }

        let minX = targetScreen.visibleFrame.minX
        let maxX = targetScreen.visibleFrame.maxX - panelSize.width
        let proposedX = targetScreen.visibleFrame.midX - (panelSize.width / 2)
        let frame = CGRect(
            x: min(max(proposedX, minX), maxX),
            y: targetScreen.visibleFrame.minY + bottomMargin,
            width: panelSize.width,
            height: panelSize.height
        )

        return HUDPlacement(screenID: targetScreen.identifier, frame: frame)
    }

    private func resolvedScreen(
        screens: [HUDScreenDescriptor],
        pointerLocation: CGPoint,
        sessionScreenID: String?
    ) -> HUDScreenDescriptor? {
        if let sessionScreenID {
            if let sessionScreen = screens.first(where: { $0.identifier == sessionScreenID }) {
                return sessionScreen
            }
        }

        if let pointerScreen = screens.first(where: { $0.visibleFrame.contains(pointerLocation) }) {
            return pointerScreen
        }

        return screens.first
    }
}
