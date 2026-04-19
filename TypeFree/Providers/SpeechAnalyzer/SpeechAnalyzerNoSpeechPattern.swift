import Foundation
import Speech

nonisolated enum SpeechAnalyzerNoSpeechPattern {
    static func matches(_ error: any Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == SFSpeechErrorDomain && nsError.code == recogRejectedCode
    }

    private static let recogRejectedCode = 1
}
