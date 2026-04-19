import Testing
@testable import TypeFree

@MainActor
struct GlobalHotkeyMonitorTests {
    @Test
    func startForwardsClassifiedActionsFromTheEventSource() {
        let source = FakeGlobalHotkeyEventSource()
        let recorder = ActionRecorder()
        let monitor = GlobalHotkeyMonitor(
            source: source,
            hotkey: .default,
            doublePressInterval: 0.5
        ) { action in
            MainActor.assumeIsolated {
                recorder.actions.append(action)
            }
        }

        monitor.start()
        source.emit(
            GlobalKeyEvent(
                timestamp: 1.0,
                kind: .flagsChanged,
                keyCode: 63,
                physicalKeyIdentifier: "fn",
                isPressed: true,
                modifierFlagsRawValue: 0
            )
        )
        source.emit(
            GlobalKeyEvent(
                timestamp: 1.1,
                kind: .flagsChanged,
                keyCode: 63,
                physicalKeyIdentifier: "fn",
                isPressed: false,
                modifierFlagsRawValue: 0
            )
        )

        #expect(source.startCallCount == 1)
        #expect(recorder.actions == [.hotkeyDown(timestamp: 1.0), .hotkeyUp(timestamp: 1.1)])
    }

    @Test
    func stopClearsTheEventHandler() {
        let source = FakeGlobalHotkeyEventSource()
        let recorder = ActionRecorder()
        let monitor = GlobalHotkeyMonitor(
            source: source,
            hotkey: .default,
            doublePressInterval: 0.5
        ) { action in
            MainActor.assumeIsolated {
                recorder.actions.append(action)
            }
        }

        monitor.start()
        monitor.stop()
        source.emit(
            GlobalKeyEvent(
                timestamp: 1.0,
                kind: .flagsChanged,
                keyCode: 63,
                physicalKeyIdentifier: "fn",
                isPressed: true,
                modifierFlagsRawValue: 0
            )
        )

        #expect(source.stopCallCount == 1)
        #expect(recorder.actions.isEmpty)
    }

    @Test
    func forwardsDoublePressWhileMonitoringRemainsActive() {
        let source = FakeGlobalHotkeyEventSource()
        let recorder = ActionRecorder()
        let monitor = GlobalHotkeyMonitor(
            source: source,
            hotkey: .default,
            doublePressInterval: 0.5
        ) { action in
            MainActor.assumeIsolated {
                recorder.actions.append(action)
            }
        }

        monitor.start()
        source.emit(makeFnKeyEvent(timestamp: 1.0, isPressed: true))
        source.emit(makeFnKeyEvent(timestamp: 1.05, isPressed: false))
        source.emit(makeFnKeyEvent(timestamp: 1.25, isPressed: true))

        #expect(recorder.actions == [
            .hotkeyDown(timestamp: 1.0),
            .hotkeyUp(timestamp: 1.05),
            .doublePress(timestamp: 1.25),
        ])

        source.emit(makeFnKeyEvent(timestamp: 2.0, isPressed: true))
        source.emit(makeFnKeyEvent(timestamp: 2.1, isPressed: false))

        #expect(recorder.actions == [
            .hotkeyDown(timestamp: 1.0),
            .hotkeyUp(timestamp: 1.05),
            .doublePress(timestamp: 1.25),
            .hotkeyDown(timestamp: 2.0),
            .hotkeyUp(timestamp: 2.1),
        ])
    }
}

@MainActor
private final class FakeGlobalHotkeyEventSource: GlobalHotkeyEventSource {
    var eventHandler: (@MainActor (GlobalKeyEvent) -> Void)?
    var startCallCount = 0
    var stopCallCount = 0

    @discardableResult
    func start() -> Bool {
        startCallCount += 1
        return true
    }

    func stop() {
        stopCallCount += 1
    }

    func emit(_ event: GlobalKeyEvent) {
        eventHandler?(event)
    }
}

@MainActor
private final class ActionRecorder {
    var actions: [GlobalHotkeyAction] = []
}

private func makeFnKeyEvent(timestamp: Double, isPressed: Bool) -> GlobalKeyEvent {
    GlobalKeyEvent(
        timestamp: timestamp,
        kind: .flagsChanged,
        keyCode: 63,
        physicalKeyIdentifier: "fn",
        isPressed: isPressed,
        modifierFlagsRawValue: 0
    )
}
