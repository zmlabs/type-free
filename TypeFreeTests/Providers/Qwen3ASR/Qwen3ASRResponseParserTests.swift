import Foundation
import Testing
@testable import TypeFree

struct Qwen3ASRResponseParserTests {
    @Test
    func parseReturnsTrimmedTranscriptAndDuration() throws {
        let parser = Qwen3ASRResponseParser()

        let output = try parser.parse(
            data: Data(
                #"""
                {
                  "output": {
                    "choices": [
                      {
                        "message": {
                          "content": [
                            {
                              "text": " hello qwen "
                            }
                          ]
                        }
                      }
                    ]
                  },
                  "usage": {
                    "seconds": 1.25
                  }
                }
                """#.utf8
            )
        )

        #expect(output == .transcript(TranscriptionResult(text: "hello qwen")))
    }

    @Test
    func parseMapsBlankTextToNoSpeech() throws {
        let parser = Qwen3ASRResponseParser()

        let output = try parser.parse(
            data: Data(
                #"""
                {
                  "output": {
                    "choices": [
                      {
                        "message": {
                          "content": [
                            {
                              "text": "   "
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
                """#.utf8
            )
        )

        #expect(output == .noSpeech)
    }

    @Test
    func parseRejectsPayloadsWithoutUsableTranscriptText() {
        let parser = Qwen3ASRResponseParser()

        #expect(throws: TranscriptionProviderError
            .invalidResponse(message: "Provider 返回体缺少 output.choices[0].message.content[0].text 字段：Invalid API key"))
        {
            _ = try parser.parse(
                data: Data(
                    #"""
                    {
                      "message": "Invalid API key"
                    }
                    """#.utf8
                )
            )
        }
    }
}
