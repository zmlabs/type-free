import AVFAudio
import Foundation

protocol AudioCapturing: Sendable {
    func startTentativeCapture(sessionID: UUID, activationScreenID: String) async throws
    func finishTentativeCapture(sessionID: UUID) async throws -> PreparedCapture
    func cancelTentativeCapture(sessionID: UUID) async
}

protocol AudioEngineControlling: AnyObject {
    nonisolated var inputFormat: AVAudioFormat { get }

    nonisolated func installTap(
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat,
        handler: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void
    )

    nonisolated func removeTap()
    nonisolated func start() throws
    nonisolated func stop()
}

actor AudioCaptureActor: AudioCapturing {
    private let engineFactory: @Sendable () -> any AudioEngineControlling
    private let temporaryDirectoryProvider: @Sendable () -> URL
    private let fileWriterFactory: @Sendable (URL, AVAudioFormat, AudioLevelRelay?) throws -> AudioFileWriter
    private let audioLevelRelay: AudioLevelRelay?
    private let bufferSize: AVAudioFrameCount

    private var activeSessionValue: AudioCaptureSession?
    private var engine: (any AudioEngineControlling)?
    private var fileWriter: AudioFileWriter?

    init(
        engineFactory: @escaping @Sendable () -> any AudioEngineControlling = { SystemAudioEngineController() },
        temporaryDirectoryProvider: @escaping @Sendable () -> URL = { FileManager.default.temporaryDirectory },
        fileWriterFactory: @escaping @Sendable (URL, AVAudioFormat, AudioLevelRelay?) throws -> AudioFileWriter = {
            try AudioFileWriter(fileURL: $0, processingFormat: $1, audioLevelRelay: $2)
        },
        audioLevelRelay: AudioLevelRelay? = nil,
        bufferSize: AVAudioFrameCount = 1024
    ) {
        self.engineFactory = engineFactory
        self.temporaryDirectoryProvider = temporaryDirectoryProvider
        self.fileWriterFactory = fileWriterFactory
        self.audioLevelRelay = audioLevelRelay
        self.bufferSize = bufferSize
    }

    func startTentativeCapture(
        sessionID: UUID,
        activationScreenID: String = ""
    ) async throws {
        guard activeSessionValue == nil else {
            throw AudioCaptureError.captureAlreadyRunning
        }

        let audioEngine = engineFactory()
        let format = audioEngine.inputFormat

        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioCaptureError.audioDeviceUnavailable
        }

        let fileURL = makeCaptureFileURL(sessionID: sessionID)
        let writer: AudioFileWriter

        do {
            writer = try fileWriterFactory(fileURL, format, audioLevelRelay)
        } catch {
            throw AudioCaptureError.writerInitializationFailed
        }

        audioEngine.installTap(
            bufferSize: bufferSize,
            format: format
        ) { [writer] buffer, _ in
            writer.record(buffer)
        }

        do {
            try audioEngine.start()
        } catch {
            audioEngine.removeTap()
            try? FileManager.default.removeItem(at: fileURL)
            throw AudioCaptureError.engineStartFailed
        }

        engine = audioEngine
        fileWriter = writer
        activeSessionValue = AudioCaptureSession(
            id: sessionID,
            fileURL: fileURL,
            activationScreenID: activationScreenID,
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount),
            startedAt: .now
        )
    }

    func finishTentativeCapture(sessionID: UUID) async throws -> PreparedCapture {
        let session = try requireActiveSession(sessionID: sessionID)

        stopCapture()

        guard let writer = fileWriter else {
            teardown()
            throw AudioCaptureError.missingActiveSession
        }

        if let error = writer.recordedError {
            try? FileManager.default.removeItem(at: session.fileURL)
            teardown()
            throw error
        }

        let capture = PreparedCapture(
            fileURL: session.fileURL,
            duration: session.duration(for: writer.recordedFrameCount),
            sampleRate: session.sampleRate,
            channelCount: session.channelCount,
            activationScreenID: session.activationScreenID
        )

        teardown()
        return capture
    }

    func cancelTentativeCapture(sessionID: UUID) async {
        guard let session = activeSessionValue, session.id == sessionID else {
            return
        }

        stopCapture()
        teardown()
        try? FileManager.default.removeItem(at: session.fileURL)
    }

    private func makeCaptureFileURL(sessionID: UUID) -> URL {
        temporaryDirectoryProvider()
            .appendingPathComponent(sessionID.uuidString)
            .appendingPathExtension("wav")
    }

    private func requireActiveSession(sessionID: UUID) throws -> AudioCaptureSession {
        guard let session = activeSessionValue else {
            throw AudioCaptureError.missingActiveSession
        }

        guard session.id == sessionID else {
            throw AudioCaptureError.staleSession
        }

        return session
    }

    private func stopCapture() {
        engine?.removeTap()
        engine?.stop()
    }

    private func teardown() {
        engine = nil
        fileWriter = nil
        activeSessionValue = nil
    }
}

nonisolated final class SystemAudioEngineController: AudioEngineControlling {
    private let engine: AVAudioEngine

    init(engine: AVAudioEngine = AVAudioEngine()) {
        self.engine = engine
    }

    var inputFormat: AVAudioFormat {
        engine.inputNode.outputFormat(forBus: 0)
    }

    func installTap(
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat,
        handler: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void
    ) {
        engine.inputNode.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: format,
            block: handler
        )
    }

    func removeTap() {
        engine.inputNode.removeTap(onBus: 0)
    }

    func start() throws {
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.stop()
    }
}
