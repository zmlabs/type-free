import Foundation
import Testing
@testable import TypeFree

@MainActor
struct Qwen3ASRProviderTests {
    @Test(arguments: [
        TranscriptionProviderError.unauthorized,
        TranscriptionProviderError.timeout,
        TranscriptionProviderError.transport(
            ProviderTransportDiagnostics(
                endpoint: ProviderKind.qwen3ASR.defaultBaseURL,
                hasAuthorizationHeader: true,
                requestFileName: nil,
                requestMimeType: "audio/wav",
                statusCode: 503,
                responseSnippet: "upstream unavailable",
                underlyingError: nil
            )
        ),
    ])
    func transcribePropagatesTransportFailuresWithoutRetry(
        failure: TranscriptionProviderError
    ) async throws {
        let transport = ProviderFailureQwenTransport(result: .failure(failure))
        let provider = Qwen3ASRProvider(
            configuration: .qwenFixture(languageHint: "zh"),
            apiKey: "sk-qwen",
            transport: transport,
            requestBuilder: Qwen3ASRRequestBuilder(),
            responseParser: Qwen3ASRResponseParser()
        )
        let capture = try preparedCapture()

        do {
            _ = try await provider.transcribe(capture: capture)
            Issue.record("Expected transcribe to throw \(failure)")
        } catch let error as TranscriptionProviderError {
            #expect(error == failure)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(await transport.uploadCount() == 1)
    }

    private func preparedCapture() throws -> PreparedCapture {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: fileURL)

        return PreparedCapture(
            fileURL: fileURL,
            duration: 1.0,
            sampleRate: 16000,
            channelCount: 1,
            activationScreenID: "screen-a"
        )
    }
}

private extension ProviderConfigurationSnapshot {
    static func qwenFixture(
        languageHint: String?,
        apiKeyReference: String = "qwen-reference"
    ) -> ProviderConfigurationSnapshot {
        ProviderConfigurationSnapshot(
            kind: .qwen3ASR,
            baseURL: ProviderKind.qwen3ASR.defaultBaseURL,
            modelIdentifier: ProviderKind.qwen3ASR.defaultModelIdentifier,
            languageHint: languageHint,
            requestTimeoutSeconds: 30,
            apiKeyReference: apiKeyReference
        )
    }
}

private actor ProviderFailureQwenTransport: Qwen3ASRTransporting {
    private let result: Result<Qwen3ASRTransportResponse, TranscriptionProviderError>
    private var count = 0

    init(result: Result<Qwen3ASRTransportResponse, TranscriptionProviderError>) {
        self.result = result
    }

    func upload(_ request: Qwen3ASRRequest) async throws -> Qwen3ASRTransportResponse {
        _ = request
        count += 1
        return try result.get()
    }

    func uploadCount() -> Int {
        count
    }
}
