import Foundation
import Testing
@testable import TypeFree

@MainActor
struct ProviderAdapterContractTests {
    @Test
    func openAICompatibleProviderBuildsMultipartUploadAndReturnsTranscript() async throws {
        let transport = TestOpenAITransport()
        let provider = OpenAICompatibleProvider(
            configuration: .fixture(),
            apiKey: "sk-test",
            transport: transport,
            requestBuilder: OpenAIRequestBuilder(),
            responseParser: OpenAIResponseParser()
        )
        await transport.enqueue(
            result: .success(
                .init(
                    statusCode: 200,
                    data: Data(#"{"text":" hello world "}"#.utf8)
                )
            )
        )

        let output = try await provider.transcribe(capture: .fixture())
        let request = try #require(await transport.lastRequest())
        let expectedFileURL = PreparedCapture.fixture().fileURL
        let expectedFilePart = OpenAIUploadPart.file(
            name: "file",
            fileURL: expectedFileURL,
            fileName: expectedFileURL.lastPathComponent,
            mimeType: "audio/wav"
        )

        #expect(output == .transcript(.init(text: "hello world")))
        #expect(request.url.absoluteString == "https://api.openai.com/v1/audio/transcriptions")
        #expect(request.timeoutInterval == 30)
        #expect(request.headerFields["Authorization"] == "Bearer sk-test")
        #expect(request.parts.contains(.text(name: "model", value: "whisper-1")))
        #expect(request.parts.contains(.text(name: "language", value: "en")))
        #expect(request.parts.contains(expectedFilePart))
    }

    @Test
    func openAICompatibleProviderMapsBlankResponsesToNoSpeech() async throws {
        let transport = TestOpenAITransport()
        let provider = OpenAICompatibleProvider(
            configuration: .fixture(languageHint: nil),
            apiKey: "sk-test",
            transport: transport,
            requestBuilder: OpenAIRequestBuilder(),
            responseParser: OpenAIResponseParser()
        )
        await transport.enqueue(result: .success(.init(statusCode: 200, data: Data(#"{"text":"   "}"#.utf8))))

        let output = try await provider.transcribe(capture: .fixture())
        let request = try #require(await transport.lastRequest())

        #expect(output == .noSpeech)
        #expect(!request.parts.contains(where: { part in
            if case .text(name: "language", value: _) = part { return true }
            return false
        }))
    }

    @Test
    func openAICompatibleProviderDoesNotRetryAutomaticallyOnTimeout() async {
        let transport = TestOpenAITransport()
        let provider = OpenAICompatibleProvider(
            configuration: .fixture(),
            apiKey: "sk-test",
            transport: transport,
            requestBuilder: OpenAIRequestBuilder(),
            responseParser: OpenAIResponseParser()
        )
        await transport.enqueue(result: .failure(.timeout))

        do {
            _ = try await provider.transcribe(capture: .fixture())
            Issue.record("Expected provider timeout to fail")
        } catch let error as TranscriptionProviderError {
            #expect(error == .timeout)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(await transport.uploadCount() == 1)
    }
}

private actor TestOpenAITransport: OpenAITransporting {
    private var queuedResults: [Result<OpenAITransportResponse, TranscriptionProviderError>] = []
    private var capturedRequests: [OpenAIUploadRequest] = []

    func enqueue(result: Result<OpenAITransportResponse, TranscriptionProviderError>) {
        queuedResults.append(result)
    }

    func upload(_ request: OpenAIUploadRequest) async throws -> OpenAITransportResponse {
        capturedRequests.append(request)
        return try queuedResults.removeFirst().get()
    }

    func lastRequest() -> OpenAIUploadRequest? {
        capturedRequests.last
    }

    func uploadCount() -> Int {
        capturedRequests.count
    }
}

@MainActor
private extension ProviderConfigurationSnapshot {
    static func fixture(
        kind: ProviderKind = .openAICompatible,
        baseURL: String = "https://api.openai.com/v1/audio/transcriptions",
        modelIdentifier: String = "whisper-1",
        languageHint: String? = "en",
        timeoutSeconds: Int = 30,
        apiKeyReference: String = "active-key"
    ) -> ProviderConfigurationSnapshot {
        ProviderConfigurationSnapshot(
            kind: kind,
            baseURL: baseURL,
            modelIdentifier: modelIdentifier,
            languageHint: languageHint,
            requestTimeoutSeconds: timeoutSeconds,
            apiKeyReference: apiKeyReference
        )
    }
}

@MainActor
private extension PreparedCapture {
    static func fixture(
        fileURL: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("capture.wav")
    ) -> PreparedCapture {
        PreparedCapture(
            fileURL: fileURL,
            duration: 1.2,
            sampleRate: 16000,
            channelCount: 1,
            activationScreenID: "screen-a"
        )
    }
}
