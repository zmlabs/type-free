import Foundation
import Observation
import Speech
import SwiftUI

@MainActor @Observable
final class SpeechAnalyzerAssetCoordinator {
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case failed(LocalizedStringKey)
    }

    private(set) var localeIdentifiers: [String] = []
    private(set) var installedIdentifiers: Set<String> = []
    var selectedIdentifier: String?
    private(set) var isDownloading = false
    private(set) var downloadProgress: Double = 0
    private(set) var statusMessage: LocalizedStringKey = ""
    private(set) var loadingState: LoadingState = .idle

    func loadLocales() async {
        guard loadingState != .loading else { return }
        loadingState = .loading

        guard SpeechTranscriber.isAvailable else {
            localeIdentifiers = []
            loadingState = .loaded
            return
        }
        let supported = await SpeechTranscriber.supportedLocales
        let installed = await SpeechTranscriber.installedLocales
        localeIdentifiers = supported.map(\.identifier).sorted()
        installedIdentifiers = Set(installed.map(\.identifier))

        if let current = selectedIdentifier {
            let stillValid = localeIdentifiers.contains(current)
            if !stillValid {
                let matched = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)
                selectedIdentifier = matched?.identifier
            }
        } else {
            let matched = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)
            selectedIdentifier = matched?.identifier
        }

        loadingState = .loaded
    }

    func restoreLocale(from identifier: String?) {
        guard let identifier, !identifier.isEmpty else {
            selectedIdentifier = nil
            return
        }
        if localeIdentifiers.isEmpty {
            selectedIdentifier = identifier
        } else {
            let valid = localeIdentifiers.contains(identifier)
            selectedIdentifier = valid ? identifier : nil
        }
    }

    func installIfNeeded() async {
        guard let identifier = selectedIdentifier else { return }

        guard localeIdentifiers.contains(identifier) else {
            statusMessage = "Selected language is no longer available on this device."
            return
        }

        guard !installedIdentifiers.contains(identifier) else { return }

        let locale = Locale(identifier: identifier)
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            return
        }
        let transcriber = SpeechTranscriber(locale: supported, preset: .transcription)
        guard let request = try? await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
            return
        }

        isDownloading = true
        downloadProgress = 0
        statusMessage = "Downloading language model…"

        let observation = request.progress.observe(\.fractionCompleted) { progress, _ in
            Task { @MainActor in
                self.downloadProgress = progress.fractionCompleted
                self.statusMessage = "Downloading… \(Int(progress.fractionCompleted * 100))%"
            }
        }

        do {
            try await request.downloadAndInstall()
            installedIdentifiers.insert(identifier)
            statusMessage = ""
        } catch {
            statusMessage = "Model download failed. Will retry on first use."
        }

        observation.invalidate()
        isDownloading = false
        downloadProgress = 0
    }

    func displayName(for identifier: String) -> LocalizedStringKey {
        let name = Locale.current.localizedString(forIdentifier: identifier) ?? identifier
        return installedIdentifiers.contains(identifier) ? LocalizedStringKey(name) : LocalizedStringKey("\(name) ↓")
    }
}
