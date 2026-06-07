import Foundation

/// Extracts the agent's final assistant text from a Claude Code transcript.
///
/// Claude Code appends one JSON object per line (JSONL) to `transcript_path`.
/// On a terminal hook (`Stop`/`SubagentStop`) we read the tail of that file and
/// return the last assistant message's text, so the pet can show what the agent
/// actually said rather than a generic "done".
///
/// Only the file tail is read: transcripts grow without bound, but the final
/// assistant message is always near the end, so loading the whole file in the
/// short-lived hook process would be wasteful.
public enum TranscriptReader {
    /// How many trailing bytes to scan. Comfortably larger than any single
    /// assistant message, small enough to read instantly.
    static let maxReadBytes = 256 * 1024
    /// How many leading bytes to scan for an exact transcript title or first
    /// meaningful user request. Some agents prepend bootstrap context, so this
    /// is larger than the tail read while still bounded.
    static let maxTitleReadBytes = 1024 * 1024
    /// Max bytes to scan from Codex's local session index. The newest entries
    /// live near the end, and the exact sidebar title is stored there.
    static let maxIndexReadBytes = 2 * 1024 * 1024
    /// Cap on the surfaced text; the UI truncates visually too, but a hard cap
    /// keeps notifications and clipboard context sane.
    static let maxMessageLength = 200

    /// The last assistant message's text in the transcript at `path`, or `nil`
    /// if the file is missing/unreadable or has no assistant text yet.
    public static func lastAssistantText(path: String) -> String? {
        guard let data = tailData(path: path) else { return nil }
        return lastAssistantText(in: data)
    }

    /// The context usage from the last assistant message in the transcript at
    /// `path`, or `nil` if the file is missing/unreadable or carries no usage.
    public static func lastUsage(path: String) -> ContextUsage? {
        guard let data = tailData(path: path) else { return nil }
        return lastUsage(in: data)
    }

    /// Agent quota/rate-limit usage from the latest token-count event.
    public static func lastQuotaUsage(path: String) -> AgentQuotaUsage? {
        guard let data = tailData(path: path) else { return nil }
        return lastQuotaUsage(in: data)
    }

    /// Runtime metadata from the latest assistant message in the transcript at
    /// `path`, or `nil` if none is present.
    public static func lastRuntimeStats(path: String) -> AgentRuntimeStats? {
        guard let data = tailData(path: path) else { return nil }
        return lastRuntimeStats(in: data)
    }

    /// A title from the transcript at `path`. Claude Code records an exact
    /// `ai-title`; otherwise we derive a compact fallback from the first
    /// meaningful user request.
    public static func sessionTitle(path: String) -> String? {
        guard let data = headData(path: path) else { return nil }
        return sessionTitle(in: data)
    }

    /// The exact Codex sidebar title for `sessionId`, if Codex has written it to
    /// its local session index.
    public static func indexedSessionTitle(sessionId: String) -> String? {
        indexedSessionTitle(sessionId: sessionId, indexPath: defaultCodexSessionIndexPath())
    }

    static func indexedSessionTitle(sessionId: String, indexPath: String) -> String? {
        guard let data = tailBoundedData(path: indexPath, maxBytes: maxIndexReadBytes) else { return nil }
        return indexedSessionTitle(sessionId: sessionId, in: data)
    }

