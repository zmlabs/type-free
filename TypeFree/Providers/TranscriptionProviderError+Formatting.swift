import Foundation

extension TranscriptionProviderError {
    var failure: ProviderFailure? {
        switch self {
        case let .unsupportedProviderKind(kind):
            .configuration(detail: "不支持的 Provider 类型：\(kind)。")
        case .invalidConfiguration:
            .configuration(detail: "Provider 配置无效，请检查 Endpoint URL、模型标识和 API Key。")
        case .missingCredential:
            .configuration(detail: "未读取到有效的 API Key，请在 Provider 设置中重新输入并保存。")
        case .unauthorized:
            .unauthorized(detail: "Provider 鉴权失败，请检查 API Key 和 Authorization 头。")
        case .timeout:
            .timeout(detail: "请求超时，请检查服务状态和网络连接。")
        case let .transport(diagnostics):
            Self.transportFailure(from: diagnostics)
        case let .invalidResponse(message):
            .invalidResponse(
                detail: message ?? "Provider 返回体不符合 OpenAI 转录兼容格式。"
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
            return "服务返回 \(statusCode)：\(snippet)"
        }

        if let statusCode = diagnostics.statusCode {
            return "服务返回 \(statusCode)。"
        }

        if let snippet = normalizedSnippet(diagnostics.responseSnippet ?? diagnostics.underlyingError) {
            return "请求失败：\(snippet)"
        }

        return "请求失败，请检查服务端日志和网络连接。"
    }

    static func formattedUnauthorizedDetail(
        from diagnostics: ProviderTransportDiagnostics
    ) -> String {
        let snippet = normalizedSnippet(diagnostics.responseSnippet ?? diagnostics.underlyingError)

        if let statusCode = diagnostics.statusCode, let snippet {
            return "服务返回 \(statusCode)：\(snippet)"
        }

        if let statusCode = diagnostics.statusCode {
            return "服务返回 \(statusCode)，请检查 API Key 和 Authorization 头。"
        }

        if let snippet = normalizedSnippet(diagnostics.responseSnippet ?? diagnostics.underlyingError) {
            return "鉴权失败：\(snippet)"
        }

        return "鉴权失败，请检查 API Key 和 Authorization 头。"
    }

    static func formattedTimeoutDetail(
        from diagnostics: ProviderTransportDiagnostics
    ) -> String {
        let snippet = normalizedSnippet(diagnostics.responseSnippet ?? diagnostics.underlyingError)

        if let statusCode = diagnostics.statusCode, let snippet {
            return "服务返回 \(statusCode)：\(snippet)"
        }

        if let statusCode = diagnostics.statusCode {
            return "服务返回 \(statusCode)，请求已超时。"
        }

        if let snippet = normalizedSnippet(diagnostics.responseSnippet ?? diagnostics.underlyingError) {
            let lowered = snippet.lowercased()
            if lowered.contains("timed out") || lowered.contains("timeout") {
                return "请求超时，请检查服务状态和网络连接。"
            }
            return "请求超时：\(snippet)"
        }

        return "请求超时，请检查服务状态和网络连接。"
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
        return """
        Provider transport failed. endpoint=\(diagnostics.endpoint) authHeaderPresent=\(diagnostics
            .hasAuthorizationHeader) fileName=\(fileNameDescription) mimeType=\(
            mimeTypeDescription
        ) statusCode=\(statusDescription) responseSnippet=\(snippetDescription) underlyingError=\(
            errorDescription
        )
        """
    }
}
