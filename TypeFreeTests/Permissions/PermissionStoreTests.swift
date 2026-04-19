import Testing
@testable import TypeFree

struct PermissionStoreTests {
    @Test @MainActor
    func refreshBuildsReadySnapshotWhenRequirementsAreSatisfied() {
        let micClient = SpyMicrophonePermissionClient(currentStatus: .undetermined)
        let accClient = SpyAccessibilityPermissionClient(currentStatus: .undetermined)
        let store = PermissionStore(
            microphoneClient: micClient,
            accessibilityClient: accClient
        )

        #expect(!store.snapshot.isReadyForDictation)

        micClient.currentStatus = .granted
        accClient.currentStatus = .granted
        let snapshot = store.refresh()

        #expect(snapshot.microphone == .granted)
        #expect(snapshot.accessibility == .granted)
        #expect(snapshot.isReadyForDictation)
        #expect(store.snapshot.microphone == .granted)
        #expect(store.snapshot.accessibility == .granted)
        #expect(store.snapshot.isReadyForDictation)
    }

    @Test @MainActor
    func refreshMarksReadinessBlockedWhenAccessibilityDenied() {
        let micClient = SpyMicrophonePermissionClient(currentStatus: .granted)
        let accClient = SpyAccessibilityPermissionClient(currentStatus: .granted)
        let store = PermissionStore(
            microphoneClient: micClient,
            accessibilityClient: accClient
        )

        #expect(store.snapshot.isReadyForDictation)

        accClient.currentStatus = .denied
        let snapshot = store.refresh()

        #expect(snapshot.accessibility == .denied)
        #expect(!snapshot.isReadyForDictation)
        #expect(store.snapshot.accessibility == .denied)
        #expect(!store.snapshot.isReadyForDictation)
    }

    @Test @MainActor
    func requestMicrophonePermissionRefreshesSnapshot() async {
        let micClient = SpyMicrophonePermissionClient(
            currentStatus: .undetermined,
            requestedStatus: .granted
        )
        let store = PermissionStore(
            microphoneClient: micClient,
            accessibilityClient: SpyAccessibilityPermissionClient(currentStatus: .granted)
        )

        _ = store.refresh()
        let snapshot = await store.requestMicrophonePermission()

        #expect(snapshot.microphone == .granted)
        #expect(store.snapshot.microphone == .granted)
    }
}

private final class SpyMicrophonePermissionClient: MicrophonePermissionClient, @unchecked Sendable {
    var currentStatus: PermissionAuthorizationState
    var requestedStatus: PermissionAuthorizationState?

    init(currentStatus: PermissionAuthorizationState, requestedStatus: PermissionAuthorizationState? = nil) {
        self.currentStatus = currentStatus
        self.requestedStatus = requestedStatus
    }

    func status() -> PermissionAuthorizationState {
        currentStatus
    }

    func requestPermission() async -> PermissionAuthorizationState {
        requestedStatus ?? currentStatus
    }
}

private final class SpyAccessibilityPermissionClient: AccessibilityPermissionClient, @unchecked Sendable {
    var currentStatus: PermissionAuthorizationState

    init(currentStatus: PermissionAuthorizationState) {
        self.currentStatus = currentStatus
    }

    func status() -> PermissionAuthorizationState {
        currentStatus
    }

    func requestTrustPrompt() -> PermissionAuthorizationState {
        currentStatus
    }
}
