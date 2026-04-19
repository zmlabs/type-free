import Foundation
import Testing
@testable import TypeFree

struct Qwen3ASRRequestBuilderTests {
    @Test
    func buildCreatesDashScopeJSONRequestWithAudioDataURLAndOptionalLanguage() throws {
        let builder = Qwen3ASRRequestBuilder()
        let fileURL = try audioFixtureURL(pathExtension: "wav", data: Data([0x52, 0x49, 0x46, 0x46]))

        let request = try builder.build(
            capture: PreparedCapture(
                fileURL: fileURL,
                duration: 1.0,
                sampleRate: 16000,
                channelCount: 1,
                activationScreenID: "screen-a"
            ),
            configuration: .qwenFixture(modelIdentifier: "qwen3-asr-custom", languageHint: "zh"),
            apiKey: "sk-qwen"
        )

        let payload = try #require(jsonObject(from: request.body) as? [String: Any])
        let input = try #require(payload["input"] as? [String: Any])
        let messages = try #require(input["messages"] as? [[String: Any]])
        let firstMessage = try #require(messages.first)
        let content = try #require(firstMessage["content"] as? [[String: Any]])
        let audio = try #require(content.first?["audio"] as? String)
        let parameters = try #require(payload["parameters"] as? [String: Any])
        let asrOptions = try #require(parameters["asr_options"] as? [String: Any])

        #expect(
            request.url.absoluteString
                == "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
        )
        #expect(request.headerFields["Authorization"] == "Bearer sk-qwen")
        #expect(request.headerFields["Content-Type"] == "application/json")
        #expect(payload["model"] as? String == "qwen3-asr-custom")
        #expect(firstMessage["role"] as? String == "user")
        #expect(audio == "data:audio/wav;base64,UklGRg==")
        #expect(asrOptions["enable_itn"] as? Bool == false)
        #expect(asrOptions["language"] as? String == "zh")
    }

    @Test
    func buildUsesConfiguredEnableITNValue() throws {
        let builder = Qwen3ASRRequestBuilder()

        let request = try builder.buildValidationRequest(
            configuration: .qwenFixture(
                baseURL: "https://dashscope-intl.aliyuncs.com/api/v1",
                languageHint: nil,
                enableITN: true
            ),
            apiKey: "sk-qwen"
        )

        let payload = try #require(jsonObject(from: request.body) as? [String: Any])
        let parameters = try #require(payload["parameters"] as? [String: Any])
        let asrOptions = try #require(parameters["asr_options"] as? [String: Any])

        #expect(
            request.url.absoluteString
                == "https://dashscope-intl.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
        )
        #expect(asrOptions["enable_itn"] as? Bool == true)
    }

    @Test
    func buildValidationRequestRejectsEndpointURLInBaseURLField() {
        let builder = Qwen3ASRRequestBuilder()

        #expect(throws: TranscriptionProviderError.invalidConfiguration) {
            try builder.buildValidationRequest(
                configuration: .qwenFixture(
                    baseURL: "https://dashscope-intl.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation",
                    languageHint: nil,
                    enableITN: true
                ),
                apiKey: "sk-qwen"
            )
        }
    }

    @Test
    func buildValidationRequestUsesPlaceholderDataURLWithoutReadingAudioFile() throws {
        let builder = Qwen3ASRRequestBuilder()

        let request = try builder.buildValidationRequest(
            configuration: .qwenFixture(languageHint: nil),
            apiKey: "sk-qwen"
        )

        let payload = try #require(jsonObject(from: request.body) as? [String: Any])
        let input = try #require(payload["input"] as? [String: Any])
        let messages = try #require(input["messages"] as? [[String: Any]])
        let firstMessage = try #require(messages.first)
        let content = try #require(firstMessage["content"] as? [[String: Any]])
        let audio = try #require(content.first?["audio"] as? String)
        let parameters = try #require(payload["parameters"] as? [String: Any])
        let asrOptions = try #require(parameters["asr_options"] as? [String: Any])

        #expect(audio == "data:audio/wav;base64,AA==")
        #expect(asrOptions["language"] == nil)
    }
}

private extension ProviderConfigurationSnapshot {
    static func qwenFixture(
        baseURL: String = "https://dashscope.aliyuncs.com/api/v1",
        modelIdentifier: String = ProviderKind.qwen3ASR.defaultModelIdentifier,
        languageHint: String?,
        enableITN: Bool = false,
        apiKeyReference: String = "qwen-reference"
    ) -> ProviderConfigurationSnapshot {
        ProviderConfigurationSnapshot(
            kind: .qwen3ASR,
            baseURL: baseURL,
            modelIdentifier: modelIdentifier,
            languageHint: languageHint,
            enableITN: enableITN,
            requestTimeoutSeconds: 30,
            apiKeyReference: apiKeyReference
        )
    }
}

private func audioFixtureURL(pathExtension: String, data: Data) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(pathExtension)
    try data.write(to: url)
    return url
}

private func jsonObject(from data: Data) throws -> Any {
    try JSONSerialization.jsonObject(with: data)
}
