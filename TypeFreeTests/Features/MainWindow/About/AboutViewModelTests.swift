import Foundation
import Testing
@testable import TypeFree

@MainActor
struct AboutViewModelTests {
    @Test
    func versionLabelFormatsAppInfoVersion() {
        let viewModel = makeTestAboutViewModel(version: "2.3")
        #expect(viewModel.versionLabel == "Version 2.3")
    }

    @Test
    func checkForUpdatesTriggersInjectedAction() {
        final class CallTracker: @unchecked Sendable { var count = 0 }
        let tracker = CallTracker()

        let viewModel = makeTestAboutViewModel(checkForUpdates: {
            tracker.count += 1
        })

        viewModel.checkForUpdates()
        viewModel.checkForUpdates()

        #expect(tracker.count == 2)
    }

    @Test
    func openRepositoryInvokesOpenURLWithRepositoryURL() throws {
        final class CapturedURL: @unchecked Sendable { var value: URL? }
        let captured = CapturedURL()
        let expected = try #require(URL(string: "https://github.com/zmlabs/type-free"))

        let viewModel = makeTestAboutViewModel(
            repositoryURL: expected,
            openURL: { url in
                captured.value = url
            }
        )

        viewModel.openRepository()

        #expect(captured.value == expected)
    }
}
