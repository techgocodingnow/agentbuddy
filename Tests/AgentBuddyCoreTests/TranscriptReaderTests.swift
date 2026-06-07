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

    func testReturnsCodexResponseItemAssistantText() {
        let jsonl = """
        {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"hello"}]}}
        {"type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Agent reply."}]}}
        """
        XCTAssertEqual(TranscriptReader.lastAssistantText(path: writeTemp(jsonl)), "Agent reply.")
    }

    func testReturnsCodexAgentMessageText() {
        let jsonl = """
        {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"hello"}]}}
        {"type":"event_msg","payload":{"type":"agent_message","message":"I am checking the app now.","phase":"commentary"}}
        """
        XCTAssertEqual(TranscriptReader.lastAssistantText(path: writeTemp(jsonl)), "I am checking the app now.")
    }

    func testReturnsCodexSessionTitleFromFirstMeaningfulUserMessage() {
        let jsonl = """
        {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"# AGENTS.md instructions for /repo\\n<environment_context>bootstrap</environment_context>"}]}}
        {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Check this idea and give honest feedback\\nIdea: Can we clone feature Codex Pet how it works in current codebase, accept to rewrite if needed"}]}}
        {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"follow-up should not win"}]}}
        """

        XCTAssertEqual(
            TranscriptReader.sessionTitle(path: writeTemp(jsonl)),
            "clone feature Codex Pet how it works in current"
        )
    }

    func testReturnsExactCodexSessionIndexTitle() {
        let jsonl = """
        {"id":"s","thread_name":"Old title"}
        {"id":"other","thread_name":"Other title"}
        {"id":"s","thread_name":"Assess Codex Pet clone idea"}
        """

        XCTAssertEqual(
            TranscriptReader.indexedSessionTitle(sessionId: "s", indexPath: writeTemp(jsonl)),
            "Assess Codex Pet clone idea"
        )
    }

    func testReturnsExactClaudeAITitleBeforeFallback() {
        let jsonl = """
        {"type":"user","message":{"content":[{"type":"text","text":"fallback user request should not win"}]}}
        {"type":"ai-title","sessionId":"s","aiTitle":"Old Claude title"}
        {"type":"ai-title","sessionId":"s","aiTitle":"Fix pet session title"}
        """

        XCTAssertEqual(
            TranscriptReader.sessionTitle(path: writeTemp(jsonl)),
            "Fix pet session title"
        )
    }

    func testReturnsSessionTitleFromMyRequestForCodexBlock() {
        let jsonl = """
        {"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"# Files mentioned by the user:\\n\\n## Screenshot.png\\n\\n## My request for Codex:\\nit seems more useful now, about agentbuddy currently it shows name of project"}]}}
        """

        XCTAssertEqual(
            TranscriptReader.sessionTitle(path: writeTemp(jsonl)),
            "it seems more useful now, about agentbuddy currently it"
        )
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
        XCTAssertEqual(usage?.modelName, "claude-opus-4-8")
        XCTAssertNil(usage?.effort)
    }

    func testLastUsageReadsEffortMetadata() {
        let jsonl = """
        {"type":"assistant","message":{"model":"claude-opus-4-8","thinking":{"effort":"medium"},"usage":{"input_tokens":2,"cache_creation_input_tokens":762,"cache_read_input_tokens":81956}}}
        """
        let usage = TranscriptReader.lastUsage(path: writeTemp(jsonl))
        XCTAssertEqual(usage?.statsLabel, "Opus 4.8 Medium")
        let stats = TranscriptReader.lastRuntimeStats(path: writeTemp(jsonl))
        XCTAssertEqual(stats?.compactModelLabel, "Opus 4.8")
        XCTAssertEqual(stats?.compactDetailLabel, "Medium")
    }

    func testClaudeTokenProgressSumsAllUsageIncludingOutputTokens() {
        let jsonl = """
        {"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"input_tokens":5,"cache_read_input_tokens":1000,"cache_creation_input_tokens":10,"output_tokens":20}}}
        {"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"input_tokens":2,"cache_creation_input_tokens":762,"cache_read_input_tokens":81956,"output_tokens":418}}}
        """

        let progress = TranscriptReader.tokenProgress(path: writeTemp(jsonl), agentKind: .claude)
        XCTAssertEqual(progress?.totalTokens, 84_173)
    }

    func testCodexTokenProgressReadsLatestTokenCountTotal() {
        let jsonl = """
        {"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":12000},"model_context_window":100000}}}
        {"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":25000},"model_context_window":100000}}}
        """

        let progress = TranscriptReader.tokenProgress(path: writeTemp(jsonl), agentKind: .codex)
        XCTAssertEqual(progress?.totalTokens, 25_000)
    }

    func testTokenProgressNilForUnsupportedAgent() {
        let jsonl = #"{"type":"assistant","message":{"usage":{"input_tokens":3}}}"#
        XCTAssertNil(TranscriptReader.tokenProgress(path: writeTemp(jsonl), agentKind: .cursor))
    }

    func testLastUsageReadsCodexTokenCountContextWindow() {
        let jsonl = """
        {"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":25000},"model_context_window":100000},"rate_limits":{"primary":{"used_percent":10.0},"secondary":{"used_percent":20.0}}}}
        """

        let usage = TranscriptReader.lastUsage(path: writeTemp(jsonl))
        XCTAssertEqual(usage?.percentUsed, 25)
        XCTAssertEqual(usage?.percentLeft, 75)
    }

    func testLastQuotaUsageReadsCodexRateLimits() {
        let jsonl = """
        {"type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":10.0},"secondary":{"used_percent":20.0}}}}
        """

        let usage = TranscriptReader.lastQuotaUsage(path: writeTemp(jsonl))
        XCTAssertEqual(usage?.sessionUsedPercent, 10)
        XCTAssertEqual(usage?.weeklyUsedPercent, 20)
        XCTAssertEqual(AgentQuotaUsage.displayPercent(usedPercent: 10, mode: .left), 90)
    }

    func testLastRuntimeStatsFromLatestAssistantLine() {
        let jsonl = """
        {"type":"assistant","message":{"model":"claude-sonnet-4-6","usage":{"speed":"fast","service_tier":"standard"}}}
        {"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"speed":"standard","service_tier":"extra_credits"}}}
        """

        let stats = TranscriptReader.lastRuntimeStats(path: writeTemp(jsonl))
        XCTAssertEqual(stats?.model, "claude-opus-4-8")
        XCTAssertEqual(stats?.speed, "standard")
        XCTAssertEqual(stats?.serviceTier, "extra_credits")
        XCTAssertEqual(stats?.displayParts, ["opus-4-8", "speed standard", "tier extra_credits"])
        XCTAssertEqual(stats?.compactModelLabel, "Opus 4.8")
        XCTAssertEqual(stats?.compactModeLabel, "Standard")
        XCTAssertEqual(stats?.compactDetailLabel, "Extra Credits")
    }

    func testLastRuntimeStatsReadsCodexTurnContext() {
        let jsonl = """
        {"type":"turn_context","payload":{"model":"gpt-5.5","effort":"high","collaboration_mode":{"mode":"default","settings":{"model":"gpt-5.5","reasoning_effort":"high"}}}}
        """

        let stats = TranscriptReader.lastRuntimeStats(path: writeTemp(jsonl))
        XCTAssertEqual(stats?.model, "gpt-5.5")
        XCTAssertNil(stats?.speed)
        XCTAssertEqual(stats?.effort, "high")
        XCTAssertEqual(stats?.displayParts, ["5.5", "effort high"])
        XCTAssertEqual(stats?.compactModelLabel, "5.5")
        XCTAssertEqual(stats?.compactDetailLabel, "High")
        XCTAssertEqual(stats?.isFastLike, false)
    }

    func testLastRuntimeStatsDoesNotInferCodexFastMode() {
        let jsonl = """
        {"type":"turn_context","payload":{"model":"gpt-5.5","effort":"low","collaboration_mode":{"mode":"fast","settings":{"model":"gpt-5.5","reasoning_effort":"low"}}}}
        """

        let stats = TranscriptReader.lastRuntimeStats(path: writeTemp(jsonl))
        XCTAssertNil(stats?.speed)
        XCTAssertEqual(stats?.isFastLike, false)
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
