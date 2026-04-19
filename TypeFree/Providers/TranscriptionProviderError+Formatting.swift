import Foundation

extension TranscriptionProviderError {
    var failure: ProviderFailure? {
        switch self {
        case let .unsupportedProviderKind(kind):
            .configuration(detail: "Unsupported provider type: \(kind).")
        case .invalidConfiguration:
            .configuration(
                detail: "Invalid provider configuration. Check the endpoint URL, model identifier, and API key."
            )
        case .missingCredential:
            .configuration(detail: "No valid API key was found. Re-enter and save it in Provider settings.")
        case .unauthorized:
            .unauthorized(detail: "Provider authorization failed. Check the API key and Authorization header.")
        case .timeout:
            .timeout(detail: "The request timed out. Check the service status and network connection.")
        case let .transport(diagnostics):
            Self.transportFailure(from: diagnostics)
        case let .invalidResponse(message):
            .invalidResponse(
                detail: message ?? "The provider response does not match the OpenAI transcription-compatible format."
            )
        case .cancelled:
            nil
        }
    }

    var diagnosticDescription: String {
        switch self {
        case let .unsupportedProviderKind(kind):
            "Unsupported provider kind: \(kind)"
        case .invalidConfiguration:
            "Invalid provider configuration"
        case .missingCredential:
            "Missing or unreadable provider credential"
        case .unauthorized:
            "Unauthorized provider request"
        case .timeout:
            "Provider request timed out"
        case let .transport(diagnostics):
            Self.transportDiagnosticDescription(diagnostics)
        case let .invalidResponse(message):
            if let message, !message.isEmpty {
                "Invalid provider response: \(message)"
            } else {
                "Invalid provider response"
            }
        case .cancelled:
            "Provider request cancelled"
        }
    }
}

private extension TranscriptionProviderError {
    static func transportFailure(
        from diagnostics: ProviderTransportDiagnostics
    ) -> ProviderFailure {
        if isUnauthorized(diagnostics) {
            return .unauthorized(detail: formattedUnauthorizedDetail(from: diagnostics))
        }

        if isTimeout(diagnostics) {
            return .timeout(detail: formattedTimeoutDetail(from: diagnostics))
        }

        return .unavailable(detail: formattedTransportDetail(from: diagnostics))
    }

    static func formattedTransportDetail(
        from diagnostics: ProviderTransportDiagnostics
    ) -> String {
        let snippet = normalizedSnippet(diagnostics.responseSnippet ?? diagnostics.underlyingError)

        if let statusCode = diagnostics.statusCode, let snippet {
            return "The service returned \(statusCode): \(snippet)"
        }

        if let statusCode = diagnostics.statusCode {
            return "The service returned \(statusCode)."
        }

        if let snippet = normalizedSnippet(diagnostics.responseSnippet ?? diagnostics.underlyingError) {
            return "The request failed: \(snippet)"
        }

        return "The request failed. Check the service logs and network connection."
    }

    static func formattedUnauthorizedDetail(
        from diagnostics: ProviderTransportDiagnostics
    ) -> String {
        let snippet = normalizedSnippet(diagnostics.responseSnippet ?? diagnostics.underlyingError)

        if let statusCode = diagnostics.statusCode, let snippet {
            return "The service returned \(statusCode): \(snippet)"
        }

        if let statusCode = diagnostics.statusCode {
            return "The service returned \(statusCode). Check the API key and Authorization header."
        }

        if let snippet = normalizedSnippet(diagnostics.responseSnippet ?? diagnostics.underlyingError) {
            return "Authorization failed: \(snippet)"
        }

        return "Authorization failed. Check the API key and Authorization header."
    }

    static func formattedTimeoutDetail(
        from diagnostics: ProviderTransportDiagnostics
    ) -> String {
        let snippet = normalizedSnippet(diagnostics.responseSnippet ?? diagnostics.underlyingError)

        if let statusCode = diagnostics.statusCode, let snippet {
            return "The service returned \(statusCode): \(snippet)"
        }

        if let statusCode = diagnostics.statusCode {
            return "The service returned \(statusCode), and the request timed out."
        }

        if let snippet = normalizedSnippet(diagnostics.responseSnippet ?? diagnostics.underlyingError) {
            let lowered = snippet.lowercased()
            if lowered.contains("timed out") || lowered.contains("timeout") {
                return "The request timed out. Check the service status and network connection."
            }
            return "The request timed out: \(snippet)"
        }

        return "The request timed out. Check the service status and network connection."
    }

    static func isUnauthorized(_ diagnostics: ProviderTransportDiagnostics) -> Bool {
        if diagnostics.classification == .unauthorized {
            return true
        }

        if case let .clientError(code) = diagnostics.httpStatusClass, [401, 403, 407].contains(code) {
            return true
        }

        let hasAuthorizationHint = containsAuthorizationHint(
            diagnostics.responseSnippet ?? diagnostics.underlyingError
        )
        let isPotentialUnauthorizedStatus = diagnostics.statusCode.map { [400, 401, 403, 407].contains($0) }
            ?? false

        if isPotentialUnauthorizedStatus, hasAuthorizationHint {
            return true
        }

        if let statusCode = diagnostics.statusCode, [401, 403, 407].contains(statusCode) {
            return true
        }

        return hasAuthorizationHint
    }

    static func isTimeout(_ diagnostics: ProviderTransportDiagnostics) -> Bool {
        if diagnostics.classification == .timeout {
            return true
        }

        if diagnostics.urlErrorCode == .timedOut {
            return true
        }

        if let statusCode = diagnostics.statusCode, [408, 504].contains(statusCode) {
            return true
        }

        guard let snippet = diagnostics.underlyingError?.lowercased() else {
            return false
        }

        return snippet.contains("timed out") || snippet.contains("timeout")
    }

    static func containsAuthorizationHint(_ value: String?) -> Bool {
        guard let value = value?.lowercased() else {
            return false
        }

        let hints = [
            "authorization",
            "api key",
            "api-key",
            "bearer",
            "unauthorized",
            "forbidden",
            "invalid_api_key",
        ]
        return hints.contains { value.contains($0) }
    }

    static func transportDiagnosticDescription(
        _ diagnostics: ProviderTransportDiagnostics
    ) -> String {
        let statusDescription = diagnostics.statusCode.map(String.init) ?? "nil"
        let fileNameDescription = normalizedSnippet(diagnostics.requestFileName) ?? "nil"
        let mimeTypeDescription = normalizedSnippet(diagnostics.requestMimeType) ?? "nil"
        let snippetDescription = normalizedSnippet(diagnostics.responseSnippet) ?? "nil"
        let errorDescription = normalizedSnippet(diagnostics.underlyingError) ?? "nil"
        return [
            "Provider transport failed.",
            "endpoint=\(diagnostics.endpoint)",
            "authHeaderPresent=\(diagnostics.hasAuthorizationHeader)",
            "fileName=\(fileNameDescription)",
            "mimeType=\(mimeTypeDescription)",
            "statusCode=\(statusDescription)",
            "responseSnippet=\(snippetDescription)",
            "underlyingError=\(errorDescription)",
        ].joined(separator: " ")
    }
}
