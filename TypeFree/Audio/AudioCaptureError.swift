import Foundation

nonisolated enum AudioCaptureError: Error, Equatable {
    case captureAlreadyRunning
    case missingActiveSession
    case staleSession
    case writerInitializationFailed
    case engineStartFailed
    case bufferFormatMismatch
    case writeFailed
}
