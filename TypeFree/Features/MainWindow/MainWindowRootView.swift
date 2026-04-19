import AppKit
import SwiftUI

struct MainWindowRootView: View {
    @Bindable var viewModel: MainWindowRootViewModel

    var body: some View {
        NavigationSplitView {
            MainWindowSidebarView(
                selection: Binding(
                    get: { viewModel.selectedSection },
                    set: { viewModel.select($0 ?? .overview) }
                ),
                sections: viewModel.sections
            )
            .background(SidebarCollapseGuard())
        } detail: {
            detailView
        }
        .toolbar(removing: .sidebarToggle)
        .accessibilityIdentifier(MainWindowAccessibilityIdentifiers.rootSplitView)
    }

    private var detailView: some View {
        Group {
            switch viewModel.selectedSection {
            case .overview:
                OverviewView(viewModel: viewModel.overviewViewModel)
            case .hotkey:
                HotkeySettingsView(viewModel: viewModel.hotkeySettingsViewModel)
            case .provider:
                ProviderSettingsView(viewModel: viewModel.providerSettingsViewModel)
            case .permissions:
                PermissionsView(viewModel: viewModel.permissionsViewModel)
            }
        }
        .navigationTitle(viewModel.navigationTitle)
    }
}

private struct SidebarCollapseGuard: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        CollapseGuardView()
    }

    func updateNSView(_: NSView, context _: Context) {}

    private class CollapseGuardView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            Task { @MainActor in
                await Task.yield()
                self.disableSidebarCollapse()
            }
        }

        private func disableSidebarCollapse() {
            var current: NSView? = superview
            while let view = current {
                if let splitView = view as? NSSplitView, let controller = splitView.delegate as? NSSplitViewController {
                    let sidebarItem = controller.splitViewItems.first
                    sidebarItem?.canCollapse = false
                    sidebarItem?.canCollapseFromWindowResize = false
                    return
                }
                current = view.superview
            }
        }
    }
}
