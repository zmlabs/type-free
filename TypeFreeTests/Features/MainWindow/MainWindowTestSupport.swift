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
