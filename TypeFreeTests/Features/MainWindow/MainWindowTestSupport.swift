import Foundation
import SwiftData
@testable import TypeFree

struct InMemoryRepositories {
    let modelContainer: ModelContainer
    let appSettingsRepository: AppSettingsRepository
    let providerConfigurationRepository: ProviderConfigurationRepository
}

@MainActor
func makeInMemoryRepositories() throws -> InMemoryRepositories {
    let modelContainer = try TypeFreePersistence.makeModelContainer(inMemory: true)
    return InMemoryRepositories(
        modelContainer: modelContainer,
        appSettingsRepository: AppSettingsRepository(modelContext: modelContainer.mainContext),
        providerConfigurationRepository: ProviderConfigurationRepository(
            modelContext: modelContainer.mainContext
        )
    )
}

actor InMemorySecretVault: ProviderSecretVaulting {
    private var secrets: [String: String]

    init(secrets: [String: String] = [:]) {
        self.secrets = secrets
    }

    func readSecret(reference: String) throws -> String? {
        secrets[reference]
    }

    func writeSecret(_ secret: String, reference: String) throws {
        secrets[reference] = secret
    }

    func deleteSecret(reference: String) throws {
        secrets.removeValue(forKey: reference)
    }

    func snapshot() -> [String: String] {
        secrets
    }
}

struct TestMicrophonePermissionClient: MicrophonePermissionClient {
    var currentStatus: PermissionAuthorizationState
    var requestedStatus: PermissionAuthorizationState?

    func status() -> PermissionAuthorizationState {
        currentStatus
    }

    func requestPermission() async -> PermissionAuthorizationState {
        requestedStatus ?? currentStatus
    }
}

@MainActor
struct TestAccessibilityPermissionClient: AccessibilityPermissionClient {
    var currentStatus: PermissionAuthorizationState

    func status() -> PermissionAuthorizationState {
        currentStatus
    }

    func requestTrustPrompt() -> PermissionAuthorizationState {
        currentStatus
    }
}

nonisolated struct TestAudioInputDeviceProbe: AudioInputDeviceProbe {
    var isAvailable: Bool

    init(isAvailable: Bool = true) {
        self.isAvailable = isAvailable
    }

    func hasAvailableInput() -> Bool {
        isAvailable
    }
}

@MainActor
func makePermissionStore(
    microphone: PermissionAuthorizationState = .granted,
    accessibility: PermissionAuthorizationState = .granted
) -> PermissionStore {
    PermissionStore(
        microphoneClient: TestMicrophonePermissionClient(currentStatus: microphone),
        accessibilityClient: TestAccessibilityPermissionClient(currentStatus: accessibility)
    )
}

@MainActor
func makeTestAboutViewModel(
    version: String = "1.0",
    repositoryURL: URL = URL(filePath: "/"),
    checkForUpdates: @escaping @MainActor () -> Void = {},
    openURL: @escaping @MainActor (URL) -> Void = { _ in }
) -> AboutViewModel {
    AboutViewModel(
        appInfo: AboutViewModel.AppInfo(name: "TypeFree", version: version, iconImage: nil),
        repositoryURL: repositoryURL,
        checkForUpdates: checkForUpdates,
        openURL: openURL
    )
}
