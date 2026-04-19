import AppKit
import CoreGraphics
import Testing
@testable import TypeFree

@Suite(.serialized)
@MainActor
struct HUDPanelControllerTests {
    @Test
    func presentReusesASingleWindowInstance() {
        var factoryCallCount = 0
        let (controller, window) = makeController(
            windowFactoryOverride: {
                factoryCallCount += 1
            }
        )

        let sessionID = UUID()
        controller.present(state: .recording, sessionID: sessionID, activationScreenID: "screen-a")
        controller.present(state: .transcribing, sessionID: sessionID, activationScreenID: "screen-a")

        #expect(factoryCallCount == 1)
        #expect(window.showCount == 1)
        #expect(controller.viewModel.state == .transcribing)
    }

    @Test
    func hideOrdersTheExistingWindowOut() {
        let (controller, window) = makeController()

        controller.present(state: .recording, sessionID: UUID(), activationScreenID: "screen-a")
        controller.hide()

        #expect(window.hideCount == 1)
        #expect(controller.viewModel.state == .hidden)
    }

    @Test
    func presentFailureStateKeepsTheHUDVisibleInTheSharedWindow() {
        let (controller, window) = makeController()

        controller.present(
            state: .providerFailed(.unauthorized()),
            sessionID: UUID(),
            activationScreenID: "screen-a"
        )

        #expect(window.showCount == 1)
        #expect(controller.viewModel.isVisible)
        #expect(controller.viewModel.state == .providerFailed(.unauthorized()))
    }

    @Test
    func hideThenPresentForANewSessionStillReusesTheSingletonHUDWindow() {
        var factoryCallCount = 0
        let (controller, window) = makeController(
            windowFactoryOverride: {
                factoryCallCount += 1
            }
        )

        controller.present(state: .recording, sessionID: UUID(), activationScreenID: "screen-a")
        controller.hide()
        controller.present(state: .transcribing, sessionID: UUID(), activationScreenID: "screen-a")

        #expect(factoryCallCount == 1)
        #expect(window.showCount == 2)
        #expect(window.hideCount == 1)
        #expect(controller.viewModel.state == .transcribing)
    }

    @Test
    func presentRecordingStartsDisplayLinkAndStopOnHide() {
        let displayLink = FakeDisplayLink()
        let relay = AudioLevelRelay()
        relay.update(0.5)
        let (controller, _) = makeController(
            audioLevelRelay: relay,
            displayLinkFactory: { target, selector in
                let weakTarget = target as AnyObject
                displayLink.callback = { [weak weakTarget] in
                    _ = weakTarget?.perform(selector)
                }
                return displayLink
            }
        )

        controller.present(state: .recording, sessionID: UUID(), activationScreenID: "screen-a")
        #expect(displayLink.isAdded)

        displayLink.fire()
        #expect(controller.viewModel.audioLevel > 0)

        controller.hide()
        #expect(displayLink.isInvalidated)
        #expect(relay.currentLevel == 0)
    }

    @Test
    func presentNonRecordingStateDoesNotStartDisplayLink() {
        let displayLink = FakeDisplayLink()
        let (controller, _) = makeController(
            displayLinkFactory: { _, _ in displayLink }
        )

        controller.present(state: .transcribing, sessionID: UUID(), activationScreenID: "screen-a")
        #expect(!displayLink.isAdded)
    }

    @Test
    func transitionFromRecordingToTranscribingStopsDisplayLink() {
        let displayLink = FakeDisplayLink()
        let relay = AudioLevelRelay()
        let (controller, _) = makeController(
            audioLevelRelay: relay,
            displayLinkFactory: { target, selector in
                let weakTarget = target as AnyObject
                displayLink.callback = { [weak weakTarget] in
                    _ = weakTarget?.perform(selector)
                }
                return displayLink
            }
        )
        let sessionID = UUID()

        controller.present(state: .recording, sessionID: sessionID, activationScreenID: "screen-a")
        #expect(displayLink.isAdded)

        controller.present(state: .transcribing, sessionID: sessionID, activationScreenID: "screen-a")
        #expect(displayLink.isInvalidated)
    }
}

@MainActor
private func makeController(
    viewModel: HUDViewModel = HUDViewModel(),
    audioLevelRelay: AudioLevelRelay = AudioLevelRelay(),
    displayLinkFactory: (@MainActor (Any, Selector) -> any DisplayLinkProviding)? = nil,
    windowFactoryOverride: (() -> Void)? = nil
) -> (controller: HUDPanelController, window: FakeHUDWindow) {
    let window = FakeHUDWindow()
    let controller = HUDPanelController(
        viewModel: viewModel,
        positioner: HUDPositioner(panelSize: CGSize(width: 300, height: 44), bottomMargin: 24),
        windowFactory: {
            windowFactoryOverride?()
            return window
        },
        screenProvider: {
            [HUDScreenDescriptor(
                identifier: "screen-a",
                visibleFrame: CGRect(x: 0, y: 0, width: 800, height: 600)
            )]
        },
        pointerLocationProvider: { CGPoint(x: 100, y: 100) },
        audioLevelRelay: audioLevelRelay,
        displayLinkFactory: displayLinkFactory ?? { _, _ in FakeDisplayLink() }
    )
    return (controller, window)
}

@MainActor
private final class FakeHUDWindow: HUDWindowing {
    var contentViewController: NSViewController?
    var frame = CGRect.zero
    var showCount = 0
    var hideCount = 0

    func setFrame(_ frame: CGRect, display _: Bool) {
        self.frame = frame
    }

    func showWithAnimation() {
        showCount += 1
    }

    func hideWithAnimation() {
        hideCount += 1
    }
}

@MainActor
private final class FakeDisplayLink: DisplayLinkProviding {
    private(set) var isAdded = false
    private(set) var isInvalidated = false
    var callback: (() -> Void)?

    func add(to _: RunLoop, forMode _: RunLoop.Mode) {
        isAdded = true
    }

    func invalidate() {
        isInvalidated = true
        isAdded = false
    }

    func fire() {
        callback?()
    }
}
