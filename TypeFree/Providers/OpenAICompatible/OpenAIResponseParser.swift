import Foundation

struct OpenAIResponseParser {
    nonisolated func parse(data: Data) throws -> TranscriptionProviderOutput {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any]
        else {
            throw TranscriptionProviderError.invalidResponse(
                message: "Provider 返回的不是有效 JSON。"
            )
        }

        guard let text = payload["text"] as? String else {
            let message = extractedMessage(from: payload) ?? normalizedSnippet(from: data)
            let detail = message.map { "Provider 返回体缺少 text 字段：\($0)" }
                ?? "Provider 返回体缺少 text 字段。"
            throw TranscriptionProviderError.invalidResponse(message: detail)
        }

        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedText.isEmpty else {
            return .noSpeech
        }

        return .transcript(
            TranscriptionResult(text: normalizedText)
        )
    }

    nonisolated private func extractedMessage(from payload: [String: Any]) -> String? {
        if let error = payload["error"] as? String {
            return error
        }

        let nestedErrorMessage = (payload["error"] as? [String: Any])?["message"] as? String
        if let nestedErrorMessage {
            return nestedErrorMessage
        }

        if let message = payload["message"] as? String {
            return message
        }

        if let detail = payload["detail"] as? String {
            return detail
        }

        return nil
    }

    nonisolated private func normalizedSnippet(from data: Data) -> String? {
        guard let raw = String(data: data, encoding: .utf8) else {
            return nil
        }

        let normalized = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return nil
        }

        if normalized.count <= 160 {
            return normalized
        }

        let endIndex = normalized.index(normalized.startIndex, offsetBy: 157)
        return "\(normalized[..<endIndex])..."
    }
}
