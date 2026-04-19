import Testing
@testable import TypeFree

@MainActor
struct UpdaterCoordinatorTests {
    @Test
    func gentleReminderAvailabilityTracksCoordinatorState() {
        let coordinator = UpdaterCoordinator(startingUpdater: false)

        #expect(coordinator.supportsGentleScheduledUpdateReminders == true)
        #expect(coordinator.isUpdateAvailable == false)

        coordinator.handleScheduledUpdatePresentation(handleShowingUpdate: false, userInitiated: false)
        #expect(coordinator.isUpdateAvailable == true)

        coordinator.handleScheduledUpdatePresentation(handleShowingUpdate: true, userInitiated: false)
        #expect(coordinator.isUpdateAvailable == true)

        coordinator.handleScheduledUpdatePresentation(handleShowingUpdate: false, userInitiated: true)
        #expect(coordinator.isUpdateAvailable == true)

        coordinator.finishUpdateSession()
        #expect(coordinator.isUpdateAvailable == false)
    }
}
