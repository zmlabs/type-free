import SwiftUI

struct AboutView: View {
    @Bindable var viewModel: AboutViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                appIdentity
                actionButtons
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier(MainWindowAccessibilityIdentifiers.about)
    }

    private var appIdentity: some View {
        VStack(spacing: 16) {
            iconView
            VStack(spacing: 6) {
                Text(viewModel.appInfo.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(viewModel.versionLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var iconView: some View {
        Group {
            if let icon = viewModel.appInfo.iconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "character.textbox")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: 128, height: 128)
        .accessibilityHidden(true)
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button {
                viewModel.checkForUpdates()
            } label: {
                Text("Check for Updates")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier(MainWindowAccessibilityIdentifiers.aboutCheckForUpdates)

            Button {
                viewModel.openRepository()
            } label: {
                Text("View on GitHub")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier(MainWindowAccessibilityIdentifiers.aboutOpenRepository)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: 240)
    }
}
