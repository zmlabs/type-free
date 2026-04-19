import Foundation
import Observation
import SwiftUI

@MainActor @Observable
final class ProviderSettingsViewModel {
    let supportedProviderKinds = ProviderKind.allCases

    private(set) var providerKind: ProviderKind = .openAICompatible
    var baseURL = ProviderKind.openAICompatible.defaultBaseURL
    var modelIdentifier = ProviderKind.openAICompatible.defaultModelIdentifier
    var languageHint = ""
    var enableITN = ProviderKind.openAICompatible.defaultEnableITN
    var requestTimeoutSeconds = 30
    var apiKey = ""
    private(set) var saveMessage: LocalizedStringKey = ""
    private(set) var saveMessageLevel: ProviderSettingsSaveMessageLevel = .success
    private(set) var isSaving = false
    let speechAnalyzerAssets = SpeechAnalyzerAssetCoordinator()

    private let repository: ProviderConfigurationRepository
    private let secretVault: any ProviderSecretVaulting
    private let configurationValidator: any ProviderConfigurationValidating
    private let onSettingsChanged: () -> Void
    private var currentCredentialReference = ""
    private var apiKeyLoadGeneration = 0
    private var apiKeyAtLoadStart = ""

    init(
        repository: ProviderConfigurationRepository,
        secretVault: any ProviderSecretVaulting,
        configurationValidator: any ProviderConfigurationValidating = ProviderConfigurationValidator(),
        onSettingsChanged: @escaping () -> Void = {}
    ) {
        self.repository = repository
        self.secretVault = secretVault
        self.configurationValidator = configurationValidator
        self.onSettingsChanged = onSettingsChanged
    }

    func refresh() {
        loadConfiguration(for: providerKind)
    }

    func selectProviderKind(_ kind: ProviderKind) {
        guard providerKind != kind else {
            return
        }

        loadConfiguration(for: kind)

        if kind == .speechAnalyzer {
            Task { await speechAnalyzerAssets.loadLocales() }
        }
    }

    func save() async throws {
        isSaving = true
        defer { isSaving = false }
        do {
            let configuration = try repository.load(kind: providerKind)

            if providerKind.requiresCredential {
                try await saveWithCredential(configuration: configuration)
            } else {
                try await saveWithoutCredential(configuration: configuration)
            }

            saveMessageLevel = .success
            saveMessage = "Provider saved."
            onSettingsChanged()
        } catch {
            let mappedError = mapSaveError(error)
            saveMessageLevel = .error
            saveMessage = mappedError.message
            throw mappedError
        }
    }

    private func saveWithCredential(configuration: ProviderConfiguration) async throws {
        let frozenInput = currentSnapshotInput()
        let frozenAPIKey = apiKey

        let existingReference = (configuration.apiKeyReference ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAPIKey = frozenAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let credentialReference = normalizedAPIKey.isEmpty ? existingReference : UUID().uuidString
        let credentialToValidate = try await resolveCredentialForValidation(
            newAPIKey: normalizedAPIKey,
            existingReference: existingReference
        )
        let snapshot = try makeSnapshot(
            credentialReference: credentialReference,
            input: frozenInput
        )

        try configurationValidator.validate(snapshot: snapshot, apiKey: credentialToValidate)

        if !normalizedAPIKey.isEmpty {
            try await secretVault.writeSecret(normalizedAPIKey, reference: credentialReference)
        }

        do {
            apply(snapshot: snapshot, to: configuration)
            try repository.save(configuration)
        } catch {
            if !normalizedAPIKey.isEmpty {
                try? await secretVault.deleteSecret(reference: credentialReference)
            }
            throw error
        }

        if !normalizedAPIKey.isEmpty, !existingReference.isEmpty {
            try? await secretVault.deleteSecret(reference: existingReference)
        }

        currentCredentialReference = credentialReference
    }

    private func saveWithoutCredential(configuration: ProviderConfiguration) async throws {
        let snapshot = try makeSnapshot(
            credentialReference: nil,
            input: currentSnapshotInput()
        )
        try configurationValidator.validate(snapshot: snapshot, apiKey: "")
        apply(snapshot: snapshot, to: configuration)
        try repository.save(configuration)
        currentCredentialReference = ""

        if providerKind == .speechAnalyzer {
            await speechAnalyzerAssets.installIfNeeded()
        }
    }
}

private extension ProviderSettingsViewModel {
    func loadConfiguration(for kind: ProviderKind) {
        guard let configuration = try? repository.load(kind: kind) else {
            return
        }

        providerKind = kind
        baseURL = configuration.baseURL ?? providerKind.defaultBaseURL
        modelIdentifier = configuration.modelIdentifier
        languageHint = configuration.languageHint ?? ""
        enableITN = configuration.enableITN ?? kind.defaultEnableITN
        requestTimeoutSeconds = configuration.requestTimeoutSeconds
        apiKey = ""
        saveMessage = ""
        saveMessageLevel = .success

        speechAnalyzerAssets.restoreLocale(from: configuration.languageHint)
        currentCredentialReference = (configuration.apiKeyReference ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        apiKeyAtLoadStart = ""
        apiKeyLoadGeneration += 1

        guard !currentCredentialReference.isEmpty else {
            return
        }

        let credentialReference = currentCredentialReference
        let gen = apiKeyLoadGeneration
        Task { await loadStoredAPIKey(reference: credentialReference, expectedProviderKind: kind, generation: gen) }
    }

    func loadStoredAPIKey(
        reference: String,
        expectedProviderKind: ProviderKind,
        generation: Int
    ) async {
        guard let stored = try? await secretVault.readSecret(reference: reference) else {
            return
        }
        guard generation == apiKeyLoadGeneration,
              apiKey == apiKeyAtLoadStart,
              providerKind == expectedProviderKind,
              currentCredentialReference == reference
        else {
            return
        }

        apiKey = stored
        apiKeyAtLoadStart = stored
    }

    func resolveCredentialForValidation(
        newAPIKey: String,
        existingReference: String
    ) async throws -> String {
        if !newAPIKey.isEmpty {
            return newAPIKey
        }

        guard !existingReference.isEmpty else {
            throw ProviderSettingsError.missingCredential
        }

        guard let storedSecret = try await secretVault.readSecret(reference: existingReference)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !storedSecret.isEmpty
        else {
            throw ProviderSettingsError.invalidStoredCredential
        }

        return storedSecret
    }
}
