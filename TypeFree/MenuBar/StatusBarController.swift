import AppKit
import Sparkle

@MainActor
final class StatusBarController: NSObject {
    private let mainWindowCoordinator: MainWindowCoordinator
    private let updaterController: SPUStandardUpdaterController
    private var viewModel: StatusMenuViewModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let statusItemTitle = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    #if DEBUG
        private var hudCatalogWindowController: HUDCatalogWindowController?
    #endif

    init(
        mainWindowCoordinator: MainWindowCoordinator,
        updaterController: SPUStandardUpdaterController,
        viewModel: StatusMenuViewModel
    ) {
        self.mainWindowCoordinator = mainWindowCoordinator
        self.updaterController = updaterController
        self.viewModel = viewModel
        super.init()
        configureStatusItem()
        configureMenu()
    }

    @objc
    private func openMainWindow(_: Any?) {
        mainWindowCoordinator.showWindow()
    }

    @objc
    private func quit(_ sender: Any?) {
        NSApplication.shared.terminate(sender)
    }

    #if DEBUG
        @objc
        private func openHUDCatalog(_: Any?) {
            if hudCatalogWindowController == nil {
                hudCatalogWindowController = HUDCatalogWindowController()
            }
            hudCatalogWindowController?.showWindow(nil)
            hudCatalogWindowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    #endif

    func update(viewModel: StatusMenuViewModel) {
        self.viewModel = viewModel
        statusItemTitle.title = viewModel.statusTitle
        statusItem.button?.toolTip = viewModel.statusTitle
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        let image = NSImage(systemSymbolName: "character.textbox", accessibilityDescription: "TypeFree")
        image?.isTemplate = true
        button.image = image
        button.toolTip = viewModel.statusTitle
        statusItem.menu = menu
    }

    private func configureMenu() {
        statusItemTitle.title = viewModel.statusTitle
        statusItemTitle.isEnabled = false
        menu.addItem(statusItemTitle)
        menu.addItem(.separator())

        let openItem = NSMenuItem(
            title: viewModel.openSettingsTitle,
            action: #selector(openMainWindow(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())
        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = updaterController
        menu.addItem(updateItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: viewModel.quitTitle, action: #selector(quit(_:)), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        #if DEBUG
            menu.addItem(.separator())
            let catalogItem = NSMenuItem(
                title: "Preview HUD Catalog…",
                action: #selector(openHUDCatalog(_:)),
                keyEquivalent: ""
            )
            catalogItem.target = self
            menu.addItem(catalogItem)
        #endif
    }
}
