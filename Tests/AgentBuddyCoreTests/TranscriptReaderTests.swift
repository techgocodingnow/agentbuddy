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

    // MARK: Usage

    func testLastUsageSumsInputAndCacheTokensFromLatestLine() {
        // Mirrors the real Claude transcript shape; the latest assistant line wins.
        let jsonl = """
        {"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"input_tokens":5,"cache_read_input_tokens":1000,"cache_creation_input_tokens":10}}}
        {"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"input_tokens":2,"cache_creation_input_tokens":762,"cache_read_input_tokens":81956,"output_tokens":418}}}
        """
        let usage = TranscriptReader.lastUsage(path: writeTemp(jsonl))
        XCTAssertEqual(usage?.usedTokens, 82_720) // 2 + 81956 + 762; output excluded
        XCTAssertEqual(usage?.limitTokens, 200_000)
    }

    func testLastUsageIgnoresPartialLeadingLine() {
        // A leading line cut by the tail read fails to decode and is skipped.
        let jsonl = """
        nput_tokens":99,"cache_read_input_tokens":99}}}
        {"type":"assistant","message":{"usage":{"input_tokens":3,"cache_read_input_tokens":7,"cache_creation_input_tokens":0}}}
        """
        XCTAssertEqual(TranscriptReader.lastUsage(path: writeTemp(jsonl))?.usedTokens, 10)
    }

    func testLastUsageNilWhenNoUsagePresent() {
        let jsonl = #"{"type":"assistant","message":{"content":[{"type":"text","text":"hi"}]}}"#
        XCTAssertNil(TranscriptReader.lastUsage(path: writeTemp(jsonl)))
    }

    func testLastUsageNilForMissingFile() {
        XCTAssertNil(TranscriptReader.lastUsage(path: "/no/such/file.jsonl"))
    }
}
