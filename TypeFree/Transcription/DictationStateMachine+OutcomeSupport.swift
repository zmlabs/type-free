import Foundation

extension DictationStateMachine {
    nonisolated func shouldReset(phase: DictationPhase) -> Bool {
        switch phase {
        case .canceled, .noSpeech, .permissionBlocked, .audioInputUnavailable, .providerFailed, .insertionFailed:
            true
        default:
            false
        }
    }

    nonisolated func canHandleTerminalOutcome(_ outcome: SessionOutcome) -> Bool {
        switch phase {
        case .transcribing:
            true
        case .tentativeCapture, .recordingVisible:
            switch outcome {
            case .permissionBlocked, .audioInputUnavailable, .providerFailed:
                true
            default:
                false
            }
        default:
            false
        }
    }
}

extension SessionOutcome {
    nonisolated var workflowHUDState: HUDState? {
        switch self {
        case .completed:
            nil
        case .canceled:
            .canceled
        case .noSpeech:
            .noSpeech
        case .permissionBlocked:
            .permissionBlocked
        case .audioInputUnavailable:
            .audioInputUnavailable
        case let .providerFailed(failure):
            .providerFailed(failure)
        case let .insertionFailed(category):
            .insertionFailed(category)
        }
    }

    nonisolated var workflowPhase: DictationPhase {
        switch self {
        case .completed:
            .idle
        case .canceled:
            .canceled
        case .noSpeech:
            .noSpeech
        case .permissionBlocked:
            .permissionBlocked
        case .audioInputUnavailable:
            .audioInputUnavailable
        case .providerFailed:
            .providerFailed
        case .insertionFailed:
            .insertionFailed
        }
    }
}
