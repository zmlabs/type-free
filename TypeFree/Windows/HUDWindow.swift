import AppKit

@MainActor
protocol HUDWindowing: AnyObject {
    var contentViewController: NSViewController? { get set }

    func setFrame(_ frame: CGRect, display: Bool)
    func showWithAnimation()
    func hideWithAnimation()
}

@MainActor
final class HUDWindow: NSPanel, HUDWindowing {
    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 300, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        animationBehavior = .utilityWindow
        backgroundColor = .clear
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        hasShadow = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        isFloatingPanel = true
        isMovableByWindowBackground = false
        isOpaque = false
        level = .statusBar
        titleVisibility = .hidden
    }

    // swiftlint:disable identifier_name
    @objc(_hasActiveAppearance) dynamic func _hasActiveAppearance() -> Bool {
        true
    }

    @objc(_hasActiveAppearanceIgnoringKeyFocus) dynamic func _hasActiveAppearanceIgnoringKeyFocus() -> Bool {
        true
    }

    @objc(_hasActiveControls) dynamic func _hasActiveControls() -> Bool {
        true
    }

    @objc(_hasKeyAppearance) dynamic func _hasKeyAppearance() -> Bool {
        true
    }

    @objc(_hasMainAppearance) dynamic func _hasMainAppearance() -> Bool {
        true
    }

    // swiftlint:enable identifier_name

    func showWithAnimation() {
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
    }

    func hideWithAnimation() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor [weak self] in
                self?.orderOut(nil)
            }
        }
    }
}
