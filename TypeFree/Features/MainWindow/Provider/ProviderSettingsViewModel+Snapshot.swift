import Foundation

extension ProviderSettingsViewModel {
    struct SnapshotInput {
        let providerKind: ProviderKind
        let baseURL: String
        let modelIdentifier: String
        let languageHint: String
        let enableITN: Bool
        let requestTimeoutSeconds: Int
    }

    func currentSnapshotInput() -> SnapshotInput {
        SnapshotInput(
            providerKind: providerKind,
            baseURL: baseURL,
            modelIdentifier: modelIdentifier,
            languageHint: languageHint,
            enableITN: enableITN,
            requestTimeoutSeconds: requestTimeoutSeconds
        )
    }

    func makeSnapshot(
        credentialReference: String?,
        input: SnapshotInput
    ) throws -> ProviderConfigurationSnapshot {
        let providerKind = input.providerKind
        let normalizedBaseURL = providerKind.requiresBaseURL
            ? try validatedBaseURL(baseURL: input.baseURL, providerKind: providerKind)
            : nil
        let normalizedModelIdentifier = try validatedModelIdentifier(
            modelIdentifier: input.modelIdentifier,
            providerKind: providerKind
        )
        let normalizedTimeout = try validatedTimeout(requestTimeoutSeconds: input.requestTimeoutSeconds)

        return ProviderConfigurationSnapshot(
            kind: providerKind,
            baseURL: normalizedBaseURL,
            modelIdentifier: normalizedModelIdentifier,
            languageHint: resolvedLanguageHint(providerKind: providerKind, languageHint: input.languageHint),
            enableITN: providerKind == .qwen3ASR ? input.enableITN : false,
            requestTimeoutSeconds: normalizedTimeout,
            apiKeyReference: credentialReference
        )
    }

    func resolvedLanguageHint(providerKind: ProviderKind, languageHint: String) -> String? {
        if providerKind == .speechAnalyzer {
            return speechAnalyzerAssets.selectedIdentifier
        }
        return languageHint.trimmedNilIfEmpty
    }

    func validatedBaseURL(baseURL: String, providerKind: ProviderKind) throws -> String {
        let normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try ProviderEndpointURL(normalizedBaseURL)
            if providerKind == .qwen3ASR {
                try Qwen3ASREndpoint.validateBaseURL(normalizedBaseURL)
            }
        } catch {
            throw ProviderSettingsError.invalidBaseURL
        }
        return normalizedBaseURL
    }

    func validatedModelIdentifier(modelIdentifier: String, providerKind: ProviderKind) throws -> String {
        guard providerKind.requiresBaseURL else { return "" }
        let normalizedModelIdentifier = modelIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedModelIdentifier.isEmpty else {
            throw ProviderSettingsError.invalidModelIdentifier
        }
        return normalizedModelIdentifier
    }

    func validatedTimeout(requestTimeoutSeconds: Int) throws -> Int {
        guard requestTimeoutSeconds > 0 else {
            throw ProviderSettingsError.invalidTimeout
        }
        return requestTimeoutSeconds
    }

    func apply(snapshot: ProviderConfigurationSnapshot, to configuration: ProviderConfiguration) {
        configuration.providerKind = snapshot.kind.rawValue
        configuration.baseURL = snapshot.baseURL
        configuration.modelIdentifier = snapshot.modelIdentifier
        configuration.languageHint = snapshot.languageHint
        configuration.enableITN = snapshot.enableITN
        configuration.requestTimeoutSeconds = snapshot.requestTimeoutSeconds
        configuration.apiKeyReference = snapshot.apiKeyReference
    }

    func mapSaveError(_ error: any Error) -> ProviderSettingsError {
        switch error {
        case let error as ProviderSettingsError:
            error
        case let error as TranscriptionProviderError:
            switch error {
            case .missingCredential:
                .missingCredential
            case .invalidConfiguration:
                .invalidConfiguration
            default:
                .invalidConfiguration
            }
        case is ProviderSecretVaultError:
            .credentialStorageFailed
        default:
            .persistenceFailed
        }
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
