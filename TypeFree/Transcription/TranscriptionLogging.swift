import Foundation
import OSLog

nonisolated enum TranscriptionLogEvent: Equatable {
    case activeProviderResolutionFailed(errorDescription: String)
    case providerTranscriptionFailed(errorDescription: String)
    case textInsertionFailed(errorDescription: String)
    case unexpectedFailure(stage: String, errorDescription: String)
}

protocol TranscriptionLogging: Actor {
    func record(_ event: TranscriptionLogEvent)
}

actor UnifiedTranscriptionLogger: TranscriptionLogging {
    private let logger: Logger

    init(subsystem: String = Bundle.main.bundleIdentifier ?? "dev.zhangyu.TypeFree") {
        logger = Logger(subsystem: subsystem, category: "Transcription")
    }

    func record(_ event: TranscriptionLogEvent) {
        switch event {
        case let .activeProviderResolutionFailed(errorDescription):
            logger.error("Active provider resolution failed: \(errorDescription)")
        case let .providerTranscriptionFailed(errorDescription):
            logger.error("Provider transcription failed: \(errorDescription)")
        case let .textInsertionFailed(errorDescription):
            logger.error("Text insertion failed: \(errorDescription)")
        case let .unexpectedFailure(stage, errorDescription):
            logger.error("Unexpected transcription failure at \(stage): \(errorDescription)")
        }
    }
}
