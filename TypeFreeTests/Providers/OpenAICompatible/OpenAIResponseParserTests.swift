import Foundation
import Testing
@testable import TypeFree

struct OpenAIResponseParserTests {
    @Test
    func parseReturnsTrimmedTranscriptWhenTextIsPresent() throws {
        let parser = OpenAIResponseParser()

        let output = try parser.parse(data: Data(#"{"text":" hello "}"#.utf8))

        #expect(output == .transcript(TranscriptionResult(text: "hello")))
    }

    @Test
    func parseMapsBlankTextToNoSpeech() throws {
        let parser = OpenAIResponseParser()

        let output = try parser.parse(data: Data(#"{"text":"   "}"#.utf8))

        #expect(output == .noSpeech)
    }

    @Test
    func parseRejectsPayloadsWithoutUsableText() {
        let parser = OpenAIResponseParser()

        do {
            _ = try parser.parse(data: Data(#"{"error":"Missing Authorization header"}"#.utf8))
            Issue.record("Expected parser to reject payload without text")
        } catch let error as TranscriptionProviderError {
            #expect(
                error == .invalidResponse(
                    message: "Provider 返回体缺少 text 字段：Missing Authorization header"
                )
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
