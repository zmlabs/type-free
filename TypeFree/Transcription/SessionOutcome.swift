import Foundation

nonisolated enum SessionOutcome: Equatable {
    case completed(text: String)
    case canceled
    case noSpeech
    case permissionBlocked
    case audioInputUnavailable
    case providerFailed(ProviderFailure)
    case insertionFailed(InsertionFailureCategory)
}
