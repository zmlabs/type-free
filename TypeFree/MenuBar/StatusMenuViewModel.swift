import Foundation

struct StatusMenuViewModel: Equatable {
    nonisolated let statusTitle: String
    nonisolated let openSettingsTitle: String
    nonisolated let quitTitle: String

    nonisolated init(
        permissionSnapshot: PermissionSnapshot,
        hasActiveProvider: Bool,
        hasAudioInputDevice: Bool = true,
        workflowPhase: DictationPhase = .idle
    ) {
        statusTitle = Self.makeStatusTitle(
            permissionSnapshot: permissionSnapshot,
            hasActiveProvider: hasActiveProvider,
            hasAudioInputDevice: hasAudioInputDevice,
            workflowPhase: workflowPhase
        )
        openSettingsTitle = String(localized: "Settings…")
        quitTitle = String(localized: "Quit")
    }

    nonisolated static func makeStatusTitle(
        permissionSnapshot: PermissionSnapshot,
        hasActiveProvider: Bool,
        hasAudioInputDevice: Bool,
        workflowPhase: DictationPhase
    ) -> String {
        if let runtimeTitle = runtimeStatusTitle(for: workflowPhase) {
            return runtimeTitle
        }

        if permissionSnapshot.microphone != .granted {
            return String(localized: "Microphone Required")
        }

        if permissionSnapshot.accessibility != .granted {
            return String(localized: "Accessibility Required")
        }

        if !hasAudioInputDevice {
            return String(localized: "No Audio Input Device")
        }

        if !hasActiveProvider {
            return String(localized: "Provider Not Configured")
        }

        return String(localized: "Ready")
    }

    nonisolated static func runtimeStatusTitle(for workflowPhase: DictationPhase) -> String? {
        switch workflowPhase {
        case .idle:
            nil
        case .tentativeCapture, .recordingVisible:
            String(localized: "recording")
        case .transcribing:
            String(localized: "transcribing")
        case .canceled:
            String(localized: "canceled")
        case .noSpeech:
            String(localized: "noSpeech")
        case .permissionBlocked:
            String(localized: "permissionBlocked")
        case .audioInputUnavailable:
            String(localized: "audioInputUnavailable")
        case .providerFailed:
            String(localized: "provider.unavailable")
        case .insertionFailed:
            String(localized: "insertion.writeFailed")
        }
    }

    nonisolated static func updateMenuTitle(isUpdateAvailable: Bool) -> String {
        isUpdateAvailable ? String(localized: "Update Available") : String(localized: "Check for Updates")
    }
}
