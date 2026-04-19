import AppKit
import ApplicationServices

@MainActor
struct TextInjector: AccessibilityTextInserting {
    func insert(text: String) async throws {
        guard !text.isEmpty else { return }
        let target = resolveTarget()
        guard !target.isSecureTextField else {
            throw AccessibilityInsertionError.notEditable
        }
        if target.usesWebContent {
            try ClipboardPaster.paste(text: text)
        } else {
            do {
                try CGEventUnicodeInjector.inject(text: text)
            } catch {
                try ClipboardPaster.paste(text: text)
            }
        }
    }
}

private extension TextInjector {
    struct Target {
        let processIdentifier: pid_t
        let bundleIdentifier: String?
        let usesWebContent: Bool
        let isSecureTextField: Bool
    }

    func resolveTarget() -> Target {
        let app = NSWorkspace.shared.frontmostApplication
        let pid = app?.processIdentifier ?? 0
        let bundleID = app?.bundleIdentifier
        let focused = focusedElement(pid: pid)

        return Target(
            processIdentifier: pid,
            bundleIdentifier: bundleID,
            usesWebContent: isWebContent(
                focused: focused, pid: pid, bundleID: bundleID
            ),
            isSecureTextField: isSecureField(focused: focused)
        )
    }

    func focusedElement(pid: pid_t) -> AXUIElement? {
        guard pid > 0 else { return nil }
        let app = AXUIElementCreateApplication(pid)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            app, kAXFocusedUIElementAttribute as CFString, &ref
        ) == .success,
            let value = ref,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return unsafeDowncast(value as AnyObject, to: AXUIElement.self)
    }

    func isWebContent(
        focused: AXUIElement?,
        pid: pid_t,
        bundleID: String?
    ) -> Bool {
        if let element = focused, hasWebAreaInHierarchy(element) { return true }
        if isElectronApp(pid: pid) { return true }
        if let id = bundleID, isKnownBrowser(id) { return true }
        return false
    }

    func hasWebAreaInHierarchy(_ element: AXUIElement) -> Bool {
        var current = element
        for _ in 0 ..< 10 {
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                current, kAXRoleAttribute as CFString, &roleRef
            ) == .success,
                let role = roleRef as? String, role == "AXWebArea"
            {
                return true
            }
            var parentRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                current, kAXParentAttribute as CFString, &parentRef
            ) == .success,
                let parent = parentRef,
                CFGetTypeID(parent) == AXUIElementGetTypeID()
            else { break }
            current = unsafeDowncast(parent as AnyObject, to: AXUIElement.self)
        }
        return false
    }

    func isElectronApp(pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid),
              let url = app.bundleURL else { return false }
        let path = url.appendingPathComponent(
            "Contents/Frameworks/Electron Framework.framework"
        )
        return FileManager.default.fileExists(atPath: path.path)
    }

    func isKnownBrowser(_ bundleID: String) -> Bool {
        let prefixes = [
            "com.google.Chrome",
            "com.brave.Browser",
            "org.mozilla.firefox",
            "com.apple.Safari",
            "com.microsoft.edgemac",
            "company.thebrowser.Browser",
        ]
        return prefixes.contains { bundleID.hasPrefix($0) }
    }

    func isSecureField(focused: AXUIElement?) -> Bool {
        guard let element = focused else { return false }
        var subroleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSubroleAttribute as CFString, &subroleRef
        ) == .success,
            let subrole = subroleRef as? String else { return false }
        return subrole == kAXSecureTextFieldSubrole
    }
}
