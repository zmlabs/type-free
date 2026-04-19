import AppKit
import Foundation
import Testing
@testable import TypeFree

struct StatusMenuViewModelTests {
    @Test
    func initBuildsReadyMenuStatusWithoutWindowState() {
        let viewModel = StatusMenuViewModel(
            permissionSnapshot: PermissionSnapshot(
                microphone: .granted,
                accessibility: .granted
            ),
            hasActiveProvider: true
        )

        #expect(viewModel.statusTitle == "Ready")
        #expect(viewModel.openSettingsTitle == "Settings…")
        #expect(viewModel.quitTitle == "Quit")
    }

    @Test
    func updateMenuTitleReflectsUpdateAvailability() {
        #expect(StatusMenuViewModel.updateMenuTitle(isUpdateAvailable: false) == "Check for Updates")
        #expect(StatusMenuViewModel.updateMenuTitle(isUpdateAvailable: true) == "Update Available")
    }

    @Test
    func initBuildsBlockedStatusWhenProviderOrPermissionsAreMissing() {
        let missingProvider = StatusMenuViewModel(
            permissionSnapshot: PermissionSnapshot(
                microphone: .granted,
                accessibility: .granted
            ),
            hasActiveProvider: false
        )

        #expect(missingProvider.statusTitle == "Provider Not Configured")
    }

    @Test
    func initReportsNoAudioInputWhenProbeReportsMissingDevice() {
        let viewModel = StatusMenuViewModel(
            permissionSnapshot: PermissionSnapshot(
                microphone: .granted,
                accessibility: .granted
            ),
            hasActiveProvider: true,
            hasAudioInputDevice: false
        )

        #expect(viewModel.statusTitle == "No Audio Input")
    }

    @Test
    func initPrefersRuntimeWorkflowStateWhenDictationIsActiveOrFailed() {
        let recording = StatusMenuViewModel(
            permissionSnapshot: PermissionSnapshot(
                microphone: .granted,
                accessibility: .granted
            ),
            hasActiveProvider: true,
            workflowPhase: .recordingVisible
        )
        let failedInsertion = StatusMenuViewModel(
            permissionSnapshot: PermissionSnapshot(
                microphone: .granted,
                accessibility: .granted
            ),
            hasActiveProvider: true,
            workflowPhase: .insertionFailed
        )

        #expect(recording.statusTitle == "Recording")
        #expect(failedInsertion.statusTitle == "Insertion Failed")
    }

    @Test @MainActor
    func entryPointConfiguresAccessoryActivationPolicy() {
        let application = FakeApplication()
        let delegate = AppDelegate()

        TypeFreeEntryPoint.configure(application: application, delegate: delegate)

        #expect(application.activationPolicies == [.accessory])
        #expect(application.assignedDelegate === delegate)
    }
}

@MainActor
private final class FakeApplication: ApplicationRuntimeControlling {
    var assignedDelegate: NSApplicationDelegate?
    var activationPolicies: [NSApplication.ActivationPolicy] = []

    var delegate: NSApplicationDelegate? {
        get { assignedDelegate }
        set { assignedDelegate = newValue }
    }

    @discardableResult
    func setActivationPolicy(_ activationPolicy: NSApplication.ActivationPolicy) -> Bool {
        activationPolicies.append(activationPolicy)
        return true
    }

    func run() {}
}
