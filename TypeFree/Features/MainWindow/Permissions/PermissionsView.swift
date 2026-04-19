import SwiftUI

struct PermissionsView: View {
    let viewModel: PermissionsViewModel

    var body: some View {
        Form {
            Section {
                ForEach(viewModel.statusItems) { item in
                    LabeledContent {
                        HStack(spacing: 12) {
                            StatusBadge(text: item.statusText, isPositive: item.isGranted)
                            if !item.isGranted {
                                Button("Grant") {
                                    Task {
                                        await viewModel.requestPermission(for: item.kind)
                                    }
                                }
                                .controlSize(.small)
                            }
                        }
                    } label: {
                        Text(item.title)
                    }
                }
            } header: {
                Text("System Permissions")
            } footer: {
                if viewModel.readinessMessage != "" {
                    Text(viewModel.readinessMessage)
                }
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier(MainWindowAccessibilityIdentifiers.permissions)
    }
}
