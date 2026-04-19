import AppKit
import ApplicationServices

@MainActor
enum ClipboardPaster {
    static func paste(text: String) throws {
        let pasteboard = NSPasteboard.general
        let saved = saveContents(of: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let changeCountAfterWrite = pasteboard.changeCount

        do {
            try simulateCmdV()
        } catch {
            Task {
                try? await Task.sleep(for: .seconds(0.4))
                if pasteboard.changeCount == changeCountAfterWrite {
                    restoreContents(saved, to: pasteboard)
                }
            }
            throw error
        }

        Task {
            try? await Task.sleep(for: .seconds(0.4))
            if pasteboard.changeCount == changeCountAfterWrite {
                restoreContents(saved, to: pasteboard)
            }
        }
    }

    private static func saveContents(of pasteboard: NSPasteboard) -> [[(NSPasteboard.PasteboardType, Data)]] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            }
        }
    }

    private static func restoreContents(_ saved: [[(NSPasteboard.PasteboardType, Data)]], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !saved.isEmpty else { return }
        let pasteboardItems = saved.map { payload -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in payload {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(pasteboardItems)
    }

    private static func simulateCmdV() throws {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw AccessibilityInsertionError.writeFailed
        }

        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let leftCmdDevice = CGEventFlags(rawValue: 0x000008)
        let cmdFlag: CGEventFlags = [.maskCommand, leftCmdDevice]

        guard
            let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        else {
            throw AccessibilityInsertionError.writeFailed
        }

        cmdDown.flags = cmdFlag
        vDown.flags = cmdFlag
        vUp.flags = cmdFlag

        cmdDown.post(tap: .cgAnnotatedSessionEventTap)
        vDown.post(tap: .cgAnnotatedSessionEventTap)
        vUp.post(tap: .cgAnnotatedSessionEventTap)
        cmdUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
