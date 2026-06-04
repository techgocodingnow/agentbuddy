import XCTest
@testable import AgentBuddyCore

final class TranscriptReaderTests: XCTestCase {
    private func writeTemp(_ contents: String) -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tr-\(UUID().uuidString).jsonl")
        try! contents.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    func testReturnsLastAssistantText() {
        let jsonl = """
        {"type":"user","message":{"content":[{"type":"text","text":"hi"}]}}
        {"type":"assistant","message":{"content":[{"type":"text","text":"First reply"}]}}
        {"type":"assistant","message":{"content":[{"type":"text","text":"Final reply"}]}}
        """
        XCTAssertEqual(TranscriptReader.lastAssistantText(path: writeTemp(jsonl)), "Final reply")
    }

    func testJoinsTextBlocksAndSkipsToolUse() {
        let jsonl = #"{"type":"assistant","message":{"content":[{"type":"text","text":"Done. "},{"type":"tool_use","name":"Bash"},{"type":"text","text":"Tests pass."}]}}"#
        XCTAssertEqual(TranscriptReader.lastAssistantText(path: writeTemp(jsonl)), "Done. Tests pass.")
    }

    func testIgnoresTrailingNonAssistantLines() {
        let jsonl = """
        {"type":"assistant","message":{"content":[{"type":"text","text":"The answer"}]}}
        {"type":"user","message":{"content":[{"type":"tool_result","text":"ok"}]}}
        """
        XCTAssertEqual(TranscriptReader.lastAssistantText(path: writeTemp(jsonl)), "The answer")
    }

    func testCollapsesNewlines() {
        let jsonl = #"{"type":"assistant","message":{"content":[{"type":"text","text":"line one\nline two"}]}}"#
        XCTAssertEqual(TranscriptReader.lastAssistantText(path: writeTemp(jsonl)), "line one line two")
    }

    func testTruncatesLongMessageWithEllipsis() {
        let long = String(repeating: "a", count: 500)
        let jsonl = #"{"type":"assistant","message":{"content":[{"type":"text","text":"\#(long)"}]}}"#
        let result = TranscriptReader.lastAssistantText(path: writeTemp(jsonl))
        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(result!.count, TranscriptReader.maxMessageLength + 1)
        XCTAssertTrue(result!.hasSuffix("…"))
    }

    func testNilForMissingFile() {
        XCTAssertNil(TranscriptReader.lastAssistantText(path: "/no/such/file.jsonl"))
    }

    func testNilWhenNoAssistantText() {
        let jsonl = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]}}"#
        XCTAssertNil(TranscriptReader.lastAssistantText(path: writeTemp(jsonl)))
    }
}
