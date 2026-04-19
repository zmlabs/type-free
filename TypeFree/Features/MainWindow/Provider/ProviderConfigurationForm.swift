import SwiftUI

struct ProviderConfigurationForm: View {
    @Bindable var viewModel: ProviderSettingsViewModel

    var body: some View {
        Section("Provider") {
            Picker(
                "Type",
                selection: Binding(
                    get: { viewModel.providerKind },
                    set: { viewModel.selectProviderKind($0) }
                )
            ) {
                ForEach(viewModel.supportedProviderKinds, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
        }

        switch viewModel.providerKind {
        case .speechAnalyzer:
            SpeechAnalyzerFormSection(assets: viewModel.speechAnalyzerAssets)
        case .openAICompatible:
            HTTPProviderFormSection(viewModel: viewModel)
        case .qwen3ASR:
            HTTPProviderFormSection(viewModel: viewModel)
            Section("Qwen Options") {
                Toggle("Enable ITN", isOn: $viewModel.enableITN)
            }
        }
    }
}
