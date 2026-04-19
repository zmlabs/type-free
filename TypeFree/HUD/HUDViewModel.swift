import Foundation
import Observation

@MainActor
@Observable
final class HUDViewModel {
    private(set) var state: HUDState = .hidden
    private(set) var audioLevel: Float = 0
    private(set) var barLevels: [Float] = Array(repeating: 0, count: weights.count)

    private static let weights: [Float] = [0.10, 0.25, 0.55, 0.85, 1.00, 0.80, 0.50, 0.20, 0.08]
    private static let smoothing: Float = 0.3

    var isVisible: Bool {
        state != .hidden
    }

    var message: String {
        messageText(for: state)
    }

    func render(state: HUDState) {
        self.state = state
    }

    func hide() {
        state = .hidden
        audioLevel = 0
        barLevels = Array(repeating: 0, count: Self.weights.count)
    }

    func updateAudioLevel(_ rawLevel: Float) {
        let normalized = Self.scaledPower(rawLevel)
        audioLevel += (normalized - audioLevel) * Self.smoothing
        for index in 0 ..< Self.weights.count {
            barLevels[index] = audioLevel * Self.weights[index]
        }
    }

    func resetAudioLevel() {
        audioLevel = 0
        barLevels = Array(repeating: 0, count: Self.weights.count)
    }

    private static func scaledPower(_ rms: Float) -> Float {
        guard rms > 0, rms.isFinite else { return 0 }
        let decibels = 20 * log10(rms)
        guard decibels.isFinite else { return 0 }
        let floor: Float = -50
        let ceiling: Float = -15
        return max(0, min(1, (decibels - floor) / (ceiling - floor)))
    }

    private func messageText(for state: HUDState) -> String {
        switch state {
        case .hidden, .tentativeCapture, .recording:
            ""
        case .transcribing:
            "Transcribing..."
        case .canceled:
            "Canceled"
        case .noSpeech:
            "No speech heard"
        case .permissionBlocked:
            "Permission needed"
        case let .providerFailed(failure):
            providerMessage(for: failure)
        case let .insertionFailed(category):
            insertionMessage(for: category)
        }
    }

    private func providerMessage(for failure: ProviderFailure) -> String {
        if let detail = failure.detail {
            return detail
        }
        return switch failure.category {
        case .configuration: "Setup incomplete"
        case .unauthorized: "Invalid API key"
        case .timeout: "Timed out"
        case .unavailable: "Service unreachable"
        case .invalidResponse: "Unexpected response"
        }
    }

    private func insertionMessage(for category: InsertionFailureCategory) -> String {
        switch category {
        case .targetUnavailable: "No text field found"
        case .targetNotEditable: "Field not editable"
        case .writeFailed: "Input rejected"
        }
    }
}
