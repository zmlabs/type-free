import AppKit
import Foundation
import Testing
@testable import TypeFree

@Suite(.serialized)
@MainActor
struct MainWindowCoordinatorTests {
    @Test
    func showWindowReusesSingleWindowController() throws {
        let repositories = try makeInMemoryRepositories()
        let coordinator = MainWindowCoordinator(
            appSettingsRepository: repositories.appSettingsRepository,
            providerConfigurationRepository: repositories.providerConfigurationRepository,
            permissionStore: makePermissionStore(),
            secretVault: InMemorySecretVault(),
            actionBridge: MainWindowActionBridge()
        )

        let firstController = coordinator.showWindow()
        let secondController = coordinator.showWindow()

        #expect(firstController === secondController)

        firstController.close()
    }

    @Test
    func showWindowReopensTheSingleWindowControllerAfterClose() throws {
        let repositories = try makeInMemoryRepositories()
        let coordinator = MainWindowCoordinator(
            appSettingsRepository: repositories.appSettingsRepository,
            providerConfigurationRepository: repositories.providerConfigurationRepository,
            permissionStore: makePermissionStore(),
            secretVault: InMemorySecretVault(),
            actionBridge: MainWindowActionBridge()
        )

        let firstController = coordinator.showWindow()
        let originalWindow = firstController.window
        #expect(originalWindow != nil)

        firstController.close()
        #expect(firstController.window != nil)

        let reopenedController = coordinator.showWindow()
        #expect(firstController === reopenedController)
        #expect(reopenedController.window === originalWindow)
        #expect(reopenedController.window?.isVisible == true)

        reopenedController.close()
    }
}
