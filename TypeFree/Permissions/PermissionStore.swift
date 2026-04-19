import Foundation

@MainActor
final class PermissionStore {
    private let microphoneClient: any MicrophonePermissionClient
    private let accessibilityClient: any AccessibilityPermissionClient

    private(set) var snapshot: PermissionSnapshot

    init(
        microphoneClient: any MicrophonePermissionClient,
        accessibilityClient: any AccessibilityPermissionClient
    ) {
        self.microphoneClient = microphoneClient
        self.accessibilityClient = accessibilityClient
        snapshot = PermissionSnapshot(
            microphone: microphoneClient.status(),
            accessibility: accessibilityClient.status()
        )
    }

    @discardableResult
    func refresh() -> PermissionSnapshot {
        let snapshot = PermissionSnapshot(
            microphone: microphoneClient.status(),
            accessibility: accessibilityClient.status()
        )
        self.snapshot = snapshot
        return snapshot
    }

    @discardableResult
    func requestMicrophonePermission() async -> PermissionSnapshot {
        let microphone = await microphoneClient.requestPermission()
        let snapshot = PermissionSnapshot(
            microphone: microphone,
            accessibility: accessibilityClient.status()
        )
        self.snapshot = snapshot
        return snapshot
    }

    @discardableResult
    func requestAccessibilityPermissionPrompt() -> PermissionSnapshot {
        _ = accessibilityClient.requestTrustPrompt()
        return refresh()
    }
}
