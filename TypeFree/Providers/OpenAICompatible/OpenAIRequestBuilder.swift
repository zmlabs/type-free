import Foundation

enum OpenAIUploadPart: Equatable {
    case text(name: String, value: String)
    case file(name: String, fileURL: URL, fileName: String, mimeType: String)
}

struct OpenAIUploadRequest: Equatable {
    let url: URL
    let headerFields: [String: String]
    let timeoutInterval: TimeInterval
    let parts: [OpenAIUploadPart]
}

struct OpenAIRequestBuilder {
    nonisolated func build(
        capture: PreparedCapture,
        configuration: ProviderConfigurationSnapshot,
        apiKey: String
    ) throws -> OpenAIUploadRequest {
        guard let baseURL = configuration.baseURL else {
            throw TranscriptionProviderError.invalidConfiguration
        }
        let endpointURL = try ProviderEndpointURL(baseURL).url

        let trimmedModelIdentifier = configuration.modelIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedModelIdentifier.isEmpty, !trimmedAPIKey.isEmpty else {
            throw TranscriptionProviderError.invalidConfiguration
        }

        let headerFields = [
            "Authorization": "Bearer \(trimmedAPIKey)",
        ]

        var parts: [OpenAIUploadPart] = [
            .text(name: "model", value: trimmedModelIdentifier),
            .file(
                name: "file",
                fileURL: capture.fileURL,
                fileName: capture.fileURL.lastPathComponent,
                mimeType: mimeType(for: capture.fileURL)
            ),
        ]

        if let languageHint = normalized(configuration.languageHint) {
            parts.append(.text(name: "language", value: languageHint))
        }

        return OpenAIUploadRequest(
            url: endpointURL,
            headerFields: headerFields,
            timeoutInterval: TimeInterval(configuration.requestTimeoutSeconds),
            parts: parts
        )
    }

    nonisolated private func normalized(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
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
