import AVFAudio
import AVFoundation
import Foundation

protocol MicrophonePermissionClient: Sendable {
    nonisolated func status() -> PermissionAuthorizationState
    nonisolated func requestPermission() async -> PermissionAuthorizationState
}

protocol MicrophoneAuthorizationControlling: Sendable {
    nonisolated func status() -> AVAuthorizationStatus
    nonisolated func requestAccess() async -> Bool
}

struct CaptureDeviceAudioAccessController: MicrophoneAuthorizationControlling {
    nonisolated func status() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    nonisolated func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

struct SystemMicrophonePermissionClient: MicrophonePermissionClient {
    private let authorizationController: any MicrophoneAuthorizationControlling

    nonisolated init(
        authorizationController: any MicrophoneAuthorizationControlling =
            CaptureDeviceAudioAccessController()
    ) {
        self.authorizationController = authorizationController
    }

    nonisolated func status() -> PermissionAuthorizationState {
        Self.map(authorizationController.status())
    }

    nonisolated func requestPermission() async -> PermissionAuthorizationState {
        let beforeCaptureStatus = authorizationController.status()
        let beforeMappedStatus = Self.map(beforeCaptureStatus)

        guard beforeCaptureStatus == .notDetermined else {
            return beforeMappedStatus
        }

        let granted = await authorizationController.requestAccess()
        let afterCaptureStatus = authorizationController.status()
        return Self.statusAfterRequest(
            granted: granted,
            authorizationStatus: afterCaptureStatus
        )
    }

    nonisolated private static func map(_ status: AVAuthorizationStatus) -> PermissionAuthorizationState {
        switch status {
        case .notDetermined:
            .undetermined
        case .authorized:
            .granted
        case .restricted, .denied:
            .denied
        @unknown default:
            .denied
        }
    }

    nonisolated private static func statusAfterRequest(
        granted: Bool,
        authorizationStatus: AVAuthorizationStatus
    ) -> PermissionAuthorizationState {
        let mappedStatus = map(authorizationStatus)

        if mappedStatus == .undetermined {
            return granted ? .granted : .denied
        }

        return mappedStatus
    }
}
