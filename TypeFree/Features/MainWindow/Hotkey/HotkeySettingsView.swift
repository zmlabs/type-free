import SwiftUI

struct HotkeySettingsView: View {
    @Bindable var viewModel: HotkeySettingsViewModel

    var body: some View {
        Form {
            Section {
                Picker(
                    "Key",
                    selection: Binding(
                        get: { viewModel.selectedHotkeyIdentifier },
                        set: { viewModel.commitSelection($0) }
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

                if viewModel.isRecording {
                    HStack {
                        Text("Press any key…")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Cancel") {
                            viewModel.cancelRecording()
                        }
                        .controlSize(.small)
                    }
                } else {
                    HStack {
                        Spacer()
                        if viewModel.isCustomHotkeySelected {
                            Button("Remove", role: .destructive) {
                                viewModel.removeCustomHotkey()
                            }
                            .controlSize(.small)
                        }
                        Button(viewModel.customHotkeyOption != nil ? "Re-record…" : "Record Custom Key…") {
                            viewModel.startRecording()
                        }
                        .controlSize(.small)
                    }
                }
            } header: {
                Text("Trigger Key")
            } footer: {
                if let validationMessage = viewModel.validationMessage {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                } else {
                    Text("Choose a preset key or record any key as your trigger.")
                }
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(MainWindowAccessibilityIdentifiers.hotkey)
    }
}
