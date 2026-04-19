import Foundation

nonisolated enum HUDState: Equatable {
    case hidden
    case tentativeCapture
    case recording
    case transcribing
    case canceled
    case noSpeech
    case permissionBlocked
    case audioInputUnavailable
    case providerFailed(ProviderFailure)
    case insertionFailed(InsertionFailureCategory)
}

extension HUDState {
    nonisolated var autoDismissDelay: Duration? {
        switch self {
        case .hidden, .tentativeCapture, .recording, .transcribing:
            nil
        case .canceled:
            .milliseconds(600)
        case .noSpeech:
            .milliseconds(1500)
        case .permissionBlocked, .audioInputUnavailable, .providerFailed, .insertionFailed:
            .seconds(3)
        }
    }
}
