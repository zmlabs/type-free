import Foundation
import Testing
@testable import TypeFree

@MainActor
struct OpenAICompatibleProviderTests {
    @Test(arguments: [
        TranscriptionProviderError.unauthorized,
        TranscriptionProviderError.timeout,
        TranscriptionProviderError.transport(
            ProviderTransportDiagnostics(
                endpoint: "https://api.openai.com/v1/audio/transcriptions",
                hasAuthorizationHeader: true,
                requestFileName: nil,
                requestMimeType: nil,
                statusCode: 503,
                responseSnippet: "upstream unavailable",
                underlyingError: nil
            )
        ),
    ])
    func transcribePropagatesTransportFailuresWithoutRetry(
        failure: TranscriptionProviderError
    ) async {
        let transport = ProviderFailureTransport(result: .failure(failure))
        let provider = OpenAICompatibleProvider(
            configuration: providerConfiguration(),
            apiKey: "sk-test",
            transport: transport,
            requestBuilder: OpenAIRequestBuilder(),
            responseParser: OpenAIResponseParser()
        )

        do {
            _ = try await provider.transcribe(capture: preparedCapture())
            Issue.record("Expected transcribe to throw \(failure)")
        } catch let error as TranscriptionProviderError {
            #expect(error == failure)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(await transport.uploadCount() == 1)
    }

    private func providerConfiguration() -> ProviderConfigurationSnapshot {
        ProviderConfigurationSnapshot(
            kind: .openAICompatible,
            baseURL: "https://api.openai.com/v1/audio/transcriptions",
            modelIdentifier: "whisper-1",
            languageHint: "en",
            requestTimeoutSeconds: 30,
            apiKeyReference: "active-key"
        )
    }

    private func preparedCapture() -> PreparedCapture {
        PreparedCapture(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("provider-failure.wav"),
            duration: 1.0,
            sampleRate: 16000,
            channelCount: 1,
            activationScreenID: "screen-a"
        )
    }
}

private actor ProviderFailureTransport: OpenAITransporting {
    private let result: Result<OpenAITransportResponse, TranscriptionProviderError>
    private var count = 0

    init(result: Result<OpenAITransportResponse, TranscriptionProviderError>) {
        self.result = result
    }

    func upload(_ request: OpenAIUploadRequest) async throws -> OpenAITransportResponse {
        _ = request
        count += 1
        return try result.get()
    }

    func uploadCount() -> Int {
        count
    }
}
