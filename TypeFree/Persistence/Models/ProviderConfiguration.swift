import Foundation
import SwiftData

@Model
final class ProviderConfiguration {
    var id: UUID
    var providerKind: String
    var baseURL: String?
    var modelIdentifier: String
    var languageHint: String?
    var enableITN: Bool?
    var requestTimeoutSeconds: Int
    var apiKeyReference: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        providerKind: String,
        baseURL: String?,
        modelIdentifier: String,
        languageHint: String?,
        enableITN: Bool? = nil,
        requestTimeoutSeconds: Int,
        apiKeyReference: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.providerKind = providerKind
        self.baseURL = baseURL
        self.modelIdentifier = modelIdentifier
        self.languageHint = languageHint
        self.enableITN = enableITN
        self.requestTimeoutSeconds = requestTimeoutSeconds
        self.apiKeyReference = apiKeyReference
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: ProviderKind {
        get { ProviderKind(rawValue: providerKind) ?? .openAICompatible }
        set { providerKind = newValue.rawValue }
    }

    var hasActiveCredentialReference: Bool {
        guard kind.requiresCredential else { return true }
        guard let ref = apiKeyReference else { return false }
        return !ref.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func defaultValue(
        kind: ProviderKind,
        now: Date = .now
    ) -> ProviderConfiguration {
        ProviderConfiguration(
            providerKind: kind.rawValue,
            baseURL: kind.requiresBaseURL ? kind.defaultBaseURL : nil,
            modelIdentifier: kind.defaultModelIdentifier,
            languageHint: nil,
            enableITN: kind.defaultEnableITN,
            requestTimeoutSeconds: kind.defaultRequestTimeoutSeconds,
            apiKeyReference: nil,
            createdAt: now,
            updatedAt: now
        )
    }
}
