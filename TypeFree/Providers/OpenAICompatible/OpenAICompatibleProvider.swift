import Alamofire
import Foundation

struct OpenAITransportResponse: Equatable {
    let statusCode: Int
    let data: Data
}

protocol OpenAITransporting: Sendable {
    func upload(_ request: OpenAIUploadRequest) async throws -> OpenAITransportResponse
}

nonisolated final class OpenAICompatibleProvider: TranscriptionProvider {
    let kind: ProviderKind = .openAICompatible

    private let configuration: ProviderConfigurationSnapshot
    private let apiKey: String
    private let transport: any OpenAITransporting
    private let requestBuilder: OpenAIRequestBuilder
    private let responseParser: OpenAIResponseParser

    init(
        configuration: ProviderConfigurationSnapshot,
        apiKey: String,
        transport: any OpenAITransporting,
        requestBuilder: OpenAIRequestBuilder,
        responseParser: OpenAIResponseParser
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

nonisolated struct AlamofireOpenAITransport: OpenAITransporting {
    private let session: Session

    init(session: Session = AF) {
        self.session = session
    }

    func upload(_ request: OpenAIUploadRequest) async throws -> OpenAITransportResponse {
        let headers = HTTPHeaders(
            request.headerFields.map { key, value in
                HTTPHeader(name: key, value: value)
            }
        )
        let uploadRequest = session.upload(
            multipartFormData: { multipartFormData in
                appendParts(request.parts, to: multipartFormData)
            },
            to: request.url,
            method: .post,
            headers: headers,
            requestModifier: { urlRequest in
                urlRequest.timeoutInterval = request.timeoutInterval
            }
        )
        let response = await withTaskCancellationHandler {
            await uploadRequest.serializingData().response
        } onCancel: {
            uploadRequest.cancel()
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
                message: "Provider 未返回 HTTP 状态码。"
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
                message: "Provider 未返回响应体。"
            )
        }

        return OpenAITransportResponse(
            statusCode: statusCode,
            data: data
        )
    }

    private func appendParts(
        _ parts: [OpenAIUploadPart],
        to multipartFormData: MultipartFormData
    ) {
        for part in parts {
            switch part {
            case let .text(name, value):
                multipartFormData.append(
                    Data(value.utf8),
                    withName: name
                )
            case let .file(name, fileURL, fileName, mimeType):
                multipartFormData.append(
                    fileURL,
                    withName: name,
                    fileName: fileName,
                    mimeType: mimeType
                )
            }
        }
    }

    private func transportDiagnostics(
        for request: OpenAIUploadRequest,
        response: AFDataResponse<Data>
    ) -> ProviderTransportDiagnostics {
        let urlCode = (response.error?.underlyingError as? URLError)?.code
        let statusCode = response.response?.statusCode
        return ProviderTransportDiagnostics(
            endpoint: request.url.absoluteString,
            hasAuthorizationHeader: hasAuthorizationHeader(in: request),
            requestFileName: requestFileName(in: request),
            requestMimeType: requestMimeType(in: request),
            statusCode: statusCode,
            responseSnippet: responseSnippet(from: response.data),
            underlyingError: response.error.map { String(describing: $0) },
            urlErrorCode: urlCode,
            httpStatusClass: statusCode.map(HTTPStatusClass.init)
        )
    }

    private func hasAuthorizationHeader(in request: OpenAIUploadRequest) -> Bool {
        guard let value = request.headerFields["Authorization"] else {
            return false
        }

        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func requestFileName(in request: OpenAIUploadRequest) -> String? {
        for part in request.parts {
            if case let .file(_, _, fileName, _) = part {
                return fileName
            }
        }

        return nil
    }

    private func requestMimeType(in request: OpenAIUploadRequest) -> String? {
        for part in request.parts {
            if case let .file(_, _, _, mimeType) = part {
                return mimeType
            }
        }

        return nil
    }
}
