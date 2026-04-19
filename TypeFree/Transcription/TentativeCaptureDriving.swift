import Foundation

enum TentativeCaptureError: Error {
    case permissionDenied
    case engineFailure(Error)
    case writerFailure(Error)
}

protocol TentativeCaptureDriving: Sendable {
    func startTentativeCapture(sessionID: UUID, activationScreenID: String) async throws(TentativeCaptureError)
    func finishTentativeCapture(sessionID: UUID) async throws(TentativeCaptureError) -> PreparedCapture
    func cancelTentativeCapture(sessionID: UUID) async
}

actor AudioTentativeCaptureDriver: TentativeCaptureDriving {
    private let audioCapture: any AudioCapturing

    init(audioCapture: any AudioCapturing = AudioCaptureActor()) {
        self.audioCapture = audioCapture
    }

    func startTentativeCapture(sessionID: UUID, activationScreenID: String) async throws(TentativeCaptureError) {
        do {
            try await audioCapture.startTentativeCapture(
                sessionID: sessionID,
                activationScreenID: activationScreenID
            )
        } catch let error as AudioCaptureError {
            switch error {
            case .engineStartFailed, .captureAlreadyRunning, .audioDeviceUnavailable:
                throw TentativeCaptureError.engineFailure(error)
            case .writerInitializationFailed, .writeFailed, .bufferFormatMismatch:
                throw TentativeCaptureError.writerFailure(error)
            case .missingActiveSession, .staleSession:
                throw TentativeCaptureError.engineFailure(error)
            }
        } catch {
            throw TentativeCaptureError.engineFailure(error)
        }
    }

    func finishTentativeCapture(sessionID: UUID) async throws(TentativeCaptureError) -> PreparedCapture {
        do {
            return try await audioCapture.finishTentativeCapture(sessionID: sessionID)
        } catch let error as AudioCaptureError {
            switch error {
            case .engineStartFailed,
                 .captureAlreadyRunning,
                 .missingActiveSession,
                 .staleSession,
                 .audioDeviceUnavailable:
                throw TentativeCaptureError.engineFailure(error)
            case .writerInitializationFailed, .writeFailed, .bufferFormatMismatch:
                throw TentativeCaptureError.writerFailure(error)
            }
        } catch {
            throw TentativeCaptureError.engineFailure(error)
        }
    }

    func cancelTentativeCapture(sessionID: UUID) async {
        await audioCapture.cancelTentativeCapture(sessionID: sessionID)
    }
}
