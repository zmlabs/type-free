import Foundation

nonisolated enum DictationPhase: String, Equatable, Codable, CaseIterable {
    case idle
    case tentativeCapture
    case recordingVisible
    case transcribing
    case canceled
    case noSpeech
    case permissionBlocked
    case audioInputUnavailable
    case providerFailed
    case insertionFailed
}
