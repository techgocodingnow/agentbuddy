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
    public let toolInput: JSONValue?
    public let turnId: String?
    public let transcriptPath: String?
    public let mcpServerName: String?
    public let elicitationId: String?
    public let mode: String?
    public let url: String?
    public let requestedSchema: JSONValue?

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
        case toolInput = "tool_input"
        case turnId = "turn_id"
        case transcriptPath = "transcript_path"
        case mcpServerName = "mcp_server_name"
        case elicitationId = "elicitation_id"
        case mode
        case url
        case requestedSchema = "requested_schema"
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
        toolInput = try container.decodeIfPresent(JSONValue.self, forKey: .toolInput)
        turnId = try container.decodeIfPresent(String.self, forKey: .turnId)
        transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
        mcpServerName = try container.decodeIfPresent(String.self, forKey: .mcpServerName)
        elicitationId = try container.decodeIfPresent(String.self, forKey: .elicitationId)
        mode = try container.decodeIfPresent(String.self, forKey: .mode)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        requestedSchema = try container.decodeIfPresent(JSONValue.self, forKey: .requestedSchema)
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
        readTokenProgress: (String, AgentKind) -> TokenProgress? = { TranscriptReader.tokenProgress(path: $0, agentKind: $1) },
        readQuotaUsage: (String) -> AgentQuotaUsage? = { TranscriptReader.lastQuotaUsage(path: $0) },
        readStats: (String) -> AgentRuntimeStats? = { TranscriptReader.lastRuntimeStats(path: $0) },
        readSessionTitle: (String) -> String? = { TranscriptReader.indexedSessionTitle(sessionId: $0) },
        readTitle: (String) -> String? = { TranscriptReader.sessionTitle(path: $0) },
        pendingResponsePath: String? = nil
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
            tokenProgress: transcriptTokenProgress(kind: kind, readTokenProgress: readTokenProgress),
            quotaUsage: transcriptQuotaUsage(kind: kind, readQuotaUsage: readQuotaUsage),
            stats: transcriptStats(kind: kind, readStats: readStats),
            pendingRequest: pendingRequest(kind: kind, responsePath: pendingResponsePath)
        )
    }

    public var waitsForAgentBuddyResponse: Bool {
        hookEventName == "PermissionRequest" || hookEventName == "Elicitation"
    }

    public func hookOutput(for response: PendingAgentResponse, kind: AgentKind) -> Data? {
        guard let hookEventName else { return nil }
        switch hookEventName {
        case "PermissionRequest":
            return permissionOutput(for: response)
        case "Elicitation":
            return elicitationOutput(for: response)
        default:
            return nil
        }
    }

    private func permissionOutput(for response: PendingAgentResponse) -> Data? {
        let behavior: String
        switch response.action {
        case .allow, .apply, .continue:
            behavior = "allow"
        case .deny:
            behavior = "deny"
        case .review:
            return nil
        case .reply, .answer:
            behavior = response.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "allow" : "deny"
        }
        let message = response.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        var decision: [String: Any] = ["behavior": behavior]
        if behavior == "deny", let message, !message.isEmpty {
            decision["message"] = message
        }
        return encodeJSONObject([
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": decision
            ]
        ])
    }

    private func elicitationOutput(for response: PendingAgentResponse) -> Data? {
        switch response.action {
        case .answer, .reply, .continue:
            let text = response.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else { return nil }
            let key = requestedSchema?.firstObjectPropertyName() ?? "response"
            return encodeJSONObject([
                "hookSpecificOutput": [
                    "hookEventName": "Elicitation",
                    "action": "accept",
                    "content": [key: text]
                ]
            ])
        case .deny:
            return encodeJSONObject([
                "hookSpecificOutput": [
                    "hookEventName": "Elicitation",
                    "action": "decline",
                    "content": [:]
                ]
            ])
        case .review:
            return nil
        case .allow, .apply:
            return nil
        }
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

    private func transcriptTokenProgress(
        kind: AgentKind,
        readTokenProgress: (String, AgentKind) -> TokenProgress?
    ) -> TokenProgress? {
        guard (kind == .claude || kind == .codex), let transcriptPath else { return nil }
        return readTokenProgress(transcriptPath, kind)
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

    private func pendingRequest(kind: AgentKind, responsePath: String?) -> PendingAgentRequest? {
        guard let hookEventName else { return nil }
        switch hookEventName {
        case "PermissionRequest":
            let tool = toolName ?? "Tool"
            let actions = permissionActions(toolName: tool)
            let requestID = [sessionId, turnId, tool, responsePath].compactMap { $0 }.joined(separator: ":")
            return PendingAgentRequest(
                id: requestID.isEmpty ? UUID().uuidString : requestID,
                kind: .permission,
                actions: actions,
                prompt: toolInputSummary(toolName: tool),
                toolName: tool,
                toolInputSummary: toolInput?.compactSummary,
                responsePath: responsePath,
                turnId: turnId,
                transcriptPath: transcriptPath
            )
        case "Elicitation":
            let requestID = [sessionId, elicitationId, responsePath].compactMap { $0 }.joined(separator: ":")
            return PendingAgentRequest(
                id: requestID.isEmpty ? UUID().uuidString : requestID,
                kind: .elicitation,
                actions: [.answer, .deny, .review],
                prompt: message ?? url ?? "Agent needs input",
                toolName: mcpServerName,
                toolInputSummary: requestedSchema?.compactSummary,
                responsePath: responsePath,
                turnId: turnId,
                transcriptPath: transcriptPath
            )
        case "item/tool/requestUserInput":
            let requestID = [sessionId, turnId, responsePath].compactMap { $0 }.joined(separator: ":")
            return PendingAgentRequest(
                id: requestID.isEmpty ? UUID().uuidString : requestID,
                kind: .question,
                actions: [.answer, .review],
                prompt: message ?? toolInput?.compactSummary ?? "Codex needs input",
                toolName: toolName,
                toolInputSummary: toolInput?.compactSummary,
                responsePath: responsePath,
                turnId: turnId,
                transcriptPath: transcriptPath
            )
        case "Notification":
            return PendingAgentRequest(
                id: sessionId ?? UUID().uuidString,
                kind: .question,
                actions: [.reply],
                prompt: message,
                responsePath: responsePath,
                transcriptPath: transcriptPath
            )
        default:
            return nil
        }
    }

    private func permissionActions(toolName: String) -> [AgentSessionAction] {
        if toolName == "apply_patch" || toolName == "Edit" || toolName == "Write" {
            return [.apply, .review, .deny]
        }
        return [.allow, .deny, .review]
    }

    private func toolInputSummary(toolName: String) -> String? {
        guard let summary = toolInput?.compactSummary, !summary.isEmpty else {
            return "\(toolName) needs approval"
        }
        return summary
    }

    private func encodeJSONObject(_ object: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: object, options: [])
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
