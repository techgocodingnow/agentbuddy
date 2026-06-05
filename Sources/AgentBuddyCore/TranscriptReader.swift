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

    static func tailData(path: String) -> Data? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let end = handle.seekToEndOfFile()
        let start = end > UInt64(maxReadBytes) ? end - UInt64(maxReadBytes) : 0
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

    static func lastUsage(in data: Data) -> ContextUsage? {
        // Walk lines bottom-up; the first assistant line carrying usage is the
        // latest turn. A partial leading line (from the tail cut) fails to decode.
        for line in data.split(separator: 0x0A, omittingEmptySubsequences: true).reversed() {
            if let usage = usage(fromLine: Data(line)) { return usage }
        }
        return nil
    }

    private static func usage(fromLine data: Data) -> ContextUsage? {
        guard let line = try? JSONDecoder().decode(Line.self, from: data),
              line.type == "assistant",
              let message = line.message,
              let usage = message.usage else { return nil }
        // The live context size is what the next turn will re-send: the prompt
        // plus cached input. Output tokens of this turn become input next turn,
        // but are not part of the context window measured here (matching /context).
        let used = usage.input_tokens
            + usage.cache_read_input_tokens
            + usage.cache_creation_input_tokens
        let limit = ContextWindow.limit(forModel: message.model)
        return ContextUsage(usedTokens: used, limitTokens: limit)
    }

    private static func assistantText(fromLine data: Data) -> String? {
        guard let line = try? JSONDecoder().decode(Line.self, from: data),
              line.type == "assistant",
              let blocks = line.message?.content else { return nil }
        let text = blocks
            .compactMap { $0.type == "text" ? $0.text : nil }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
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
        let message: Message?
    }
    private struct Message: Decodable {
        let content: [Block]?
        let model: String?
        let usage: Usage?
    }
    private struct Block: Decodable {
        let type: String?
        let text: String?
    }
    // Token counts Claude Code records per assistant message. Missing keys
    // default to 0 so an older/partial transcript still yields a usable total.
    private struct Usage: Decodable {
        let input_tokens: Int
        let cache_read_input_tokens: Int
        let cache_creation_input_tokens: Int

        enum CodingKeys: String, CodingKey {
            case input_tokens, cache_read_input_tokens, cache_creation_input_tokens
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            input_tokens = try c.decodeIfPresent(Int.self, forKey: .input_tokens) ?? 0
            cache_read_input_tokens = try c.decodeIfPresent(Int.self, forKey: .cache_read_input_tokens) ?? 0
            cache_creation_input_tokens = try c.decodeIfPresent(Int.self, forKey: .cache_creation_input_tokens) ?? 0
        }
    }
}
