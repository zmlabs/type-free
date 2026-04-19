import Foundation
import Sparkle

@MainActor
final class UpdaterCoordinator {
    private final class UserDriverDelegateProxy: NSObject, SPUStandardUserDriverDelegate {
        weak var coordinator: UpdaterCoordinator?

        var supportsGentleScheduledUpdateReminders: Bool {
            coordinator?.supportsGentleScheduledUpdateReminders ?? false
        }

        func standardUserDriverWillHandleShowingUpdate(
            _ handleShowingUpdate: Bool,
            forUpdate _: SUAppcastItem,
            state: SPUUserUpdateState
        ) {
            coordinator?.handleScheduledUpdatePresentation(
                handleShowingUpdate: handleShowingUpdate,
                userInitiated: state.userInitiated
            )
        }

        func standardUserDriverWillFinishUpdateSession() {
            coordinator?.finishUpdateSession()
        }
    }

    let controller: SPUStandardUpdaterController
    var onUpdateAvailabilityChanged: ((Bool) -> Void)?
    private let userDriverDelegateProxy: UserDriverDelegateProxy
    private(set) var isUpdateAvailable = false
    let supportsGentleScheduledUpdateReminders = true

    init(startingUpdater: Bool = true) {
        userDriverDelegateProxy = UserDriverDelegateProxy()
        controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: nil,
            userDriverDelegate: userDriverDelegateProxy
        )
        userDriverDelegateProxy.coordinator = self
    }

    func handleScheduledUpdatePresentation(handleShowingUpdate: Bool, userInitiated: Bool) {
        guard !handleShowingUpdate, !userInitiated else {
            return
        }

        setUpdateAvailable(true)
    }

    func finishUpdateSession() {
        setUpdateAvailable(false)
    }

    private func setUpdateAvailable(_ isUpdateAvailable: Bool) {
        guard self.isUpdateAvailable != isUpdateAvailable else {
            return
        }

        self.isUpdateAvailable = isUpdateAvailable
        onUpdateAvailabilityChanged?(isUpdateAvailable)
    }
}
