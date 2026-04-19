import Foundation

@MainActor
final class MainWindowActionBridge {
    var onHotkeySaved: (HotkeyConfiguration) -> Void
    var onRuntimeStateChanged: () -> Void

    init(
        onHotkeySaved: @escaping (HotkeyConfiguration) -> Void = { _ in },
        onRuntimeStateChanged: @escaping () -> Void = {}
    ) {
        self.onHotkeySaved = onHotkeySaved
        self.onRuntimeStateChanged = onRuntimeStateChanged
    }

    func applyHotkey(_ hotkey: HotkeyConfiguration) {
        onHotkeySaved(hotkey)
        onRuntimeStateChanged()
    }

    func refreshRuntimeState() {
        onRuntimeStateChanged()
    }
}
