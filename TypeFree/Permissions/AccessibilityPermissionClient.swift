import ApplicationServices
import Foundation

@MainActor
protocol AccessibilityPermissionClient: Sendable {
    func status() -> PermissionAuthorizationState
    func requestTrustPrompt() -> PermissionAuthorizationState
}

@MainActor
struct SystemAccessibilityPermissionClient: AccessibilityPermissionClient {
    func status() -> PermissionAuthorizationState {
        AXIsProcessTrusted() ? .granted : .denied
    }

    func requestTrustPrompt() -> PermissionAuthorizationState {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options) ? .granted : .denied
    }
}
