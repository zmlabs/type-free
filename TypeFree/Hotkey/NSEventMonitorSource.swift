import AppKit
import Foundation

@MainActor
protocol GlobalHotkeyEventSource: AnyObject {
    var eventHandler: (@MainActor (GlobalKeyEvent) -> Void)? { get set }

    @discardableResult
    func start() -> Bool
    func stop()
}

@MainActor
final class NSEventMonitorSource: GlobalHotkeyEventSource {
    var eventHandler: (@MainActor (GlobalKeyEvent) -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    @discardableResult
    func start() -> Bool {
        guard globalMonitor == nil else {
            return true
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            self?.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            self?.handle(event)
            return event
        }

        guard globalMonitor != nil, localMonitor != nil else {
            if let globalMonitor {
                NSEvent.removeMonitor(globalMonitor)
            }
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
            }
            globalMonitor = nil
            localMonitor = nil
            return false
        }

        return true
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard let globalEvent = makeGlobalKeyEvent(from: event) else {
            return
        }
        eventHandler?(globalEvent)
    }

    private func makeGlobalKeyEvent(from event: NSEvent) -> GlobalKeyEvent? {
        let keyCode = CGKeyCode(event.keyCode)
        let identifier = physicalKeyIdentifier(for: keyCode)

        let kind: GlobalKeyEvent.Kind
        let isPressed: Bool

        switch event.type {
        case .keyDown:
            kind = .keyDown
            isPressed = true
        case .keyUp:
            kind = .keyUp
            isPressed = false
        case .flagsChanged:
            kind = .flagsChanged
            isPressed = isModifierKeyPress(keyCode: keyCode, modifierFlags: event.modifierFlags)
        default:
            return nil
        }

        return GlobalKeyEvent(
            timestamp: ProcessInfo.processInfo.systemUptime,
            kind: kind,
            keyCode: keyCode,
            physicalKeyIdentifier: identifier,
            isPressed: isPressed,
            modifierFlagsRawValue: UInt64(event.modifierFlags.rawValue)
        )
    }
}
