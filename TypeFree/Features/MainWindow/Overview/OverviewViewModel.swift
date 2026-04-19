import Foundation
import Observation

enum OverviewReadiness: Equatable {
    case ready
    case microphoneRequired
    case accessibilityRequired
    case audioInputUnavailable
    case providerNotConfigured

    var title: String {
        switch self {
        case .ready: "Ready"
        case .microphoneRequired: "Microphone Required"
        case .accessibilityRequired: "Accessibility Required"
        case .audioInputUnavailable: "No Audio Input Device"
        case .providerNotConfigured: "Provider Not Configured"
        }
    }

    var message: String {
        switch self {
        case .ready: "Hold the trigger key to start dictation."
        case .microphoneRequired: "Grant Microphone access to enable recording."
        case .accessibilityRequired: "Grant Accessibility access to insert transcribed text."
        case .audioInputUnavailable: "No Audio Input Device"
        case .providerNotConfigured: "Set up a provider to enable dictation."
        }
    }

    var isReady: Bool {
        self == .ready
    }
}

@MainActor @Observable
final class OverviewViewModel {
    let presetHotkeys = HotkeyConfiguration.supported.map(HotkeyOption.init(configuration:))
    let availableProviderKinds = ProviderKind.allCases

    private(set) var selectedHotkeyIdentifier = HotkeyConfiguration.default.identifier
    private(set) var activeProvider: ProviderKind = .openAICompatible
    private(set) var customHotkeyOption: HotkeyOption?
    private(set) var readiness: OverviewReadiness = .ready
    private(set) var lastPersistenceError: String?

    var onHotkeyBroadcast: (HotkeyConfiguration) -> Void = { _ in }
    var onActiveProviderSaved: (ProviderKind) -> Void = { _ in }

    var availableHotkeys: [HotkeyOption] {
        if let custom = customHotkeyOption {
            return presetHotkeys + [custom]
        }
        return presetHotkeys
    }

    private let appSettingsRepository: AppSettingsRepository
    private let providerConfigurationRepository: ProviderConfigurationRepository
    private let permissionStore: PermissionStore
    private let audioInputDeviceProbe: any AudioInputDeviceProbe
    private let broadcaster: HotkeyChangeBroadcaster

    init(
        appSettingsRepository: AppSettingsRepository,
        providerConfigurationRepository: ProviderConfigurationRepository,
        permissionStore: PermissionStore,
        audioInputDeviceProbe: any AudioInputDeviceProbe,
        broadcaster: HotkeyChangeBroadcaster
    ) {
        self.appSettingsRepository = appSettingsRepository
        self.providerConfigurationRepository = providerConfigurationRepository
        self.permissionStore = permissionStore
        self.audioInputDeviceProbe = audioInputDeviceProbe
        self.broadcaster = broadcaster
    }

    func commitHotkey(_ identifier: String) {
        guard let option = availableHotkeys.first(where: { $0.configuration.identifier == identifier }) else {
            return
        }
        do {
            let settings = try appSettingsRepository.load()
            settings.hotkeyIdentifier = option.configuration.identifier
            settings.hotkeyDisplayName = option.configuration.displayName
            try appSettingsRepository.save(settings)
            lastPersistenceError = nil
            broadcaster.broadcast(option.configuration)
            onHotkeyBroadcast(option.configuration)
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    func commitActiveProvider(_ kind: ProviderKind) {
        do {
            let settings = try appSettingsRepository.load()
            settings.activeProvider = kind
            try appSettingsRepository.save(settings)
            lastPersistenceError = nil
            refresh()
            onActiveProviderSaved(kind)
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    func refresh() {
        let settings = try? appSettingsRepository.load()
        let snapshot = permissionStore.refresh()

        selectedHotkeyIdentifier = settings?.hotkeyIdentifier ?? HotkeyConfiguration.default.identifier
        if let id = settings?.hotkeyIdentifier {
            let hasPresetHotkey = presetHotkeys.contains(where: { $0.id == id })
            if let displayName = settings?.hotkeyDisplayName, !hasPresetHotkey {
                customHotkeyOption = HotkeyOption(
                    configuration: HotkeyConfiguration(identifier: id, displayName: displayName)
                )
            } else {
                customHotkeyOption = nil
            }
        } else {
            customHotkeyOption = nil
        }

        activeProvider = settings?.activeProvider ?? .openAICompatible
        let providerConfiguration = try? providerConfigurationRepository.load(kind: activeProvider)

        if snapshot.microphone != .granted {
            readiness = .microphoneRequired
        } else if snapshot.accessibility != .granted {
            readiness = .accessibilityRequired
        } else if !audioInputDeviceProbe.hasAvailableInput() {
            readiness = .audioInputUnavailable
        } else if providerConfiguration?.hasActiveCredentialReference != true {
            readiness = .providerNotConfigured
        } else {
            readiness = .ready
        }
    }
}

extension OverviewViewModel: HotkeyChangeObserver {
    func hotkeyDidChange(_: HotkeyConfiguration) {
        refresh()
    }
}
