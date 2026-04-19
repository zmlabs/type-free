import Foundation

struct ProviderFactory {
    private let secretVault: any ProviderSecretVaulting
    private let openAITransportFactory: () -> any OpenAITransporting
    private let qwenTransportFactory: () -> any Qwen3ASRTransporting

    init(
        secretVault: any ProviderSecretVaulting,
        openAITransportFactory: @escaping () -> any OpenAITransporting = { AlamofireOpenAITransport() },
        qwenTransportFactory: @escaping () -> any Qwen3ASRTransporting = { AlamofireQwen3ASRTransport() }
    ) {
        self.secretVault = secretVault
        self.openAITransportFactory = openAITransportFactory
        self.qwenTransportFactory = qwenTransportFactory
    }

    func makeProvider(
        for configuration: ProviderConfigurationSnapshot
    ) async throws -> any TranscriptionProvider {
        switch configuration.kind {
        case .speechAnalyzer:
            SpeechAnalyzerProvider(configuration: configuration)
        case .openAICompatible, .qwen3ASR:
            try await makeHTTPProvider(for: configuration)
        }
    }

    private func makeHTTPProvider(
        for configuration: ProviderConfigurationSnapshot
    ) async throws -> any TranscriptionProvider {
        guard let secretReference = configuration.apiKeyReference?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !secretReference.isEmpty
        else {
            throw TranscriptionProviderError.missingCredential
        }

        guard let apiKey = try await secretVault.readSecret(reference: secretReference)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !apiKey.isEmpty
        else {
            throw TranscriptionProviderError.missingCredential
        }

        switch configuration.kind {
        case .openAICompatible:
            return OpenAICompatibleProvider(
                configuration: configuration,
                apiKey: apiKey,
                transport: openAITransportFactory(),
                requestBuilder: OpenAIRequestBuilder(),
                responseParser: OpenAIResponseParser()
            )
        case .qwen3ASR:
            return Qwen3ASRProvider(
                configuration: configuration,
                apiKey: apiKey,
                transport: qwenTransportFactory(),
                requestBuilder: Qwen3ASRRequestBuilder(),
                responseParser: Qwen3ASRResponseParser()
            )
        case .speechAnalyzer:
            fatalError("Unreachable")
        }
    }
}
