import Foundation

nonisolated enum ProviderKind: String, CaseIterable {
    case openAICompatible
    case qwen3ASR
    case speechAnalyzer
}

extension ProviderKind {
    nonisolated var title: String {
        switch self {
        case .openAICompatible: "OpenAI Compatible"
        case .qwen3ASR: "Qwen3 ASR"
        case .speechAnalyzer: "SpeechAnalyzer"
        }
    }

    nonisolated var requiresCredential: Bool {
        switch self {
        case .openAICompatible, .qwen3ASR: true
        case .speechAnalyzer: false
        }
    }

    nonisolated var requiresBaseURL: Bool {
        switch self {
        case .openAICompatible, .qwen3ASR: true
        case .speechAnalyzer: false
        }
    }

    nonisolated var defaultBaseURL: String {
        switch self {
        case .openAICompatible: "https://api.openai.com/v1/audio/transcriptions"
        case .qwen3ASR: "https://dashscope.aliyuncs.com/api/v1"
        case .speechAnalyzer: ""
        }
    }

    nonisolated var defaultModelIdentifier: String {
        switch self {
        case .openAICompatible: "whisper-1"
        case .qwen3ASR: "qwen3-asr-flash"
        case .speechAnalyzer: ""
        }
    }

    nonisolated var defaultRequestTimeoutSeconds: Int {
        switch self {
        case .openAICompatible, .qwen3ASR: 30
        case .speechAnalyzer: 60
        }
    }

    nonisolated var defaultEnableITN: Bool {
        false
    }
}
