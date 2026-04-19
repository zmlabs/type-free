import Foundation

struct StatusMenuViewModel: Equatable {
    nonisolated let statusTitle: String
    nonisolated let openSettingsTitle: String
    nonisolated let quitTitle: String

    nonisolated init(
        permissionSnapshot: PermissionSnapshot,
        hasActiveProvider: Bool,
        workflowPhase: DictationPhase = .idle
    ) {
        statusTitle = Self.makeStatusTitle(
            permissionSnapshot: permissionSnapshot,
            hasActiveProvider: hasActiveProvider,
            workflowPhase: workflowPhase
        )
        openSettingsTitle = "Settings…"
        quitTitle = "Quit"
    }

    nonisolated static func makeStatusTitle(
        permissionSnapshot: PermissionSnapshot,
        hasActiveProvider: Bool,
        workflowPhase: DictationPhase
    ) -> String {
        if let runtimeTitle = runtimeStatusTitle(for: workflowPhase) {
            return runtimeTitle
        }

        if permissionSnapshot.microphone != .granted {
            return "Microphone Required"
        }

        if permissionSnapshot.accessibility != .granted {
            return "Accessibility Required"
        }

        if !hasActiveProvider {
            return "Provider Not Configured"
        }

        return "Ready"
    }

    nonisolated static func runtimeStatusTitle(for workflowPhase: DictationPhase) -> String? {
        switch workflowPhase {
        case .idle:
            nil
        case .tentativeCapture, .recordingVisible:
            "Recording"
        case .transcribing:
            "Transcribing"
        case .canceled:
            "Canceled"
        case .noSpeech:
            "No Speech"
        case .permissionBlocked:
            "Permission Blocked"
        case .providerFailed:
            "Provider Failed"
        case .insertionFailed:
            "Insertion Failed"
        }
    }
}
