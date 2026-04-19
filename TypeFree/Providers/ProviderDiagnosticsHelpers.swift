import Foundation

nonisolated func normalizedSnippet(_ value: String?) -> String? {
    guard let value else {
        return nil
    }

    let normalized = value
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

nonisolated func extractedErrorMessage(from payload: [String: Any]) -> String? {
    if let error = payload["error"] as? String {
        return error
    }

    if let message = (payload["error"] as? [String: Any])?["message"] as? String {
        return message
    }

    if let message = payload["message"] as? String {
        return message
    }

    if let detail = payload["detail"] as? String {
        return detail
    }

    return nil
}

nonisolated func responseSnippet(from data: Data?) -> String? {
    guard let data else {
        return nil
    }

    let object = try? JSONSerialization.jsonObject(with: data)
    if let payload = object as? [String: Any],
       let message = extractedErrorMessage(from: payload)
    {
        return normalizedSnippet(message)
    }

    guard let raw = String(data: data, encoding: .utf8) else {
        return nil
    }

    return normalizedSnippet(raw)
}