    static func headData(path: String) -> Data? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        return handle.readData(ofLength: maxTitleReadBytes)
    }

    static func tailData(path: String) -> Data? {
        tailBoundedData(path: path, maxBytes: maxReadBytes)
    }

    static func tailBoundedData(path: String, maxBytes: Int) -> Data? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let end = handle.seekToEndOfFile()
        let start = end > UInt64(maxBytes) ? end - UInt64(maxBytes) : 0
        handle.seek(toFileOffset: start)
        return handle.readDataToEndOfFile()
    }

    static func lastAssistantText(in data: Data) -> String? {
        // Walk lines bottom-up; the first decodable assistant line is the latest.
        // A partial leading line (from the tail cut) simply fails to decode.
        for line in data.split(separator: 0x0A, omittingEmptySubsequences: true).reversed() {
            if let text = assistantText(fromLine: Data(line)) { return truncate(text) }
        }
        return nil
    }

    static func sessionTitle(in data: Data) -> String? {
        if let title = aiTitle(in: data) {
            return title
        }

        // Walk forward: session titles should follow the first real user ask,
        // not later follow-up turns or injected bootstrap context.
        for line in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
            guard let text = userText(fromLine: Data(line)),
                  let candidate = titleCandidate(from: text),
                  let title = TaskSummary.compact(from: candidate) else { continue }
            return title
        }
        return nil
    }

    static func aiTitle(in data: Data) -> String? {
        // Claude Code may repeat ai-title records as the transcript grows.
        // Newest wins if several are present in the scanned window.
        for line in data.split(separator: 0x0A, omittingEmptySubsequences: true).reversed() {
            guard let entry = try? JSONDecoder().decode(Line.self, from: Data(line)),
                  entry.type == "ai-title",
                  let title = cleanedTitle(entry.aiTitle) else { continue }
            return title
        }
        return nil
    }

    static func indexedSessionTitle(sessionId: String, in data: Data) -> String? {
        // Walk newest-first in case the index ever contains repeated ids.
        for line in data.split(separator: 0x0A, omittingEmptySubsequences: true).reversed() {
            guard let entry = try? JSONDecoder().decode(IndexLine.self, from: Data(line)),
                  entry.id == sessionId,
                  let title = cleanedTitle(entry.thread_name) else { continue }
            return title
        }
        return nil
    }

    static func lastUsage(in data: Data) -> ContextUsage? {
        // Walk lines bottom-up; the first assistant line carrying usage is the
        // latest turn. A partial leading line (from the tail cut) fails to decode.
        for line in data.split(separator: 0x0A, omittingEmptySubsequences: true).reversed() {
            if let usage = usage(fromLine: Data(line)) { return usage }
        }
        return nil
    }

    static func lastQuotaUsage(in data: Data) -> AgentQuotaUsage? {
        for line in data.split(separator: 0x0A, omittingEmptySubsequences: true).reversed() {
            if let usage = quotaUsage(fromLine: Data(line)) { return usage }
        }
        return nil
    }

    static func lastRuntimeStats(in data: Data) -> AgentRuntimeStats? {
        for line in data.split(separator: 0x0A, omittingEmptySubsequences: true).reversed() {
            if let stats = runtimeStats(fromLine: Data(line)) { return stats }
        }
        return nil
    }

    private static func codexUsage(from line: Line) -> ContextUsage? {
        guard line.type == "event_msg",
              line.payload?.type == "token_count",
              let info = line.payload?.info,
              let totalTokens = info.total_token_usage?.total_tokens,
              let window = info.model_context_window,
              window > 0 else { return nil }
        return ContextUsage(usedTokens: totalTokens, limitTokens: window)
    }

    private static func quotaUsage(fromLine data: Data) -> AgentQuotaUsage? {
        guard let line = try? JSONDecoder().decode(Line.self, from: data),
              line.type == "event_msg",
              line.payload?.type == "token_count",
              let rateLimits = line.payload?.rate_limits else { return nil }
        let usage = AgentQuotaUsage(
            sessionUsedPercent: rateLimits.primary?.usedPercentInt,
            weeklyUsedPercent: rateLimits.secondary?.usedPercentInt
        )
        return usage.isEmpty ? nil : usage
    }

    private static func usage(fromLine data: Data) -> ContextUsage? {
        guard let line = try? JSONDecoder().decode(Line.self, from: data) else { return nil }
        if let codex = codexUsage(from: line) { return codex }
        guard line.type == "assistant",
              let message = line.message,
              let usage = message.usage else { return nil }
        let used = usage.input_tokens
            + usage.cache_read_input_tokens
            + usage.cache_creation_input_tokens
        let limit = ContextWindow.limit(forModel: message.model)
        return ContextUsage(
            usedTokens: used,
            limitTokens: limit,
            modelName: message.model,
            effort: message.effortLabel
        )
    }

    private static func runtimeStats(fromLine data: Data) -> AgentRuntimeStats? {
        guard let line = try? JSONDecoder().decode(Line.self, from: data) else { return nil }
        if let stats = codexRuntimeStats(from: line) { return stats }
        guard line.type == "assistant",
              let message = line.message else { return nil }
        let stats = AgentRuntimeStats(
            model: message.model,
            speed: message.usage?.speed,
            serviceTier: message.usage?.service_tier,
            effort: message.usage?.effort ?? message.effortLabel
        )
        return stats.isEmpty ? nil : stats
    }

    private static func codexRuntimeStats(from line: Line) -> AgentRuntimeStats? {
        guard line.type == "turn_context",
              let payload = line.payload else { return nil }
        let model = payload.model ?? payload.collaboration_mode?.settings?.model
        let effort = payload.effort ?? payload.collaboration_mode?.settings?.reasoning_effort
        let stats = AgentRuntimeStats(
            model: model,
            effort: effort
        )
        return stats.isEmpty ? nil : stats
    }

    private static func assistantText(fromLine data: Data) -> String? {
        guard let line = try? JSONDecoder().decode(Line.self, from: data),
              let text = assistantText(from: line) else { return nil }
        return text
    }

    private static func userText(fromLine data: Data) -> String? {
        guard let line = try? JSONDecoder().decode(Line.self, from: data) else { return nil }
        return userText(from: line)
    }

    private static func assistantText(from line: Line) -> String? {
        if line.type == "assistant", let blocks = line.message?.content {
            return joinedText(blocks)
        }

        // Codex Desktop/CLI session JSONL stores assistant output as response
        // items, while commentary/final events also appear as agent_message
        // payloads. Support both so Codex Stop hooks can surface the real reply.
        if line.type == "response_item",
           line.payload?.type == "message",
           line.payload?.role == "assistant",
           let blocks = line.payload?.content {
            return joinedText(blocks)
        }

        if line.type == "event_msg",
           line.payload?.type == "agent_message",
           let text = line.payload?.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }

        return nil
    }

    private static func userText(from line: Line) -> String? {
        if line.type == "user", let blocks = line.message?.content {
            return joinedText(blocks, acceptedTypes: ["text"])
        }

        if line.type == "response_item",
           line.payload?.type == "message",
           line.payload?.role == "user",
           let blocks = line.payload?.content {
            return joinedText(blocks, acceptedTypes: ["input_text", "text"])
        }

        return nil
    }

    private static func joinedText(_ blocks: [Block]) -> String? {
        joinedText(blocks, acceptedTypes: ["text", "output_text"])
    }

    private static func joinedText(_ blocks: [Block], acceptedTypes: Set<String>) -> String? {
        let text = blocks
            .compactMap { block -> String? in
                guard let type = block.type, acceptedTypes.contains(type) else { return nil }
                return block.text
            }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func titleCandidate(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !looksLikeInjectedContext(trimmed) else { return nil }

        let lines = trimmed
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let idea = prefixedLine(in: lines, prefix: "Idea:") {
            return idea
        }

        if let request = prefixedLine(in: lines, prefix: "My request for Codex:") {
            return request
        }

        return lines.first { !looksLikeAttachmentMetadata($0) && !$0.hasPrefix("#") }
    }

    private static func prefixedLine(in lines: [String], prefix: String) -> String? {
        for (index, line) in lines.enumerated() {
            if line.localizedCaseInsensitiveCompare(prefix) == .orderedSame {
                return lines.dropFirst(index + 1)
                    .first { !looksLikeAttachmentMetadata($0) && !$0.hasPrefix("#") }
            }

            guard line.lowercased().hasPrefix(prefix.lowercased()) else { continue }
            let value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }
        return nil
    }

    private static func looksLikeInjectedContext(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.hasPrefix("# agents.md instructions") { return true }
        if lower.hasPrefix("<environment_context>") { return true }
        if lower.contains("<environment_context>") { return true }
        if lower.contains("<instructions>") { return true }
        if lower.contains("<app-context>") { return true }
        if lower.contains("<skills_instructions>") { return true }
        return text.count > 20_000
    }

    private static func looksLikeAttachmentMetadata(_ line: String) -> Bool {
        line.hasPrefix("<image ")
            || line.hasPrefix("</image>")
            || line.hasPrefix("## ")
            || line.hasPrefix("# Files mentioned")
    }

    private static func cleanedTitle(_ text: String?) -> String? {
        guard let title = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return nil }
        return title
    }

    private static func defaultCodexSessionIndexPath() -> String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/session_index.jsonl")
            .path
    }

    private static func truncate(_ text: String) -> String {
        let collapsed = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        guard collapsed.count > maxMessageLength else { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: maxMessageLength)
        return collapsed[..<end].trimmingCharacters(in: .whitespaces) + "…"
    }

    // Minimal projection of a transcript line; unknown keys are ignored.
    private struct Line: Decodable {
        let type: String?
        let aiTitle: String?
        let message: Message?
        let payload: Payload?
    }
    private struct Message: Decodable {
        let content: [Block]?
        let model: String?
        let usage: Usage?
        let effort: String?
        let reasoningEffort: String?
        let thinkingEffort: String?
        let thinking: Thinking?

        enum CodingKeys: String, CodingKey {
            case content, model, usage, effort, thinking
            case reasoningEffort = "reasoning_effort"
            case thinkingEffort = "thinking_effort"
        }

        var effortLabel: String? {
            effort ?? reasoningEffort ?? thinkingEffort ?? thinking?.effort
        }
    }
    private struct Payload: Decodable {
        let type: String?
        let role: String?
        let content: [Block]?
        let message: String?
        let model: String?
        let effort: String?
        let collaboration_mode: CollaborationMode?
        let info: TokenCountInfo?
        let rate_limits: RateLimits?
    }
    private struct CollaborationMode: Decodable {
        let mode: String?
        let settings: CollaborationSettings?
    }
    private struct CollaborationSettings: Decodable {
        let model: String?
        let reasoning_effort: String?
    }
    private struct TokenCountInfo: Decodable {
        let total_token_usage: TokenUsage?
        let model_context_window: Int?
    }
    private struct TokenUsage: Decodable {
        let total_tokens: Int?
    }
    private struct RateLimits: Decodable {
        let primary: RateLimitWindow?
        let secondary: RateLimitWindow?
    }
    private struct RateLimitWindow: Decodable {
        let used_percent: Double?

        var usedPercentInt: Int? {
            guard let used_percent else { return nil }
            return max(0, min(100, Int(used_percent.rounded())))
        }
    }
    private struct IndexLine: Decodable {
        let id: String?
        let thread_name: String?
    }
    private struct Block: Decodable {
        let type: String?
        let text: String?
    }
    private struct Thinking: Decodable {
        let effort: String?
    }
    // Token counts Claude Code records per assistant message. Missing keys
    // default to 0 so an older/partial transcript still yields a usable total.
    private struct Usage: Decodable {
        let input_tokens: Int
        let cache_read_input_tokens: Int
        let cache_creation_input_tokens: Int
        let speed: String?
        let service_tier: String?
        let effort: String?

        enum CodingKeys: String, CodingKey {
            case input_tokens, cache_read_input_tokens, cache_creation_input_tokens
            case speed, service_tier, effort
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            input_tokens = try c.decodeIfPresent(Int.self, forKey: .input_tokens) ?? 0
            cache_read_input_tokens = try c.decodeIfPresent(Int.self, forKey: .cache_read_input_tokens) ?? 0
            cache_creation_input_tokens = try c.decodeIfPresent(Int.self, forKey: .cache_creation_input_tokens) ?? 0
            speed = try c.decodeIfPresent(String.self, forKey: .speed)
            service_tier = try c.decodeIfPresent(String.self, forKey: .service_tier)
            effort = try c.decodeIfPresent(String.self, forKey: .effort)
        }
    }
}
