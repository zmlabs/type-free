import SwiftUI

struct SpeechAnalyzerFormSection: View {
    @Bindable var assets: SpeechAnalyzerAssetCoordinator

    var body: some View {
        Section("Language") {
            switch assets.loadingState {
            case .idle, .loading:
                ProgressView()
                    .task { await assets.loadLocales() }
            case .loaded where assets.localeIdentifiers.isEmpty:
                Text("No speech recognition languages available on this device")
                    .foregroundStyle(.secondary)
            case .loaded:
                Picker("Language", selection: $assets.selectedIdentifier) {
                    Text("System Default").tag(nil as String?)
                    ForEach(assets.localeIdentifiers, id: \.self) { identifier in
                        Text(assets.displayName(for: identifier)).tag(identifier as String?)
                    }
                }
            case let .failed(message):
                Text(message)
                    .foregroundStyle(.red)
            }
            if assets.isDownloading {
                ProgressView(value: assets.downloadProgress) {
                    Text(assets.statusMessage)
                        .font(.caption)
                }
            }
        }
    }
}
