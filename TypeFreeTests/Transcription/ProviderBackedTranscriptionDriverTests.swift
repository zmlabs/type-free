import Foundation
import Testing
@testable import TypeFree

@MainActor
struct ProviderBackedTranscriptionDriverTests {
    @Test
    func providerResolutionFailureIsLoggedAndMappedToConfigurationFailure() async throws {
        let logger = RecordingTranscriptionLogger()
        let driver = ProviderBackedTranscriptionDriver(
            activeProviderResolver: { throw TranscriptionProviderError.missingCredential },
            textInserter: RecordingTextInserter(),
            logger: logger
        )

        let outcome = try await driver.startTranscribing(
            sessionID: UUID(),
            capture: .fixture()
        )

        #expect(
            outcome == .providerFailed(
                .configuration(detail: "未读取到有效的 API Key，请在 Provider 设置中重新输入并保存。")
            )
        )
        #expect(
            await logger.events() == [
                .activeProviderResolutionFailed(
                    errorDescription: "Missing or unreadable provider credential"
                ),
            ]
        )
    }

    @Test
    func providerTransportFailureLogsDiagnosticsAndPreservesActionableDetail() async throws {
        let logger = RecordingTranscriptionLogger()
        let expectedDiagnostic = [
            "Provider transport failed. endpoint=http://localhost:9000/v1/audio/transcriptions",
            "authHeaderPresent=true fileName=recording.wav mimeType=audio/wav statusCode=400",
            "responseSnippet=Missing Authorization header underlyingError=nil",
        ].joined(separator: " ")
        let driver = ProviderBackedTranscriptionDriver(
            activeProviderResolver: {
                FailingTestProvider(
                    error: .transport(
                        ProviderTransportDiagnostics(
                            endpoint: "http://localhost:9000/v1/audio/transcriptions",
                            hasAuthorizationHeader: true,
                            requestFileName: "recording.wav",
                            requestMimeType: "audio/wav",
                            statusCode: 400,
                            responseSnippet: "Missing Authorization header",
                            underlyingError: nil
                        )
                    )
                )
            },
            textInserter: RecordingTextInserter(),
            logger: logger
        )

        let outcome = try await driver.startTranscribing(
            sessionID: UUID(),
            capture: .fixture()
        )

        #expect(
            outcome == .providerFailed(
                .unauthorized(detail: "服务返回 400：Missing Authorization header")
            )
        )
        #expect(
            await logger.events() == [
                .providerTranscriptionFailed(
                    errorDescription: expectedDiagnostic
                ),
            ]
        )
    }

    @Test
    func insertionFailureIsLoggedAndMappedWithoutSilentlyFallingBack() async throws {
        let logger = RecordingTranscriptionLogger()
        let driver = ProviderBackedTranscriptionDriver(
            activeProviderResolver: {
                ImmediateTestProvider(
                    output: .transcript(.init(text: "cannot insert"))
                )
            },
            textInserter: RecordingTextInserter(shouldFail: true),
            logger: logger
        )

        let outcome = try await driver.startTranscribing(
            sessionID: UUID(),
            capture: .fixture()
        )

        #expect(outcome == .insertionFailed(.writeFailed))
        #expect(
            await logger.events() == [
                .textInsertionFailed(errorDescription: "writeFailed"),
            ]
        )
    }
}

private actor RecordingTranscriptionLogger: TranscriptionLogging {
    private var recordedEvents: [TranscriptionLogEvent] = []

    func record(_ event: TranscriptionLogEvent) {
        recordedEvents.append(event)
    }

    func events() -> [TranscriptionLogEvent] {
        recordedEvents
    }
}

private struct FailingTestProvider: TranscriptionProvider {
    let kind: ProviderKind = .openAICompatible
    let error: TranscriptionProviderError

    func transcribe(capture _: PreparedCapture) async throws -> TranscriptionProviderOutput {
        throw error
    }
}
