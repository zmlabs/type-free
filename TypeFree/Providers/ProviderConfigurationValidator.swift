import Foundation

protocol ProviderConfigurationValidating: Sendable {
    func validate(
        snapshot: ProviderConfigurationSnapshot,
        apiKey: String
    ) throws
}

struct ProviderConfigurationValidator: ProviderConfigurationValidating {
    private let openAIRequestBuilder: OpenAIRequestBuilder
    private let qwenRequestBuilder: Qwen3ASRRequestBuilder

    init(
        openAIRequestBuilder: OpenAIRequestBuilder = OpenAIRequestBuilder(),
        qwenRequestBuilder: Qwen3ASRRequestBuilder = Qwen3ASRRequestBuilder()
    ) {
        self.openAIRequestBuilder = openAIRequestBuilder
        self.qwenRequestBuilder = qwenRequestBuilder
    }

    func validate(
        snapshot: ProviderConfigurationSnapshot,
        apiKey: String
    ) throws {
        switch snapshot.kind {
        case .openAICompatible:
            _ = try openAIRequestBuilder.build(
                capture: validationCapture,
                configuration: snapshot,
                apiKey: apiKey
            )
        case .qwen3ASR:
            _ = try qwenRequestBuilder.buildValidationRequest(
                configuration: snapshot,
                apiKey: apiKey
            )
        case .speechAnalyzer:
            break
        }
    }

    private var validationCapture: PreparedCapture {
        PreparedCapture(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("provider-validation.wav"),
            duration: 0.1,
            sampleRate: 16000,
            channelCount: 1,
            activationScreenID: "provider-settings"
        )
    }
}
