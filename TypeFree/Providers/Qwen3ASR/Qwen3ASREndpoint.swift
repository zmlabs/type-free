import Foundation

nonisolated enum Qwen3ASREndpoint {
    static let generationPath = "/services/aigc/multimodal-generation/generation"
    private static let apiBasePath = "/api/v1"

    static func validateBaseURL(_ rawBaseURL: String) throws {
        let baseURL = try ProviderEndpointURL(rawBaseURL).url
        let normalizedBasePath = normalizedPath(baseURL.path)
        let normalizedGenerationPath = normalizedPath(generationPath)

        guard !normalizedBasePath.hasSuffix(normalizedGenerationPath) else {
            throw TranscriptionProviderError.invalidConfiguration
        }
    }

    static func makeEndpointURL(from rawBaseURL: String) throws -> URL {
        let baseURL = try ProviderEndpointURL(rawBaseURL).url
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw TranscriptionProviderError.invalidConfiguration
        }

        let normalizedBasePath = normalizedPath(components.path)
        let normalizedGenerationPath = normalizedPath(generationPath)

        guard !normalizedBasePath.hasSuffix(normalizedGenerationPath) else {
            throw TranscriptionProviderError.invalidConfiguration
        }

        components.query = nil
        components.fragment = nil

        if normalizedBasePath.isEmpty {
            components.path = "\(apiBasePath)\(generationPath)"
        } else {
            components.path = "/\(normalizedBasePath)/\(normalizedGenerationPath)"
        }

        guard let endpointURL = components.url else {
            throw TranscriptionProviderError.invalidConfiguration
        }

        return endpointURL
    }

    private static func normalizedPath(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
