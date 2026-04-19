import AVFAudio
import Foundation
import Testing
@testable import TypeFree

struct AudioFileWriterTests {
    @Test
    func writePersistsSequentialPCMFrames() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        var writer: AudioFileWriter? = try AudioFileWriter(fileURL: fileURL, processingFormat: format)
        let firstBuffer = try makeBuffer(format: format, frameLength: 160)
        let secondBuffer = try makeBuffer(format: format, frameLength: 80)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        try writer?.write(firstBuffer)
        try writer?.write(secondBuffer)

        #expect(writer?.recordedFrameCount == 240)
        writer = nil

        let storedFile = try AVAudioFile(forReading: fileURL)

        #expect(storedFile.length == 240)
        #expect(storedFile.processingFormat.sampleRate == 16000)
        #expect(storedFile.processingFormat.channelCount == 1)
    }

    @Test
    func writeRejectsMismatchedBufferFormat() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        let writerFormat = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let mismatchedFormat = try #require(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
        let writer = try AudioFileWriter(fileURL: fileURL, processingFormat: writerFormat)
        let mismatchedBuffer = try makeBuffer(format: mismatchedFormat, frameLength: 160)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        #expect(throws: AudioCaptureError.bufferFormatMismatch) {
            try writer.write(mismatchedBuffer)
        }
    }

    @Test
    func recordUpdatesRelayWithExpectedRMS() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let relay = AudioLevelRelay()
        let writer = try AudioFileWriter(fileURL: fileURL, processingFormat: format, audioLevelRelay: relay)
        let frameLength: AVAudioFrameCount = 160
        let buffer = try makeBuffer(format: format, frameLength: frameLength)

        defer { try? FileManager.default.removeItem(at: fileURL) }

        writer.record(buffer)

        let expectedRMS: Float = {
            let count = Float(frameLength)
            var sum: Float = 0
            for idx in 0 ..< Int(frameLength) {
                let sample = Float(idx) / count
                sum += sample * sample
            }
            return sqrt(sum / count)
        }()
        #expect(abs(relay.currentLevel - expectedRMS) < 0.001)
    }

    @Test
    func recordUpdatesRelayEvenAfterWriteError() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        let writerFormat = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let mismatchedFormat = try #require(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
        let relay = AudioLevelRelay()
        let writer = try AudioFileWriter(fileURL: fileURL, processingFormat: writerFormat, audioLevelRelay: relay)
        let badBuffer = try makeBuffer(format: mismatchedFormat, frameLength: 160)
        let goodBuffer = try makeBuffer(format: writerFormat, frameLength: 160)

        defer { try? FileManager.default.removeItem(at: fileURL) }

        writer.record(badBuffer)
        #expect(writer.recordedError == .bufferFormatMismatch)
        #expect(relay.currentLevel > 0)

        relay.reset()
        writer.record(goodBuffer)

        let expectedRMS: Float = {
            let frameLength: AVAudioFrameCount = 160
            let count = Float(frameLength)
            var sum: Float = 0
            for idx in 0 ..< Int(frameLength) {
                let sample = Float(idx) / count
                sum += sample * sample
            }
            return sqrt(sum / count)
        }()
        #expect(abs(relay.currentLevel - expectedRMS) < 0.001)
    }

    private func makeBuffer(
        format: AVAudioFormat,
        frameLength: AVAudioFrameCount
    ) throws -> AVAudioPCMBuffer {
        let buffer = try #require(
            AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frameLength
            )
        )
        buffer.frameLength = frameLength

        if let floatChannelData = buffer.floatChannelData {
            for frameIndex in 0 ..< Int(frameLength) {
                floatChannelData[0][frameIndex] = Float(frameIndex) / Float(frameLength)
            }
        }

        return buffer
    }
}
