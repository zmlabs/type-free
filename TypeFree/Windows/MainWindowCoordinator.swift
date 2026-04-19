import AppKit

@MainActor
final class MainWindowCoordinator {
    private let rootViewModel: MainWindowRootViewModel
    private var windowController: MainWindowController?

    init(
        appSettingsRepository: AppSettingsRepository,
        providerConfigurationRepository: ProviderConfigurationRepository,
        permissionStore: PermissionStore,
        secretVault: any ProviderSecretVaulting,
        actionBridge: MainWindowActionBridge
    ) {
        let broadcaster = HotkeyChangeBroadcaster()
        let overviewViewModel = OverviewViewModel(
            appSettingsRepository: appSettingsRepository,
            providerConfigurationRepository: providerConfigurationRepository,
            permissionStore: permissionStore,
            broadcaster: broadcaster
        )
        let hotkeySettingsViewModel = HotkeySettingsViewModel(
            repository: appSettingsRepository,
            broadcaster: broadcaster
        )
        broadcaster.register(overviewViewModel)
        broadcaster.register(hotkeySettingsViewModel)
        overviewViewModel.onHotkeyBroadcast = { hotkey in
            actionBridge.applyHotkey(hotkey)
        }
        hotkeySettingsViewModel.onHotkeyBroadcast = { hotkey in
            actionBridge.applyHotkey(hotkey)
        }
        overviewViewModel.onActiveProviderSaved = { _ in
            actionBridge.refreshRuntimeState()
        }
        let providerSettingsViewModel = ProviderSettingsViewModel(
            repository: providerConfigurationRepository,
            secretVault: secretVault,
            onSettingsChanged: {
                actionBridge.refreshRuntimeState()
                overviewViewModel.refresh()
            }
        )
        let permissionsViewModel = PermissionsViewModel(
            permissionStore: permissionStore,
            onSettingsChanged: {
                actionBridge.refreshRuntimeState()
                overviewViewModel.refresh()
            }
        )

        rootViewModel = MainWindowRootViewModel(
            appSettingsRepository: appSettingsRepository,
            overviewViewModel: overviewViewModel,
            hotkeySettingsViewModel: hotkeySettingsViewModel,
            providerSettingsViewModel: providerSettingsViewModel,
            permissionsViewModel: permissionsViewModel
        )
    }

    @discardableResult
    func showWindow() -> MainWindowController {
        let controller: MainWindowController

        if let existingController = windowController {
            controller = existingController
        } else {
            let newController = MainWindowController(rootViewModel: rootViewModel)
            windowController = newController
            controller = newController
        }

        rootViewModel.refresh()
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        return controller
    }
}
