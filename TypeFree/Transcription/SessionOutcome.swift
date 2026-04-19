import Foundation

nonisolated enum SessionOutcome: Equatable {
    case completed(text: String)
    case canceled
    case noSpeech
    case permissionBlocked
    case providerFailed(ProviderFailure)
    case insertionFailed(InsertionFailureCategory)
}
