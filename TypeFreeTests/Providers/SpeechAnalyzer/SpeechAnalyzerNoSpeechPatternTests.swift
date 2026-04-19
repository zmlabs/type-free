import Foundation
import Speech
import Testing
@testable import TypeFree

struct SpeechAnalyzerNoSpeechPatternTests {
    @Test
    func matchesRecogRejectedError() {
        let error = NSError(
            domain: SFSpeechErrorDomain,
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "RecogRejected"]
        )

        #expect(SpeechAnalyzerNoSpeechPattern.matches(error))
    }

    @Test
    func doesNotMatchOtherSpeechErrorCodes() {
        let error = NSError(domain: SFSpeechErrorDomain, code: 2)

        #expect(!SpeechAnalyzerNoSpeechPattern.matches(error))
    }

    @Test
    func doesNotMatchCode1FromDifferentDomain() {
        let error = NSError(domain: "com.example.other", code: 1)

        #expect(!SpeechAnalyzerNoSpeechPattern.matches(error))
    }

    @Test
    func doesNotMatchUnrelatedError() {
        struct SampleError: Error {}

        #expect(!SpeechAnalyzerNoSpeechPattern.matches(SampleError()))
    }
}
