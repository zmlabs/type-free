import AVFAudio
import Foundation
import Testing
@testable import TypeFree

@MainActor
struct AudioCaptureActorTests {
    @Test
    func finishTentativeCaptureReturnsPreparedCaptureAndStopsTheEngine() async throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let engine = TestAudioCaptureEngine(format: format)
        let actor = AudioCaptureActor(
            engineFactory: { engine },
            temporaryDirectoryProvider: { FileManager.default.temporaryDirectory }
        )
        let sessionID = UUID()

        try await actor.startTentativeCapture(sessionID: sessionID)
        let buffer = try makeBuffer(format: format, frameLength: 320)
        engine.emit(buffer: buffer)

        let preparedCapture = try await actor.finishTentativeCapture(sessionID: sessionID)

        #expect(preparedCapture.sampleRate == 16000)
        #expect(preparedCapture.channelCount == 1)
        #expect(preparedCapture.duration == 0.02)
        #expect(engine.removeTapCallCount == 1)
        #expect(engine.stopCallCount == 1)
        #expect(FileManager.default.fileExists(atPath: preparedCapture.fileURL.path()))

        try? FileManager.default.removeItem(at: preparedCapture.fileURL)
    }

    @Test
    func cancelTentativeCaptureStopsTheEngineAndDeletesTheTemporaryFile() async throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let engine = TestAudioCaptureEngine(format: format)
        let tempDirectory = FileManager.default.temporaryDirectory
        let actor = AudioCaptureActor(
            engineFactory: { engine },
            temporaryDirectoryProvider: { tempDirectory }
        )
        let sessionID = UUID()
        let expectedFileURL = tempDirectory
            .appendingPathComponent(sessionID.uuidString)
            .appendingPathExtension("wav")

        try await actor.startTentativeCapture(sessionID: sessionID)
        #expect(FileManager.default.fileExists(atPath: expectedFileURL.path()))

        await actor.cancelTentativeCapture(sessionID: sessionID)

        #expect(engine.removeTapCallCount == 1)
        #expect(engine.stopCallCount == 1)
        #expect(!FileManager.default.fileExists(atPath: expectedFileURL.path()))
    }

    @Test
    func startTentativeCaptureThrowsWhenInputFormatHasZeroSampleRate() async throws {
        let invalidFormat = try #require(Self.makeInvalidFormat(sampleRate: 0, channels: 2))
        let engine = TestAudioCaptureEngine(format: invalidFormat)
        let actor = AudioCaptureActor(
            engineFactory: { engine },
            temporaryDirectoryProvider: { FileManager.default.temporaryDirectory }
        )

        await #expect(throws: AudioCaptureError.audioDeviceUnavailable) {
            try await actor.startTentativeCapture(sessionID: UUID())
        }
        #expect(engine.installTapCallCount == 0)
        #expect(engine.startCallCount == 0)
    }

    @Test
    func startTentativeCaptureThrowsWhenInputFormatHasZeroChannelCount() async throws {
        let invalidFormat = try #require(Self.makeInvalidFormat(sampleRate: 44100, channels: 0))
        let engine = TestAudioCaptureEngine(format: invalidFormat)
        let actor = AudioCaptureActor(
            engineFactory: { engine },
            temporaryDirectoryProvider: { FileManager.default.temporaryDirectory }
        )

        await #expect(throws: AudioCaptureError.audioDeviceUnavailable) {
            try await actor.startTentativeCapture(sessionID: UUID())
        }
        #expect(engine.installTapCallCount == 0)
        #expect(engine.startCallCount == 0)
    }

    private static func makeInvalidFormat(sampleRate: Double, channels: UInt32) -> AVAudioFormat? {
        var description = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        return AVAudioFormat(streamDescription: &description)
    }

    @Test
    func audioTapUpdatesRelayWithNonZeroLevel() async throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let engine = TestAudioCaptureEngine(format: format)
        let relay = AudioLevelRelay()
        let actor = AudioCaptureActor(
            engineFactory: { engine },
            temporaryDirectoryProvider: { FileManager.default.temporaryDirectory },
            audioLevelRelay: relay
        )
        let sessionID = UUID()

        try await actor.startTentativeCapture(sessionID: sessionID)
        let frameLength: AVAudioFrameCount = 320
        let buffer = try makeBuffer(format: format, frameLength: frameLength)
        engine.emit(buffer: buffer)

        var expectedSum: Float = 0
        for frameIndex in 0 ..< Int(frameLength) {
            let sample = Float(frameIndex) / Float(frameLength)
            expectedSum += sample * sample
        }
        let expectedRMS = sqrt(expectedSum / Float(frameLength))
        #expect(abs(relay.currentLevel - expectedRMS) < 0.001)

        await actor.cancelTentativeCapture(sessionID: sessionID)
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

private final class TestAudioCaptureEngine: AudioEngineControlling, @unchecked Sendable {
    let inputFormat: AVAudioFormat
    private(set) var installTapCallCount = 0
    private(set) var removeTapCallCount = 0
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private var tapHandler: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?

    init(format: AVAudioFormat) {
        inputFormat = format
    }

    func installTap(
        bufferSize _: AVAudioFrameCount,
        format _: AVAudioFormat,
        handler: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void
    ) {
        installTapCallCount += 1
        tapHandler = handler
    }

    func removeTap() {
        removeTapCallCount += 1
        tapHandler = nil
    }

    func start() throws {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func emit(buffer: AVAudioPCMBuffer) {
        tapHandler?(buffer, AVAudioTime(sampleTime: 0, atRate: inputFormat.sampleRate))
    }
}
