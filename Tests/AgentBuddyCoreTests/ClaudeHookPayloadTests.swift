import XCTest
@testable import AgentBuddyCore

final class ClaudeHookPayloadTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100)

    private func payload(_ json: String) -> ClaudeHookPayload? {
        ClaudeHookPayload.decode(from: Data(json.utf8))
    }

    func testDecodesSessionStart() {
        let event = payload(#"{"session_id":"abc","cwd":"/Users/x/proj","hook_event_name":"SessionStart"}"#)?
            .makeEvent(now: now)
        XCTAssertEqual(event?.sessionId, "abc")
        XCTAssertEqual(event?.project, "/Users/x/proj")
        XCTAssertEqual(event?.eventName, "SessionStart")
        XCTAssertEqual(event?.agentKind, .claude)
    }

    func testDecodesNotificationWithMessage() {
        let p = payload(#"{"session_id":"s","cwd":"/p","hook_event_name":"Notification","message":"needs permission"}"#)
        let event = p?.makeEvent(now: now)
        XCTAssertEqual(event?.message, "needs permission")
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: event!.eventName), .waiting)
    }

    func testStopReadsTranscriptMessage() {
        let p = payload(#"{"session_id":"s","hook_event_name":"Stop","transcript_path":"/x.jsonl"}"#)
        let event = p?.makeEvent(now: now, kind: .claude, readTranscript: { path in
            path == "/x.jsonl" ? "Refactored the parser." : nil
        })
        XCTAssertEqual(event?.message, "Refactored the parser.")
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: event!.eventName), .done)
    }

    func testExplicitMessageWinsOverTranscript() {
        let p = payload(#"{"session_id":"s","hook_event_name":"Notification","message":"needs permission","transcript_path":"/x"}"#)
        let event = p?.makeEvent(now: now, readTranscript: { _ in "should be ignored" })
        XCTAssertEqual(event?.message, "needs permission")
    }

    func testToolNameDoesNotBecomeDisplayMessage() {
        let p = payload(#"{"session_id":"s","hook_event_name":"PreToolUse","tool_name":"Bash"}"#)
        let event = p?.makeEvent(now: now, kind: .codex)
        XCTAssertNil(event?.message)
        XCTAssertEqual(StateMapper.state(for: .codex, eventName: event!.eventName), .working)
    }

    func testTranscriptIgnoredForNonClaudeKind() {
        let p = payload(#"{"session_id":"s","hook_event_name":"Stop","transcript_path":"/x"}"#)
        let event = p?.makeEvent(now: now, kind: .codex, readTranscript: { _ in "claude-only text" })
        XCTAssertNil(event?.message)
    }

    func testIgnoresUnknownFields() {
        // Real Claude payloads carry extra keys (transcript_path, stop_hook_active, ...).
        let event = payload(#"{"session_id":"s","hook_event_name":"Stop","transcript_path":"/t","stop_hook_active":false}"#)?
            .makeEvent(now: now)
        XCTAssertEqual(event?.eventName, "Stop")
        XCTAssertNil(event?.project)
    }

    func testNilWhenMissingEssentialFields() {
        XCTAssertNil(payload(#"{"cwd":"/p"}"#)?.makeEvent(now: now))
        XCTAssertNil(payload("not json"))
    }

    func testPopulatesUsageOnNonTerminalEvent() {
        // Usage is read on every Claude event, not only Stop/SubagentStop.
        let p = payload(#"{"session_id":"s","hook_event_name":"PreToolUse","transcript_path":"/x.jsonl"}"#)
        let event = p?.makeEvent(now: now, kind: .claude, readUsage: { path in
            path == "/x.jsonl" ? ContextUsage(usedTokens: 82_720, limitTokens: 200_000) : nil
        })
        XCTAssertEqual(event?.usage?.usedTokens, 82_720)
        XCTAssertEqual(event?.usage?.percentLeft, 59)
    }

    func testUsageNilForNonClaudeKind() {
        let p = payload(#"{"session_id":"s","hook_event_name":"PreToolUse","transcript_path":"/x.jsonl"}"#)
        let event = p?.makeEvent(now: now, kind: .codex, readUsage: { _ in
            ContextUsage(usedTokens: 1, limitTokens: 200_000)
        })
        XCTAssertNil(event?.usage)
    }

    func testUsageNilWhenNoTranscriptPath() {
        let p = payload(#"{"session_id":"s","hook_event_name":"PreToolUse"}"#)
        let event = p?.makeEvent(now: now, readUsage: { _ in
            ContextUsage(usedTokens: 1, limitTokens: 200_000)
        })
        XCTAssertNil(event?.usage)
    }
}
