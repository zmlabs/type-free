import SwiftUI

struct HTTPProviderFormSection: View {
    @Bindable var viewModel: ProviderSettingsViewModel

    var body: some View {
        Section("Connection") {
            TextField(
                viewModel.providerKind == .qwen3ASR ? "Base URL" : "Endpoint URL",
                text: $viewModel.baseURL,
                prompt: Text(viewModel.providerKind.defaultBaseURL)
            )
            TextField(
                "Model",
                text: $viewModel.modelIdentifier,
                prompt: Text(viewModel.providerKind.defaultModelIdentifier)
            )
        }

        Section("Authentication") {
            SecureField("API Key", text: $viewModel.apiKey)
        }

        Section("Options") {
            TextField("Language Hint", text: $viewModel.languageHint, prompt: Text("en, zh, ja"))
            Picker("Timeout", selection: $viewModel.requestTimeoutSeconds) {
                ForEach([5, 10, 15, 30, 45, 60, 90, 120, 180, 300], id: \.self) { value in
                    Text("\(value) sec").tag(value)
                }
            }
        }
    }
}
