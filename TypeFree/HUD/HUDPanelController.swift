import AppKit
import QuartzCore
import SwiftUI

@MainActor
protocol HUDPresenting: AnyObject, Sendable {
    func activationScreenID() -> String
    func present(state: HUDState, sessionID: UUID, activationScreenID: String)
    func hide()
}

@MainActor
protocol DisplayLinkProviding: AnyObject {
    func add(to runLoop: RunLoop, forMode mode: RunLoop.Mode)
    func invalidate()
}

extension CADisplayLink: DisplayLinkProviding {}

@MainActor
final class HUDPanelController: NSObject, HUDPresenting {
    typealias WindowFactory = @MainActor () -> any HUDWindowing
    typealias ScreenProvider = @MainActor () -> [HUDScreenDescriptor]
    typealias PointerLocationProvider = @MainActor () -> CGPoint
    typealias DisplayLinkFactory = @MainActor (Any, Selector) -> any DisplayLinkProviding

    let viewModel: HUDViewModel

    private let positioner: HUDPositioner
    private let windowFactory: WindowFactory
    private let screenProvider: ScreenProvider
    private let pointerLocationProvider: PointerLocationProvider
    private let audioLevelRelay: AudioLevelRelay
    private let displayLinkFactory: DisplayLinkFactory

    private var activeSessionID: UUID?
    private var activeScreenID: String?
    private var window: (any HUDWindowing)?
    private var displayLink: (any DisplayLinkProviding)?

    init(
        viewModel: HUDViewModel = HUDViewModel(),
        positioner: HUDPositioner = HUDPositioner(
            panelSize: CGSize(width: 300, height: 80),
            bottomMargin: 24
        ),
        windowFactory: @escaping WindowFactory = {
            HUDWindow()
        },
        screenProvider: @escaping ScreenProvider = {
            NSScreen.screens.map(HUDScreenDescriptor.init)
        },
        pointerLocationProvider: @escaping PointerLocationProvider = {
            NSEvent.mouseLocation
        },
        audioLevelRelay: AudioLevelRelay = AudioLevelRelay(),
        displayLinkFactory: @escaping DisplayLinkFactory = { target, selector in
            let screen = NSScreen.main ?? NSScreen.screens[0]
            let link = screen.displayLink(target: target, selector: selector)
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
            return link
        }
    ) {
        self.viewModel = viewModel
        self.positioner = positioner
        self.windowFactory = windowFactory
        self.screenProvider = screenProvider
        self.pointerLocationProvider = pointerLocationProvider
        self.audioLevelRelay = audioLevelRelay
        self.displayLinkFactory = displayLinkFactory
        super.init()
    }

    func activationScreenID() -> String {
        let pointerLocation = pointerLocationProvider()
        let nsScreens = NSScreen.screens

        let matchedScreen = nsScreens.first(where: { $0.frame.contains(pointerLocation) })
            ?? nsScreens.first

        guard let matchedScreen else {
            return "screen-unknown"
        }

        return HUDScreenDescriptor(screen: matchedScreen).identifier
    }

    func present(state: HUDState, sessionID: UUID, activationScreenID: String) {
        let resolvedScreenID = resolvedScreenID(
            sessionID: sessionID,
            activationScreenID: activationScreenID
        )
        let screens = screenProvider()
        let pointerLocation = pointerLocationProvider()

        guard let placement = positioner.placement(
            screens: screens,
            pointerLocation: pointerLocation,
            sessionScreenID: resolvedScreenID
        ) else {
            return
        }

        let window = makeWindowIfNeeded()
        viewModel.render(state: state)

        if state == .recording || state == .tentativeCapture {
            startDisplayLinkIfNeeded()
        } else {
            stopDisplayLink()
        }

        let isFirstPresentation = activeSessionID == nil
        window.setFrame(placement.frame, display: true)
        if isFirstPresentation {
            window.showWithAnimation()
        }

        activeSessionID = sessionID
        activeScreenID = placement.screenID
    }

    func hide() {
        stopDisplayLink()
        viewModel.hide()
        window?.hideWithAnimation()
        activeSessionID = nil
        activeScreenID = nil
    }

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let link = displayLinkFactory(self, #selector(displayLinkTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        audioLevelRelay.reset()
        viewModel.resetAudioLevel()
    }

    @objc private func displayLinkTick() {
        viewModel.updateAudioLevel(audioLevelRelay.currentLevel)
    }

    private func resolvedScreenID(sessionID: UUID, activationScreenID: String) -> String {
        if activeSessionID == sessionID, let activeScreenID {
            return activeScreenID
        }

        return activationScreenID
    }

    private func makeWindowIfNeeded() -> any HUDWindowing {
        if let window {
            return window
        }

        let window = windowFactory()
        let hostingController = NSHostingController(
            rootView: HUDRootView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        hostingController.sizingOptions = []
        window.contentViewController = hostingController
        self.window = window
        return window
    }
}

private extension HUDScreenDescriptor {
    init(screen: NSScreen) {
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        let screenNumber = screen.deviceDescription[screenNumberKey] as? NSNumber

        let frame = screen.frame
        let fallbackID = "screen-\(Int(frame.minX))-\(Int(frame.minY))-\(Int(frame.width))-\(Int(frame.height))"
        identifier = screenNumber?.stringValue ?? fallbackID
        visibleFrame = screen.visibleFrame
    }
}
