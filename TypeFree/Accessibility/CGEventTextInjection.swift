import ApplicationServices
import Carbon

@MainActor
enum CGEventUnicodeInjector {
    static func inject(text: String) throws {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw AccessibilityInsertionError.writeFailed
        }

        let previousSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        var asciiSource: TISInputSource?

        if let prev = previousSource, isCJKInputSource(prev) {
            asciiSource = findASCIIInputSource()
            if let ascii = asciiSource {
                TISSelectInputSource(ascii)
                usleep(80000)
            }
        }

        defer {
            if let prev = previousSource, asciiSource != nil {
                TISSelectInputSource(prev)
            }
        }

        var chunk: [UInt16] = []
        chunk.reserveCapacity(20)

        func flushChunk() throws {
            guard !chunk.isEmpty else { return }
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
                throw AccessibilityInsertionError.writeFailed
            }
            keyDown.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
            keyDown.post(tap: .cghidEventTap)

            guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                throw AccessibilityInsertionError.writeFailed
            }
            keyUp.keyboardSetUnicodeString(stringLength: 0, unicodeString: [])
            keyUp.post(tap: .cghidEventTap)
            chunk.removeAll(keepingCapacity: true)
        }

        for character in text {
            let units = Array(character.utf16)
            if chunk.count + units.count > 20 {
                try flushChunk()
                usleep(4000)
            }
            chunk.append(contentsOf: units)
        }
        try flushChunk()
    }

    private static func isCJKInputSource(_ source: TISInputSource) -> Bool {
        guard let langsProp = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else {
            return false
        }
        let langs = Unmanaged<CFArray>.fromOpaque(langsProp).takeUnretainedValue() as [AnyObject]
        return langs.compactMap { $0 as? String }.contains { lang in
            lang.hasPrefix("zh") || lang.hasPrefix("ja") || lang.hasPrefix("ko")
        }
    }

    private static func findASCIIInputSource() -> TISInputSource? {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceIsASCIICapable as CFString: true,
            kTISPropertyInputSourceCategory as CFString: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceType as CFString: kTISTypeKeyboardLayout as Any,
        ]
        guard let listRef = TISCreateInputSourceList(filter as CFDictionary, false) else {
            return nil
        }
        guard let list = listRef.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }
        return list.first
    }
}
