import Foundation

struct ProviderEndpointURL {
    let url: URL

    nonisolated init(_ rawValue: String) throws {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedValue),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            throw TranscriptionProviderError.invalidConfiguration
        }

        self.url = url
    }
}
