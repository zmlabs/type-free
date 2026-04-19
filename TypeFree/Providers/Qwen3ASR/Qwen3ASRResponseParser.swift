import Foundation

struct Qwen3ASRResponseParser {
    nonisolated func parse(data: Data) throws -> TranscriptionProviderOutput {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any]
        else {
            throw TranscriptionProviderError.invalidResponse(
                message: "Provider did not return valid JSON."
            )
        }

        guard let text = extractedText(from: payload) else {
            let message = extractedMessage(from: payload) ?? normalizedSnippet(from: data)
            let detail = message.map {
                "Provider response is missing the output.choices[0].message.content[0].text field: \($0)"
            } ?? "Provider response is missing the output.choices[0].message.content[0].text field."
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

    nonisolated private func extractedText(from payload: [String: Any]) -> String? {
        let output = payload["output"] as? [String: Any]
        let choices = output?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? [[String: Any]]
        return content?.first?["text"] as? String
    }

    nonisolated private func extractedDuration(from payload: [String: Any]) -> TimeInterval? {
        let usage = payload["usage"] as? [String: Any]

        if let seconds = usage?["seconds"] as? Double {
            return seconds
        }

        if let seconds = usage?["seconds"] as? NSNumber {
            return seconds.doubleValue
        }

        return nil
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
