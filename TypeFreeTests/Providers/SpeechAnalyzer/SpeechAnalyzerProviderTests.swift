import AVFAudio
import Foundation
import Testing
@testable import TypeFree

@MainActor
struct SpeechAnalyzerProviderTests {
    @Test
    func factoryCreatesSpeechAnalyzerProviderWithoutCredential() async throws {
        let vault = InertSecretVault()
        let factory = ProviderFactory(secretVault: vault)
        let snapshot = ProviderConfigurationSnapshot(
            kind: .speechAnalyzer,
            modelIdentifier: "",
            languageHint: nil,
            requestTimeoutSeconds: 60
        )

        let provider = try await factory.makeProvider(for: snapshot)

        #expect(provider.kind == .speechAnalyzer)
        #expect(await vault.readCount() == 0)
    }

    @Test
    func transcribeSilentAudioReturnsNoSpeech() async throws {
        let provider = SpeechAnalyzerProvider(
            configuration: ProviderConfigurationSnapshot(
                kind: .speechAnalyzer,
                modelIdentifier: "",
                languageHint: nil,
                requestTimeoutSeconds: 60
            )
        )

        let fileURL = try makeSilentWAV(durationSeconds: 0.5)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let capture = PreparedCapture(
            fileURL: fileURL,
            duration: 0.5,
            sampleRate: 16000,
            channelCount: 1,
            activationScreenID: "test"
        )

        let output = try await provider.transcribe(capture: capture)

        #expect(output == .noSpeech)
    }
}

private func makeSilentWAV(durationSeconds: Double) throws -> URL {
    let sampleRate: Double = 16000
    let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
    let format = try #require(
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
    )
    let buffer = try #require(
        AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
    )
    buffer.frameLength = frameCount

    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("wav")
    let file = try AVAudioFile(
        forWriting: fileURL,
        settings: format.settings,
        commonFormat: format.commonFormat,
        interleaved: format.isInterleaved
    )
    try file.write(from: buffer)
    return fileURL
}

private actor InertSecretVault: ProviderSecretVaulting {
    private var reads = 0

    func readSecret(reference _: String) throws -> String? {
        reads += 1
        return nil
    }

    func writeSecret(_: String, reference _: String) throws {}
    func deleteSecret(reference _: String) throws {}

    func readCount() -> Int {
        reads
    }
}
