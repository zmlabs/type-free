import Foundation

nonisolated struct Qwen3ASRRequest: Equatable {
    let url: URL
    let headerFields: [String: String]
    let timeoutInterval: TimeInterval
    let body: Data
    let requestMimeType: String?
}

struct Qwen3ASRRequestBuilder {
    nonisolated func build(
        capture: PreparedCapture,
        configuration: ProviderConfigurationSnapshot,
        apiKey: String
    ) throws -> Qwen3ASRRequest {
        let mimeType = mimeType(for: capture.fileURL)
        let audioData = try Data(contentsOf: capture.fileURL)
        let audioDataURL = dataURL(for: audioData, mimeType: mimeType)

        return try build(
            audioDataURL: audioDataURL,
            requestMimeType: mimeType,
            configuration: configuration,
            apiKey: apiKey
        )
    }

    nonisolated func buildValidationRequest(
        configuration: ProviderConfigurationSnapshot,
        apiKey: String
    ) throws -> Qwen3ASRRequest {
        try build(
            audioDataURL: "data:audio/wav;base64,AA==",
            requestMimeType: "audio/wav",
            configuration: configuration,
            apiKey: apiKey
        )
    }

    nonisolated private func build(
        audioDataURL: String,
        requestMimeType: String,
        configuration: ProviderConfigurationSnapshot,
        apiKey: String
    ) throws -> Qwen3ASRRequest {
        guard let baseURL = configuration.baseURL else {
            throw TranscriptionProviderError.invalidConfiguration
        }
        let endpointURL = try Qwen3ASREndpoint.makeEndpointURL(from: baseURL)
        let trimmedModelIdentifier = configuration.modelIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedModelIdentifier.isEmpty, !trimmedAPIKey.isEmpty else {
            throw TranscriptionProviderError.invalidConfiguration
        }

        let body = try JSONSerialization.data(
            withJSONObject: requestBody(
                modelIdentifier: trimmedModelIdentifier,
                audioDataURL: audioDataURL,
                languageHint: normalized(configuration.languageHint),
                enableITN: configuration.enableITN
            )
        )

        return Qwen3ASRRequest(
            url: endpointURL,
            headerFields: [
                "Authorization": "Bearer \(trimmedAPIKey)",
                "Content-Type": "application/json",
            ],
            timeoutInterval: TimeInterval(configuration.requestTimeoutSeconds),
            body: body,
            requestMimeType: requestMimeType
        )
    }

    nonisolated private func requestBody(
        modelIdentifier: String,
        audioDataURL: String,
        languageHint: String?,
        enableITN: Bool
    ) -> [String: Any] {
        var asrOptions: [String: Any] = [
            "enable_itn": enableITN,
        ]

        if let languageHint {
            asrOptions["language"] = languageHint
        }

        return [
            "model": modelIdentifier,
            "input": [
                "messages": [
                    [
                        "role": "user",
                        "content": [
                            [
                                "audio": audioDataURL,
                            ],
                        ],
                    ],
                ],
            ],
            "parameters": [
                "asr_options": asrOptions,
            ],
        ]
    }

    nonisolated private func normalized(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    nonisolated private func dataURL(for data: Data, mimeType: String) -> String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    nonisolated private func mimeType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "wav":
            "audio/wav"
        case "m4a":
            "audio/m4a"
        case "mp3":
            "audio/mpeg"
        default:
            "application/octet-stream"
        }
    }
}
