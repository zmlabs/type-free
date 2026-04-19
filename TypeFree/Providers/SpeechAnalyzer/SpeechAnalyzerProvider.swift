import AVFAudio
import Foundation
import Speech

struct SpeechAnalyzerProvider: TranscriptionProvider {
    let kind: ProviderKind = .speechAnalyzer

    private let configuration: ProviderConfigurationSnapshot

    init(configuration: ProviderConfigurationSnapshot) {
        self.configuration = configuration
    }

    func transcribe(capture: PreparedCapture) async throws -> TranscriptionProviderOutput {
        let transcriber = try await makeConfiguredTranscriber()
        let audioFile = try openAudioFile(at: capture.fileURL)
        let detector = SpeechDetector()
        let analyzer = SpeechAnalyzer(modules: [detector, transcriber])

        async let collectedText: String = {
            var segments: [String] = []
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                if !text.isEmpty {
                    segments.append(text)
                }
            }
            return segments.joined()
        }()

        let text: String
        do {
            if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
                try await analyzer.finalizeAndFinish(through: lastSample)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            text = try await collectedText
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch where SpeechAnalyzerNoSpeechPattern.matches(error) {
            return .noSpeech
        } catch {
            throw transportError(for: capture, underlying: error)
        }

        guard !text.isEmpty else {
            return .noSpeech
        }
        return .transcript(TranscriptionResult(text: text))
    }

    private func makeConfiguredTranscriber() async throws -> SpeechTranscriber {
        let locale = resolveLocale()
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw TranscriptionProviderError.invalidConfiguration
        }
        let transcriber = SpeechTranscriber(locale: supportedLocale, preset: .transcription)
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        } catch {
            throw TranscriptionProviderError.invalidConfiguration
        }
        return transcriber
    }

    private func openAudioFile(at url: URL) throws -> AVAudioFile {
        do {
            return try AVAudioFile(forReading: url)
        } catch {
            throw TranscriptionProviderError.invalidConfiguration
        }
    }

    private func transportError(
        for capture: PreparedCapture,
        underlying error: any Error
    ) -> TranscriptionProviderError {
        .transport(
            ProviderTransportDiagnostics(
                endpoint: capture.fileURL.absoluteString,
                hasAuthorizationHeader: false,
                requestFileName: capture.fileURL.lastPathComponent,
                requestMimeType: nil,
                statusCode: nil,
                responseSnippet: nil,
                underlyingError: String(describing: error),
                classification: .unknown
            )
        )
    }

    private func resolveLocale() -> Locale {
        if let hint = configuration.languageHint, !hint.isEmpty {
            return Locale(identifier: hint)
        }
        return Locale.current
    }
}
