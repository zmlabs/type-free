import SwiftUI
import Testing
@testable import TypeFree

struct PermissionsViewModelTests {
    @Test @MainActor
    func refreshShowsGrantedBadgeForSatisfiedPermissions() {
        let viewModel = PermissionsViewModel(
            permissionStore: makePermissionStore(
                microphone: .granted,
                accessibility: .granted
            )
        )

        viewModel.refresh()

        #expect(viewModel.readinessMessage == "")
        #expect(viewModel.statusItems.count == 2)
        let allGranted = viewModel.statusItems.allSatisfy(\.isGranted)
        #expect(allGranted)
    }

    @Test @MainActor
    func refreshShowsActionableRowWhenMicrophoneDenied() {
        let viewModel = PermissionsViewModel(
            permissionStore: makePermissionStore(
                microphone: .denied
            )
        )

        viewModel.refresh()

        #expect(viewModel.readinessMessage == "Re-enable Microphone in System Settings.")
        let mic = viewModel.statusItems.first { $0.kind == .microphone }
        #expect(mic?.isGranted == false)
        #expect(mic?.statusText == "Denied")
    }

    @Test @MainActor
    func refreshMarksSetupIncompleteWhenAccessibilityDenied() {
        let viewModel = PermissionsViewModel(
            permissionStore: makePermissionStore(accessibility: .denied)
        )

        viewModel.refresh()

        #expect(viewModel.readinessMessage == "Grant missing permissions below.")
        #expect(viewModel.statusItems.contains {
            $0.kind == .accessibility && !$0.isGranted
        })
    }
}
