import AppKit

@MainActor
final class GlobalHotkeyMonitor {
    private let source: any GlobalHotkeyEventSource
    private let handler: @Sendable (GlobalHotkeyAction) -> Void
    private let doublePressInterval: TimeInterval

    private var classifier: HotkeyPressClassifier
    private var isRunning = false

    init(
        source: any GlobalHotkeyEventSource,
        hotkey: HotkeyConfiguration,
        doublePressInterval: TimeInterval = NSEvent.doubleClickInterval,
        handler: @escaping @Sendable (GlobalHotkeyAction) -> Void
    ) {
        self.source = source
        self.handler = handler
        self.doublePressInterval = doublePressInterval
        classifier = HotkeyPressClassifier(
            hotkey: hotkey,
            doublePressInterval: doublePressInterval
        )
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else {
            return true
        }

        source.eventHandler = { [weak self] event in
            self?.receive(event)
        }

        guard source.start() else {
            source.eventHandler = nil
            return false
        }

        isRunning = true
        return true
    }

    func stop() {
        source.stop()
        source.eventHandler = nil
        isRunning = false
    }

    func updateHotkey(_ hotkey: HotkeyConfiguration) {
        classifier = HotkeyPressClassifier(
            hotkey: hotkey,
            doublePressInterval: doublePressInterval
        )
    }

    private func receive(_ event: GlobalKeyEvent) {
        guard let action = classifier.consume(event) else {
            return
        }

        handler(action)
    }
}
