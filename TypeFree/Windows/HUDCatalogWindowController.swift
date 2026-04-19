#if DEBUG
    import AppKit
    import SwiftUI

    @MainActor
    final class HUDCatalogWindowController: NSWindowController {
        private let hudController: HUDPanelController

        init() {
            let hudController = HUDPanelController()
            let sessionID = UUID()
            let view = HUDCatalogView(
                onSelect: { state in
                    hudController.present(
                        state: state,
                        sessionID: sessionID,
                        activationScreenID: hudController.activationScreenID()
                    )
                },
                onHide: {
                    hudController.hide()
                }
            )
            let hostingController = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "HUD Debug"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.hudController = hudController
            super.init(window: window)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
#endif
