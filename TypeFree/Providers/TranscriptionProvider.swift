import Foundation

nonisolated struct PreparedCapture: Equatable {
    let fileURL: URL
    let duration: TimeInterval
    let sampleRate: Double
    let channelCount: Int
    let activationScreenID: String
}

nonisolated struct ProviderConfigurationSnapshot: Equatable {
    let kind: ProviderKind
    let baseURL: String?
    let modelIdentifier: String
    let languageHint: String?
    let enableITN: Bool
    let requestTimeoutSeconds: Int
    let apiKeyReference: String?

    init(
        kind: ProviderKind,
        baseURL: String? = nil,
        modelIdentifier: String,
        languageHint: String?,
        enableITN: Bool = false,
        requestTimeoutSeconds: Int,
        apiKeyReference: String? = nil
    ) {
        self.kind = kind
        self.baseURL = baseURL
        self.modelIdentifier = modelIdentifier
        self.languageHint = languageHint
        self.enableITN = enableITN
        self.requestTimeoutSeconds = requestTimeoutSeconds
        self.apiKeyReference = apiKeyReference
    }

    init(configuration: ProviderConfiguration) throws {
        guard let kind = ProviderKind(rawValue: configuration.providerKind) else {
            throw TranscriptionProviderError.unsupportedProviderKind(configuration.providerKind)
        }

        self.init(
            kind: kind,
            baseURL: configuration.baseURL,
            modelIdentifier: configuration.modelIdentifier,
            languageHint: configuration.languageHint,
            enableITN: configuration.enableITN ?? kind.defaultEnableITN,
            requestTimeoutSeconds: configuration.requestTimeoutSeconds,
            apiKeyReference: configuration.apiKeyReference
        )
    }
}

nonisolated enum TranscriptionProviderOutput: Equatable {
    case transcript(TranscriptionResult)
    case noSpeech
}

protocol TranscriptionProvider: Sendable {
    var kind: ProviderKind { get }
    func transcribe(capture: PreparedCapture) async throws -> TranscriptionProviderOutput
}
