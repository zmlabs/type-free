import SwiftUI

struct OverviewView: View {
    @Bindable var viewModel: OverviewViewModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Readiness") {
                    StatusBadge(
                        text: viewModel.readiness.title,
                        isPositive: viewModel.readiness.isReady
                    )
                }
            } header: {
                Text("Status")
            } footer: {
                Text(viewModel.readiness.message)
            }

            Section("Configuration") {
                Picker(
                    "Trigger Key",
                    selection: Binding(
                        get: { viewModel.selectedHotkeyIdentifier },
                        set: { viewModel.commitHotkey($0) }
                    )
                ) {
                    ForEach(viewModel.presetHotkeys) { option in
                        Text(option.configuration.displayName)
                            .tag(option.configuration.identifier)
                    }
                    if let custom = viewModel.customHotkeyOption {
                        Divider()
                        Text(custom.configuration.displayName)
                            .tag(custom.configuration.identifier)
                    }
                }
                Picker(
                    "Provider",
                    selection: Binding(
                        get: { viewModel.activeProvider },
                        set: { viewModel.commitActiveProvider($0) }
                    )
                ) {
                    ForEach(viewModel.availableProviderKinds, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(MainWindowAccessibilityIdentifiers.overview)
    }
}
