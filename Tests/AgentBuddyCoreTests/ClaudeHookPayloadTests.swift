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

    func testDecodesTitleAndPrompt() {
        let p = payload(#"{"session_id":"s","cwd":"/p","hook_event_name":"UserPromptSubmit","session_title":"Assess Codex Pet clone idea","prompt":"Sync title to pet"}"#)
        let event = p?.makeEvent(now: now, kind: .codex)

        XCTAssertEqual(event?.title, "Assess Codex Pet clone idea")
        XCTAssertNil(event?.message)
    }

    func testPromptSeedsTitleButNotMessage() {
        let p = payload(#"{"session_id":"s","cwd":"/p","hook_event_name":"UserPromptSubmit","prompt":"Please sync title to pet"}"#)
        let event = p?.makeEvent(now: now, kind: .codex)

        XCTAssertEqual(event?.title, "sync title to pet")
        XCTAssertNil(event?.message)
    }

    func testExplicitMessageWinsOverPrompt() {
        let p = payload(#"{"session_id":"s","hook_event_name":"UserPromptSubmit","prompt":"user prompt","message":"explicit message"}"#)
        let event = p?.makeEvent(now: now, kind: .codex)

        XCTAssertEqual(event?.message, "explicit message")
    }

    func testStopReadsTranscriptMessage() {
        let p = payload(#"{"session_id":"s","hook_event_name":"Stop","transcript_path":"/x.jsonl"}"#)
        let event = p?.makeEvent(now: now, kind: .claude, readTranscript: { path in
            path == "/x.jsonl" ? "Refactored the parser." : nil
        })
        XCTAssertEqual(event?.message, "Refactored the parser.")
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: event!.eventName), .done)
    }

    func testClaudeWorkingEventReadsTranscriptMessage() {
        let p = payload(#"{"session_id":"s","hook_event_name":"PreToolUse","transcript_path":"/x.jsonl"}"#)
        let event = p?.makeEvent(now: now, kind: .claude, readTranscript: { path in
            path == "/x.jsonl" ? "I will inspect the hook flow." : nil
        })

        XCTAssertEqual(event?.message, "I will inspect the hook flow.")
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: event!.eventName), .working)
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

    func testCodexStopReadsTranscriptMessage() {
        let p = payload(#"{"session_id":"s","hook_event_name":"Stop","transcript_path":"/x"}"#)
        let event = p?.makeEvent(now: now, kind: .codex, readTranscript: { path in
            path == "/x" ? "Codex finished the patch." : nil
        })

        XCTAssertEqual(event?.message, "Codex finished the patch.")
    }

    func testCodexEventReadsUsageAndQuotaMetrics() {
        let p = payload(#"{"session_id":"s","hook_event_name":"Stop","transcript_path":"/x"}"#)
        let event = p?.makeEvent(now: now, kind: .codex, readUsage: { path in
            path == "/x" ? ContextUsage(usedTokens: 25_000, limitTokens: 100_000) : nil
        }, readQuotaUsage: { path in
            path == "/x" ? AgentQuotaUsage(sessionUsedPercent: 10, weeklyUsedPercent: 20) : nil
        })

        XCTAssertEqual(event?.usage?.percentUsed, 25)
        XCTAssertEqual(event?.quotaUsage?.sessionUsedPercent, 10)
        XCTAssertEqual(event?.quotaUsage?.weeklyUsedPercent, 20)
    }

    func testDerivesTitleFromTranscriptWhenPromptMissing() {
        let p = payload(#"{"session_id":"s","hook_event_name":"Stop","transcript_path":"/x"}"#)
        let event = p?.makeEvent(now: now, kind: .codex, readSessionTitle: { _ in nil }, readTitle: { path in
            path == "/x" ? "Assess Codex Pet clone idea" : nil
        })

        XCTAssertEqual(event?.title, "Assess Codex Pet clone idea")
    }

    func testDerivesTitleFromCodexSessionIndexBeforeTranscriptFallback() {
        let p = payload(#"{"session_id":"s","hook_event_name":"Stop","transcript_path":"/x"}"#)
        let event = p?.makeEvent(now: now, kind: .codex, readSessionTitle: { sessionId in
            sessionId == "s" ? "Assess Codex Pet clone idea" : nil
        }, readTitle: { _ in
            "fallback transcript title"
        })

        XCTAssertEqual(event?.title, "Assess Codex Pet clone idea")
    }

    func testPromptWinsOverTranscriptTitle() {
        let p = payload(#"{"session_id":"s","hook_event_name":"UserPromptSubmit","prompt":"Please sync title to pet","transcript_path":"/x"}"#)
        let event = p?.makeEvent(now: now, kind: .codex, readSessionTitle: { _ in
            "Old indexed title"
        }, readTitle: { _ in
            "Old transcript title"
        })

        XCTAssertEqual(event?.title, "sync title to pet")
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

    func testPopulatesRuntimeStatsOnClaudeEvent() {
        let p = payload(#"{"session_id":"s","hook_event_name":"PreToolUse","transcript_path":"/x.jsonl"}"#)
        let event = p?.makeEvent(now: now, kind: .claude, readStats: { path in
            path == "/x.jsonl" ? AgentRuntimeStats(model: "claude-opus-4-8", speed: "standard", serviceTier: "standard") : nil
        })

        XCTAssertEqual(event?.stats?.model, "claude-opus-4-8")
        XCTAssertEqual(event?.stats?.speed, "standard")
        XCTAssertEqual(event?.stats?.serviceTier, "standard")
    }

    func testPopulatesRuntimeStatsOnCodexEvent() {
        let p = payload(#"{"session_id":"s","hook_event_name":"PreToolUse","transcript_path":"/x.jsonl"}"#)
        let event = p?.makeEvent(now: now, kind: .codex, readStats: { path in
            path == "/x.jsonl" ? AgentRuntimeStats(model: "gpt-5.5", speed: "fast", effort: "high") : nil
        })

        XCTAssertEqual(event?.stats?.model, "gpt-5.5")
        XCTAssertEqual(event?.stats?.speed, "fast")
        XCTAssertEqual(event?.stats?.effort, "high")
    }

    func testUsageNilForKindWithoutTranscriptUsage() {
        let p = payload(#"{"session_id":"s","hook_event_name":"PreToolUse","transcript_path":"/x.jsonl"}"#)
        let event = p?.makeEvent(now: now, kind: .gemini, readUsage: { _ in
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
