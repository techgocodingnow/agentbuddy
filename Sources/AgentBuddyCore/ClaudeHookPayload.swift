import Foundation

/// The JSON Claude Code writes to a hook's stdin. Only the fields AgentBuddy
/// needs are decoded; the rest are ignored.
public struct ClaudeHookPayload: Decodable, Equatable {
    public let sessionId: String?
    public let cwd: String?
    public let hookEventName: String?
    public let message: String?
    public let toolName: String?
    public let transcriptPath: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case hookEventName = "hook_event_name"
        case message
        case toolName = "tool_name"
        case transcriptPath = "transcript_path"
    }

    /// Terminal events whose final assistant message is worth surfacing.
    private static let transcriptEvents: Set<String> = ["Stop", "SubagentStop"]

    public static func decode(from data: Data) -> ClaudeHookPayload? {
        try? JSONDecoder().decode(ClaudeHookPayload.self, from: data)
    }

    /// Builds an `AgentEvent` from the payload, or `nil` if the essential
    /// fields (session id and event name) are missing.
    ///
    /// `readTranscript` is the seam that resolves the agent's final message from
    /// a transcript path; it defaults to the real reader and is injected in tests
    /// to keep this function pure.
    public func makeEvent(
        now: Date,
        kind: AgentKind = .claude,
        readTranscript: (String) -> String? = { TranscriptReader.lastAssistantText(path: $0) },
        readUsage: (String) -> ContextUsage? = { TranscriptReader.lastUsage(path: $0) }
    ) -> AgentEvent? {
        guard let sessionId, let hookEventName else { return nil }
        // Prefer an explicit message; then the agent's final assistant text on a
        // terminal event. Tool names are telemetry, not user-facing agent text.
        let context = message
            ?? transcriptMessage(for: hookEventName, kind: kind, readTranscript: readTranscript)
        return AgentEvent(
            sessionId: sessionId, agentKind: kind, eventName: hookEventName,
            project: cwd, message: context, timestamp: now,
            usage: transcriptUsage(kind: kind, readUsage: readUsage)
        )
    }

    /// Context usage from the transcript, read on every Claude event (not just
    /// terminal ones) so the usage indicator tracks the live context size.
    private func transcriptUsage(
        kind: AgentKind,
        readUsage: (String) -> ContextUsage?
    ) -> ContextUsage? {
        guard kind == .claude, let transcriptPath else { return nil }
        return readUsage(transcriptPath)
    }

    private func transcriptMessage(
        for eventName: String,
        kind: AgentKind,
        readTranscript: (String) -> String?
    ) -> String? {
        guard kind == .claude,
              Self.transcriptEvents.contains(eventName),
              let transcriptPath else { return nil }
        return readTranscript(transcriptPath)
    }
}
