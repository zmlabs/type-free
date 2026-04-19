import Foundation

struct AudioCaptureSession: Equatable {
    let id: UUID
    let fileURL: URL
    let activationScreenID: String
    let sampleRate: Double
    let channelCount: Int
    let startedAt: Date

    nonisolated func duration(for recordedFrameCount: Int64) -> TimeInterval {
        guard sampleRate > 0 else {
            return 0
        }

        return Double(recordedFrameCount) / sampleRate
    }
}
