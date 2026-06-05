import Foundation

/// The JSON Claude Code writes to a hook's stdin. Only the fields AgentBuddy
/// needs are decoded; the rest are ignored.
public struct ClaudeHookPayload: Decodable, Equatable {
    public let sessionId: String?
    public let cwd: String?
    public let hookEventName: String?
    public let title: String?
    public let message: String?
    public let prompt: String?
    public let toolName: String?
    public let transcriptPath: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case hookEventName = "hook_event_name"
        case title
        case sessionTitle = "session_title"
        case conversationTitle = "conversation_title"
        case threadTitle = "thread_title"
        case prompt
        case message
        case toolName = "tool_name"
        case transcriptPath = "transcript_path"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
        hookEventName = try container.decodeIfPresent(String.self, forKey: .hookEventName)
        title = try container.decodeFirstString(forKeys: [.title, .sessionTitle, .conversationTitle, .threadTitle])
        message = try container.decodeIfPresent(String.self, forKey: .message)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
    }

    /// Hook events whose transcript is likely to contain fresh assistant text.
    /// Avoid `UserPromptSubmit`: at that point the latest assistant text may
    /// still be from the previous turn.
    private static let transcriptEvents: Set<String> = ["PreToolUse", "PostToolUse", "Stop", "SubagentStop"]

    public static func decode(from data: Data) -> ClaudeHookPayload? {
        try? JSONDecoder().decode(ClaudeHookPayload.self, from: data)
    }

    /// Builds an `AgentEvent` from the payload, or `nil` if the essential
    /// fields (session id and event name) are missing.
    ///
    /// `readTranscript` is the seam that syncs the agent's latest message from
    /// a local transcript path. AgentBuddy never calls an LLM here; tests inject
    /// this dependency to keep the function pure.
    public func makeEvent(
        now: Date,
        kind: AgentKind = .claude,
        readTranscript: (String) -> String? = { TranscriptReader.lastAssistantText(path: $0) },
        readUsage: (String) -> ContextUsage? = { TranscriptReader.lastUsage(path: $0) },
        readQuotaUsage: (String) -> AgentQuotaUsage? = { TranscriptReader.lastQuotaUsage(path: $0) },
        readStats: (String) -> AgentRuntimeStats? = { TranscriptReader.lastRuntimeStats(path: $0) },
        readSessionTitle: (String) -> String? = { TranscriptReader.indexedSessionTitle(sessionId: $0) },
        readTitle: (String) -> String? = { TranscriptReader.sessionTitle(path: $0) }
    ) -> AgentEvent? {
        guard let sessionId, let hookEventName else { return nil }
        // Prefer an explicit hook message, then the agent's transcript text on
        // events where the transcript is fresh. The user prompt seeds the title
        // only, not the pet's spoken message.
        let resolvedTitle = title
            ?? TaskSummary.compact(from: prompt)
            ?? readSessionTitle(sessionId)
            ?? transcriptTitle(readTitle: readTitle)
        let context = message
            ?? transcriptMessage(for: hookEventName, kind: kind, readTranscript: readTranscript)
        return AgentEvent(
            sessionId: sessionId, agentKind: kind, eventName: hookEventName,
            project: cwd, title: resolvedTitle, message: context, timestamp: now,
            usage: transcriptUsage(kind: kind, readUsage: readUsage),
            quotaUsage: transcriptQuotaUsage(kind: kind, readQuotaUsage: readQuotaUsage),
            stats: transcriptStats(kind: kind, readStats: readStats)
        )
    }

    /// Context usage from the transcript, read on every Claude event (not just
    /// terminal ones) so the usage indicator tracks the live context size.
    private func transcriptUsage(
        kind: AgentKind,
        readUsage: (String) -> ContextUsage?
    ) -> ContextUsage? {
        guard (kind == .claude || kind == .codex), let transcriptPath else { return nil }
        return readUsage(transcriptPath)
    }

    private func transcriptQuotaUsage(
        kind: AgentKind,
        readQuotaUsage: (String) -> AgentQuotaUsage?
    ) -> AgentQuotaUsage? {
        guard kind == .codex, let transcriptPath else { return nil }
        return readQuotaUsage(transcriptPath)
    }

    private func transcriptStats(
        kind: AgentKind,
        readStats: (String) -> AgentRuntimeStats?
    ) -> AgentRuntimeStats? {
        guard (kind == .claude || kind == .codex), let transcriptPath else { return nil }
        return readStats(transcriptPath)
    }

    private func transcriptTitle(
        readTitle: (String) -> String?
    ) -> String? {
        guard let transcriptPath else { return nil }
        return readTitle(transcriptPath)
    }

    private func transcriptMessage(
        for eventName: String,
        kind: AgentKind,
        readTranscript: (String) -> String?
    ) -> String? {
        guard Self.transcriptEvents.contains(eventName),
              let transcriptPath else { return nil }
        return readTranscript(transcriptPath)
    }
}

private extension KeyedDecodingContainer where K == ClaudeHookPayload.CodingKeys {
    func decodeFirstString(forKeys keys: [K]) throws -> String? {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key) {
                return value
            }
        }
        return nil
    }
}
