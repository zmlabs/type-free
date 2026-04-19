import AppKit
import Sparkle
import SwiftData

extension AppBootstrap {
    func makeStatusBarController(
        mainWindowCoordinator: MainWindowCoordinator,
        persistence: PersistenceStack,
        permissionStore: PermissionStore,
        updaterController: SPUStandardUpdaterController
    ) -> StatusBarController {
        StatusBarController(
            mainWindowCoordinator: mainWindowCoordinator,
            updaterController: updaterController,
            viewModel: Self.makeStatusMenuViewModel(
                appSettingsRepository: persistence.appSettingsRepository,
                permissionStore: permissionStore,
                providerConfigurationRepository: persistence.providerConfigurationRepository,
                workflowPhase: .idle
            )
        )
    }

    func makeRuntime(
        persistence: PersistenceStack,
        permissionStore: PermissionStore,
        mainWindowCoordinator: MainWindowCoordinator,
        statusBarController: StatusBarController,
        interactionRuntime: InteractionRuntime,
        updaterCoordinator: UpdaterCoordinator
    ) -> Runtime {
        Runtime(
            modelContainer: persistence.modelContainer,
            appSettingsRepository: persistence.appSettingsRepository,
            providerConfigurationRepository: persistence.providerConfigurationRepository,
            permissionStore: permissionStore,
            mainWindowCoordinator: mainWindowCoordinator,
            statusBarController: statusBarController,
            hudPanelController: interactionRuntime.hudPanelController,
            dictationWorkflowActor: interactionRuntime.workflowActor,
            hotkeyMonitor: interactionRuntime.hotkeyMonitor,
            updaterCoordinator: updaterCoordinator
        )
    }

    func makePersistenceStack(inMemory: Bool) throws -> PersistenceStack {
        let modelContainer = try TypeFreePersistence.makeModelContainer(inMemory: inMemory)
        let modelContext = modelContainer.mainContext
        try TypeFreePersistence.bootstrapDefaults(in: modelContext)

        return PersistenceStack(
            modelContainer: modelContainer,
            appSettingsRepository: AppSettingsRepository(modelContext: modelContext),
            providerConfigurationRepository: ProviderConfigurationRepository(modelContext: modelContext)
        )
    }

    func makePermissionStore() -> PermissionStore {
        PermissionStore(
            microphoneClient: SystemMicrophonePermissionClient(),
            accessibilityClient: SystemAccessibilityPermissionClient()
        )
    }

    func makeTranscriptionDriver(
        appSettingsRepository: AppSettingsRepository,
        providerConfigurationRepository: ProviderConfigurationRepository,
        providerSecretVault: any ProviderSecretVaulting
    ) -> ProviderBackedTranscriptionDriver {
        let providerFactory = ProviderFactory(secretVault: providerSecretVault)

        return ProviderBackedTranscriptionDriver(
            activeProviderResolver: {
                let settings = try appSettingsRepository.load()
                let configuration = try providerConfigurationRepository.load(
                    kind: settings.activeProvider
                )
                let snapshot = try ProviderConfigurationSnapshot(configuration: configuration)
                return try await providerFactory.makeProvider(for: snapshot)
            },
            textInserter: TextInjector()
        )
    }

    func makeReadinessProvider(
        permissionStore: PermissionStore,
        appSettingsRepository: AppSettingsRepository,
        providerConfigurationRepository: ProviderConfigurationRepository
    ) -> @MainActor @Sendable () async -> DictationWorkflowReadiness {
        {
            let snapshot = permissionStore.refresh()
            guard snapshot.isReadyForDictation else {
                return .permissionBlocked
            }

            let settings = try? appSettingsRepository.load()
            let providerConfiguration = settings.flatMap { settings in
                try? providerConfigurationRepository.load(kind: settings.activeProvider)
            }
            return providerConfiguration?.hasActiveCredentialReference == true
                ? .ready
                : .providerUnavailable
        }
    }

    func makeHotkeyMonitor(
        appSettings: AppSettings,
        workflowActor: DictationWorkflowActor
    ) -> GlobalHotkeyMonitor {
        GlobalHotkeyMonitor(
            source: NSEventMonitorSource(),
            hotkey: HotkeyConfiguration(
                identifier: appSettings.hotkeyIdentifier,
                displayName: appSettings.hotkeyDisplayName
            )
        ) { action in
            Task {
                await workflowActor.handle(action)
            }
        }
    }

    static func makeStatusMenuViewModel(
        appSettingsRepository: AppSettingsRepository,
        permissionStore: PermissionStore,
        providerConfigurationRepository: ProviderConfigurationRepository,
        workflowPhase: DictationPhase
    ) -> StatusMenuViewModel {
        let settings = try? appSettingsRepository.load()
        let providerConfiguration = settings.flatMap { settings in
            try? providerConfigurationRepository.load(kind: settings.activeProvider)
        }
        return StatusMenuViewModel(
            permissionSnapshot: permissionStore.refresh(),
            hasActiveProvider: providerConfiguration?.hasActiveCredentialReference == true,
            workflowPhase: workflowPhase
        )
    }
}
