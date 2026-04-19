import Foundation

protocol TranscriptionDriving: Sendable {
    func startTranscribing(sessionID: UUID, capture: PreparedCapture) async throws -> SessionOutcome
}

struct ProviderBackedTranscriptionDriver: TranscriptionDriving {
    typealias ActiveProviderResolver = @MainActor @Sendable () async throws -> any TranscriptionProvider

    private let activeProviderResolver: ActiveProviderResolver
    private let textInserter: any AccessibilityTextInserting
    private let logger: any TranscriptionLogging

    init(
        activeProviderResolver: @escaping ActiveProviderResolver,
        textInserter: any AccessibilityTextInserting = TextInjector(),
        logger: any TranscriptionLogging = UnifiedTranscriptionLogger()
    ) {
        self.activeProviderResolver = activeProviderResolver
        self.textInserter = textInserter
        self.logger = logger
    }

    func startTranscribing(sessionID _: UUID, capture: PreparedCapture) async throws -> SessionOutcome {
        do {
            let provider = try await resolveProvider()
            let output = try await transcribe(capture: capture, with: provider)
            return try await finish(output: output)
        } catch let error as SessionOutcomeFailure {
            switch error {
            case let .provider(failure):
                return .providerFailed(failure)
            case let .insertion(category):
                return .insertionFailed(category)
            }
        }
    }

    private func describe(_ error: any Error) -> String {
        if let error = error as? TranscriptionProviderError {
            return error.diagnosticDescription
        }

        return String(describing: error)
    }

    private func resolveProvider() async throws -> any TranscriptionProvider {
        do {
            return try await activeProviderResolver()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as TranscriptionProviderError {
            if error == .cancelled {
                throw CancellationError()
            }

            await logger.record(
                .activeProviderResolutionFailed(errorDescription: describe(error))
            )
            throw SessionOutcomeFailure.provider(error.failure ?? .unavailable())
        } catch {
            await logger.record(
                .unexpectedFailure(
                    stage: "activeProviderResolver",
                    errorDescription: describe(error)
                )
            )
            throw SessionOutcomeFailure.provider(.unavailable())
        }
    }

    private func transcribe(
        capture: PreparedCapture,
        with provider: any TranscriptionProvider
    ) async throws -> TranscriptionProviderOutput {
        do {
            return try await provider.transcribe(capture: capture)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as TranscriptionProviderError {
            if error == .cancelled {
                throw CancellationError()
            }

            await logger.record(
                .providerTranscriptionFailed(errorDescription: describe(error))
            )
            throw SessionOutcomeFailure.provider(error.failure ?? .unavailable())
        } catch {
            await logger.record(
                .unexpectedFailure(
                    stage: "provider.transcribe",
                    errorDescription: describe(error)
                )
            )
            throw SessionOutcomeFailure.provider(.unavailable())
        }
    }

    private func finish(output: TranscriptionProviderOutput) async throws -> SessionOutcome {
        do {
            switch output {
            case let .transcript(result):
                try Task.checkCancellation()
                try await textInserter.insert(text: result.text)
                return .completed(text: result.text)
            case .noSpeech:
                return .noSpeech
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AccessibilityInsertionError {
            await logger.record(
                .textInsertionFailed(errorDescription: describe(error))
            )
            throw SessionOutcomeFailure.insertion(error.failureCategory)
        } catch {
            await logger.record(
                .unexpectedFailure(
                    stage: "textInserter.insert",
                    errorDescription: describe(error)
                )
            )
            throw SessionOutcomeFailure.provider(.unavailable())
        }
    }
}

private enum SessionOutcomeFailure: Error {
    case provider(ProviderFailure)
    case insertion(InsertionFailureCategory)
}
