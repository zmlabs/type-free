import Foundation
import Observation

struct PermissionStatusItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case microphone
        case accessibility
    }

    let kind: Kind
    let title: String
    let statusText: String
    let isGranted: Bool

    var id: Kind {
        kind
    }
}

@MainActor @Observable
final class PermissionsViewModel {
    private(set) var readinessMessage = ""
    private(set) var statusItems: [PermissionStatusItem] = []

    private let permissionStore: PermissionStore
    private let onSettingsChanged: () -> Void

    init(
        permissionStore: PermissionStore,
        onSettingsChanged: @escaping () -> Void = {}
    ) {
        self.permissionStore = permissionStore
        self.onSettingsChanged = onSettingsChanged
    }

    func refresh() {
        applyQuietly(permissionStore.refresh())
    }

    func requestPermission(for kind: PermissionStatusItem.Kind) async {
        switch kind {
        case .microphone:
            await requestMicrophonePermission()
        case .accessibility:
            promptForAccessibilityPermission()
        }
    }

    func requestMicrophonePermission() async {
        guard permissionStore.snapshot.microphone == .undetermined else {
            refresh()
            return
        }
        await apply(permissionStore.requestMicrophonePermission())
    }

    func promptForAccessibilityPermission() {
        apply(permissionStore.requestAccessibilityPermissionPrompt())
    }

    private func apply(_ snapshot: PermissionSnapshot) {
        let previous = statusItems
        applyQuietly(snapshot)
        if statusItems != previous {
            onSettingsChanged()
        }
    }

    private func applyQuietly(_ snapshot: PermissionSnapshot) {
        statusItems = Self.makeStatusItems(from: snapshot)
        updateReadiness(from: snapshot)
    }

    private func updateReadiness(from snapshot: PermissionSnapshot) {
        if snapshot.microphone == .denied {
            readinessMessage = "Re-enable Microphone in System Settings."
        } else if snapshot.microphone != .granted || snapshot.accessibility != .granted {
            readinessMessage = "Grant missing permissions below."
        } else {
            readinessMessage = ""
        }
    }

    private static func makeStatusItems(
        from snapshot: PermissionSnapshot
    ) -> [PermissionStatusItem] {
        [
            .init(
                kind: .microphone,
                title: "Microphone",
                statusText: label(for: snapshot.microphone),
                isGranted: snapshot.microphone == .granted
            ),
            .init(
                kind: .accessibility,
                title: "Accessibility",
                statusText: label(for: snapshot.accessibility),
                isGranted: snapshot.accessibility == .granted
            ),
        ]
    }

    private static func label(
        for state: PermissionAuthorizationState
    ) -> String {
        switch state {
        case .undetermined:
            "Not Set"
        case .granted:
            "Granted"
        case .denied:
            "Denied"
        }
    }
}
