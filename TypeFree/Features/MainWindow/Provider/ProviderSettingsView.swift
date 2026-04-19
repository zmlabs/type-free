import SwiftUI

struct ProviderSettingsView: View {
    @Bindable var viewModel: ProviderSettingsViewModel

    var body: some View {
        Form {
            ProviderConfigurationForm(viewModel: viewModel)

            Section {
                HStack {
                    if !viewModel.saveMessage.isEmpty {
                        Text(viewModel.saveMessage)
                            .font(.callout)
                            .foregroundStyle(
                                viewModel.saveMessageLevel == .error ? .red : .secondary
                            )
                    }
                    Spacer()
                    Button("Save") {
                        Task { try? await viewModel.save() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(MainWindowAccessibilityIdentifiers.provider)
    }
}
