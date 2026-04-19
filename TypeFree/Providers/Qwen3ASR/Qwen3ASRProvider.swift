import Alamofire
import Foundation

nonisolated struct Qwen3ASRTransportResponse: Equatable {
    let statusCode: Int
    let data: Data
}

protocol Qwen3ASRTransporting: Sendable {
    func upload(_ request: Qwen3ASRRequest) async throws -> Qwen3ASRTransportResponse
}

nonisolated final class Qwen3ASRProvider: TranscriptionProvider {
    let kind: ProviderKind = .qwen3ASR

    private let configuration: ProviderConfigurationSnapshot
    private let apiKey: String
    private let transport: any Qwen3ASRTransporting
    private let requestBuilder: Qwen3ASRRequestBuilder
    private let responseParser: Qwen3ASRResponseParser

    init(
        configuration: ProviderConfigurationSnapshot,
        apiKey: String,
        transport: any Qwen3ASRTransporting,
        requestBuilder: Qwen3ASRRequestBuilder,
        responseParser: Qwen3ASRResponseParser
    ) {
        self.configuration = configuration
        self.apiKey = apiKey
        self.transport = transport
        self.requestBuilder = requestBuilder
        self.responseParser = responseParser
    }

    func transcribe(capture: PreparedCapture) async throws -> TranscriptionProviderOutput {
        let request = try requestBuilder.build(
            capture: capture,
            configuration: configuration,
            apiKey: apiKey
        )
        let response = try await transport.upload(request)
        return try responseParser.parse(data: response.data)
    }
}

nonisolated struct AlamofireQwen3ASRTransport: Qwen3ASRTransporting {
    private let session: Session

    init(session: Session = AF) {
        self.session = session
    }

    func upload(_ request: Qwen3ASRRequest) async throws -> Qwen3ASRTransportResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = HTTPMethod.post.rawValue
        urlRequest.timeoutInterval = request.timeoutInterval
        for (key, value) in request.headerFields {
            urlRequest.headers.add(name: key, value: value)
        }
        urlRequest.httpBody = request.body

        let dataRequest = session.request(urlRequest)
        let response = await withTaskCancellationHandler {
            await dataRequest.serializingData().response
        } onCancel: {
            dataRequest.cancel()
        }

        if Task.isCancelled || response.error?.isExplicitlyCancelledError == true {
            throw TranscriptionProviderError.cancelled
        }

        let diagnostics = transportDiagnostics(for: request, response: response)

        if let error = response.error, error.isSessionTaskError {
            throw TranscriptionProviderError.transport(diagnostics)
        }

        guard let statusCode = response.response?.statusCode else {
            throw TranscriptionProviderError.invalidResponse(
                message: "Provider did not return an HTTP status code."
            )
        }

        guard (200 ..< 300).contains(statusCode) else {
            throw TranscriptionProviderError.transport(diagnostics)
        }

        if let error = response.error {
            let message = responseSnippet(from: response.data) ?? error.localizedDescription
            throw TranscriptionProviderError.invalidResponse(message: message)
        }

        guard let data = response.data else {
            throw TranscriptionProviderError.invalidResponse(
                message: "Provider did not return a response body."
            )
        }

        return Qwen3ASRTransportResponse(statusCode: statusCode, data: data)
    }

    private func transportDiagnostics(
        for request: Qwen3ASRRequest,
        response: AFDataResponse<Data>
    ) -> ProviderTransportDiagnostics {
        let urlCode = (response.error?.underlyingError as? URLError)?.code
        let statusCode = response.response?.statusCode
        return ProviderTransportDiagnostics(
            endpoint: request.url.absoluteString,
            hasAuthorizationHeader: hasAuthorizationHeader(in: request),
            requestFileName: nil,
            requestMimeType: request.requestMimeType,
            statusCode: statusCode,
            responseSnippet: responseSnippet(from: response.data),
            underlyingError: response.error.map { String(describing: $0) },
            urlErrorCode: urlCode,
            httpStatusClass: statusCode.map(HTTPStatusClass.init)
        )
    }

    private func hasAuthorizationHeader(in request: Qwen3ASRRequest) -> Bool {
        guard let value = request.headerFields["Authorization"] else {
            return false
        }

        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
