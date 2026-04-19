import Foundation

nonisolated enum ProviderFailureCategory: String, Equatable {
    case configuration
    case unauthorized
    case timeout
    case unavailable
    case invalidResponse
}

nonisolated struct ProviderFailure: Equatable {
    let category: ProviderFailureCategory
    let detail: String?
}

extension ProviderFailure {
    nonisolated static func configuration(detail: String? = nil) -> Self {
        .init(category: .configuration, detail: detail)
    }

    nonisolated static func unauthorized(detail: String? = nil) -> Self {
        .init(category: .unauthorized, detail: detail)
    }

    nonisolated static func timeout(detail: String? = nil) -> Self {
        .init(category: .timeout, detail: detail)
    }

    nonisolated static func unavailable(detail: String? = nil) -> Self {
        .init(category: .unavailable, detail: detail)
    }

    nonisolated static func invalidResponse(detail: String? = nil) -> Self {
        .init(category: .invalidResponse, detail: detail)
    }
}

nonisolated enum HTTPStatusClass: Equatable {
    case success(Int)
    case clientError(Int)
    case serverError(Int)
    case other(Int)

    init(_ code: Int) {
        switch code {
        case 200 ..< 300: self = .success(code)
        case 400 ..< 500: self = .clientError(code)
        case 500 ..< 600: self = .serverError(code)
        default: self = .other(code)
        }
    }
}

nonisolated enum TransportFailureClass: Equatable {
    case unauthorized
    case timeout
    case rateLimited
    case unknown
}

nonisolated struct ProviderTransportDiagnostics: Equatable {
    let endpoint: String
    let hasAuthorizationHeader: Bool
    let requestFileName: String?
    let requestMimeType: String?
    let statusCode: Int?
    let responseSnippet: String?
    let underlyingError: String?
    var urlErrorCode: URLError.Code?
    var httpStatusClass: HTTPStatusClass?
    var classification: TransportFailureClass?

    init(
        endpoint: String,
        hasAuthorizationHeader: Bool,
        requestFileName: String?,
        requestMimeType: String?,
        statusCode: Int?,
        responseSnippet: String?,
        underlyingError: String?,
        urlErrorCode: URLError.Code? = nil,
        httpStatusClass: HTTPStatusClass? = nil,
        classification: TransportFailureClass? = nil
    ) {
        self.endpoint = endpoint
        self.hasAuthorizationHeader = hasAuthorizationHeader
        self.requestFileName = requestFileName
        self.requestMimeType = requestMimeType
        self.statusCode = statusCode
        self.responseSnippet = responseSnippet
        self.underlyingError = underlyingError
        self.urlErrorCode = urlErrorCode
        self.httpStatusClass = httpStatusClass
        self.classification = classification
    }
}

nonisolated enum TranscriptionProviderError: Error, Equatable {
    case unsupportedProviderKind(String)
    case invalidConfiguration
    case missingCredential
    case unauthorized
    case timeout
    case cancelled
    case transport(ProviderTransportDiagnostics)
    case invalidResponse(message: String? = nil)
}
