import AppKit
import OSLog
import SwiftData

@MainActor
final class AppBootstrap {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "dev.zhangyu.TypeFree",
        category: "AppBootstrap"
    )

    @MainActor
    private final class RuntimeStatus {
        var phase: DictationPhase = .idle
    }

    struct PersistenceStack {
        let modelContainer: ModelContainer
        let appSettingsRepository: AppSettingsRepository
        let providerConfigurationRepository: ProviderConfigurationRepository
    }

    struct InteractionRuntime {
        let hudPanelController: HUDPanelController
        let workflowActor: DictationWorkflowActor
        let hotkeyMonitor: GlobalHotkeyMonitor
    }

    private struct WorkflowStatusContext {
        let appSettingsRepository: AppSettingsRepository
        let permissionStore: PermissionStore
        let providerConfigurationRepository: ProviderConfigurationRepository
        let statusBarController: StatusBarController
    }

    struct Runtime {
        let modelContainer: ModelContainer
        let appSettingsRepository: AppSettingsRepository
        let providerConfigurationRepository: ProviderConfigurationRepository
        let permissionStore: PermissionStore
        let mainWindowCoordinator: MainWindowCoordinator
        let statusBarController: StatusBarController
        let hudPanelController: HUDPanelController
        let dictationWorkflowActor: DictationWorkflowActor
        let hotkeyMonitor: GlobalHotkeyMonitor
        let updaterCoordinator: UpdaterCoordinator
    }

    func bootstrap(
        launchConfiguration: LaunchConfiguration = .currentProcess
    ) throws -> Runtime {
        let persistence = try makePersistenceStack(inMemory: launchConfiguration.usesInMemoryPersistence)
        let permissionStore = makePermissionStore()
        let providerSecretVault = ProviderSecretVault()
        let mainWindowActionBridge = MainWindowActionBridge()
        let appSettings = try persistence.appSettingsRepository.load()
        let updaterCoordinator = UpdaterCoordinator()
        let mainWindowCoordinator = MainWindowCoordinator(
            appSettingsRepository: persistence.appSettingsRepository,
            providerConfigurationRepository: persistence.providerConfigurationRepository,
            permissionStore: permissionStore,
            secretVault: providerSecretVault,
            actionBridge: mainWindowActionBridge
        )
        let statusBarController = makeStatusBarController(
            mainWindowCoordinator: mainWindowCoordinator,
            persistence: persistence,
            permissionStore: permissionStore,
            updaterController: updaterCoordinator.controller
        )
        let statusContext = WorkflowStatusContext(
            appSettingsRepository: persistence.appSettingsRepository,
            permissionStore: permissionStore,
            providerConfigurationRepository: persistence.providerConfigurationRepository,
            statusBarController: statusBarController
        )
        let runtimeStatus = RuntimeStatus()
        let interactionRuntime = makeInteractionRuntime(
            appSettings: appSettings,
            statusContext: statusContext,
            runtimeStatus: runtimeStatus,
            providerSecretVault: providerSecretVault,
            disableHotkeyMonitoring: launchConfiguration.disablesHotkeyMonitoring
        )

        wireActionBridge(
            mainWindowActionBridge,
            interactionRuntime: interactionRuntime,
            statusContext: statusContext,
            runtimeStatus: runtimeStatus
        )

        return makeRuntime(
            persistence: persistence,
            permissionStore: permissionStore,
            mainWindowCoordinator: mainWindowCoordinator,
            statusBarController: statusBarController,
            interactionRuntime: interactionRuntime,
            updaterCoordinator: updaterCoordinator
        )
    }
}

private extension AppBootstrap {
    private func wireActionBridge(
        _ mainWindowActionBridge: MainWindowActionBridge,
        interactionRuntime: InteractionRuntime,
        statusContext: WorkflowStatusContext,
        runtimeStatus: RuntimeStatus
    ) {
        mainWindowActionBridge.onHotkeySaved = { hotkey in
            interactionRuntime.hotkeyMonitor.updateHotkey(hotkey)
        }
        mainWindowActionBridge.onRuntimeStateChanged = {
            statusContext.statusBarController.update(
                viewModel: Self.makeStatusMenuViewModel(
                    appSettingsRepository: statusContext.appSettingsRepository,
                    permissionStore: statusContext.permissionStore,
                    providerConfigurationRepository: statusContext.providerConfigurationRepository,
                    workflowPhase: runtimeStatus.phase
                )
            )
        }
    }

    private func makeInteractionRuntime(
        appSettings: AppSettings,
        statusContext: WorkflowStatusContext,
        runtimeStatus: RuntimeStatus,
        providerSecretVault: any ProviderSecretVaulting,
        disableHotkeyMonitoring: Bool
    ) -> InteractionRuntime {
        let audioLevelRelay = AudioLevelRelay()
        let hudPanelController = HUDPanelController(audioLevelRelay: audioLevelRelay)
        let tentativeCaptureDriver = AudioTentativeCaptureDriver(
            audioCapture: AudioCaptureActor(audioLevelRelay: audioLevelRelay)
        )
        let transcriptionDriver = makeTranscriptionDriver(
            appSettingsRepository: statusContext.appSettingsRepository,
            providerConfigurationRepository: statusContext.providerConfigurationRepository,
            providerSecretVault: providerSecretVault
        )
        let workflowActor = makeWorkflowActor(
            hudPanelController: hudPanelController,
            tentativeCaptureDriver: tentativeCaptureDriver,
            transcriptionDriver: transcriptionDriver,
            statusContext: statusContext,
            runtimeStatus: runtimeStatus
        )
        let hotkeyMonitor = makeHotkeyMonitor(appSettings: appSettings, workflowActor: workflowActor)
        if !disableHotkeyMonitoring {
            let started = hotkeyMonitor.start()
            if !started {
                Self.logger.error("Hotkey monitor failed to start")
            }
        }

        return InteractionRuntime(
            hudPanelController: hudPanelController,
            workflowActor: workflowActor,
            hotkeyMonitor: hotkeyMonitor
        )
    }

    private func makeWorkflowActor(
        hudPanelController: HUDPanelController,
        tentativeCaptureDriver: AudioTentativeCaptureDriver,
        transcriptionDriver: ProviderBackedTranscriptionDriver,
        statusContext: WorkflowStatusContext,
        runtimeStatus: RuntimeStatus
    ) -> DictationWorkflowActor {
        DictationWorkflowActor(
            hudPresenter: hudPanelController,
            tentativeCaptureDriver: tentativeCaptureDriver,
            transcriptionDriver: transcriptionDriver,
            clock: SystemWorkflowClock(),
            readinessProvider: makeReadinessProvider(
                permissionStore: statusContext.permissionStore,
                appSettingsRepository: statusContext.appSettingsRepository,
                providerConfigurationRepository: statusContext.providerConfigurationRepository
            ),
            phaseObserver: { phase in
                runtimeStatus.phase = phase
                statusContext.statusBarController.update(
                    viewModel: Self.makeStatusMenuViewModel(
                        appSettingsRepository: statusContext.appSettingsRepository,
                        permissionStore: statusContext.permissionStore,
                        providerConfigurationRepository: statusContext.providerConfigurationRepository,
                        workflowPhase: phase
                    )
                )
            }
        )
    }
}
