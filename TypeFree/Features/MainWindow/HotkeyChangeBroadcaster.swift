import Foundation

@MainActor
final class HotkeyChangeBroadcaster {
    private var observers: [ObjectIdentifier: WeakObserver] = [:]

    func register(_ observer: any HotkeyChangeObserver) {
        observers[ObjectIdentifier(observer)] = WeakObserver(observer)
    }

    func broadcast(_ hotkey: HotkeyConfiguration) {
        observers = observers.filter { $0.value.value != nil }
        for entry in observers.values {
            entry.value?.hotkeyDidChange(hotkey)
        }
    }
}

@MainActor
protocol HotkeyChangeObserver: AnyObject {
    func hotkeyDidChange(_ hotkey: HotkeyConfiguration)
}

private final class WeakObserver {
    weak var value: (any HotkeyChangeObserver)?
    init(_ value: any HotkeyChangeObserver) {
        self.value = value
    }
}
