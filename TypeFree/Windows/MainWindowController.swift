import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController {
    init(rootViewModel: MainWindowRootViewModel) {
        let rootView = MainWindowRootView(viewModel: rootViewModel)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "TypeFree"
        window.setContentSize(NSSize(width: 640, height: 440))
        window.minSize = NSSize(width: 540, height: 360)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        let toolbar = NSToolbar()
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.tabbingMode = .disallowed
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.isReleasedWhenClosed = false

        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
