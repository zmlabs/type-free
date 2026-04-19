import AVFAudio
import Foundation
import Synchronization

nonisolated final class AudioFileWriter: Sendable {
    let fileURL: URL
    let processingFormat: AVAudioFormat

    private let audioFile: AVAudioFile
    private let audioLevelRelay: AudioLevelRelay?
    private let state = Mutex(State())

    private struct State: ~Copyable {
        var recordedFrameCount: Int64 = 0
        var recordedError: AudioCaptureError?
    }

    var recordedFrameCount: Int64 {
        state.withLock { $0.recordedFrameCount }
    }

    var recordedError: AudioCaptureError? {
        state.withLock { $0.recordedError }
    }

    init(fileURL: URL, processingFormat: AVAudioFormat, audioLevelRelay: AudioLevelRelay? = nil) throws {
        self.fileURL = fileURL
        self.processingFormat = processingFormat
        self.audioLevelRelay = audioLevelRelay

        audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: processingFormat.settings,
            commonFormat: processingFormat.commonFormat,
            interleaved: processingFormat.isInterleaved
        )
    }

    func write(_ buffer: AVAudioPCMBuffer) throws {
        guard formatMatches(buffer.format, processingFormat) else {
            throw AudioCaptureError.bufferFormatMismatch
        }

        do {
            try audioFile.write(from: buffer)
            state.withLock { $0.recordedFrameCount += Int64(buffer.frameLength) }
        } catch {
            throw AudioCaptureError.writeFailed
        }
    }

    func record(_ buffer: AVAudioPCMBuffer) {
        if let audioLevelRelay {
            let rms = computeRMS(from: buffer)
            audioLevelRelay.update(rms)
        }

        let hasError = state.withLock { $0.recordedError != nil }
        guard !hasError else { return }

        do {
            try write(buffer)
        } catch let error as AudioCaptureError {
            state.withLock { $0.recordedError = error }
        } catch {
            state.withLock { $0.recordedError = .writeFailed }
        }
    }

    private func computeRMS(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        var sum: Float = 0
        let samples = channelData[0]
        for frameIndex in 0 ..< frameLength {
            let sample = samples[frameIndex]
            sum += sample * sample
        }
        return sqrt(sum / Float(frameLength))
    }

    private func formatMatches(
        _ lhs: AVAudioFormat,
        _ rhs: AVAudioFormat
    ) -> Bool {
        lhs.sampleRate == rhs.sampleRate &&
            lhs.channelCount == rhs.channelCount &&
            lhs.commonFormat == rhs.commonFormat &&
            lhs.isInterleaved == rhs.isInterleaved
    }
}
