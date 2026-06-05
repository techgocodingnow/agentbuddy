import Foundation

/// How full an agent's context window is, derived from its transcript.
///
/// `usedTokens` is the live size of the latest assistant turn's context
/// (prompt + cached input); `limitTokens` is the model's context window. Only
/// Claude Code reports the token counts AgentBuddy needs, so other agents leave
/// this `nil` and the UI shows no usage indicator for them.
public struct ContextUsage: Codable, Sendable, Equatable {
    public let usedTokens: Int
    public let limitTokens: Int

    public init(usedTokens: Int, limitTokens: Int) {
        self.usedTokens = usedTokens
        self.limitTokens = limitTokens
    }

    /// Percentage of the context window still free, `0...100`.
    ///
    /// Clamped: context can momentarily exceed the window just before Claude
    /// auto-compacts, which would otherwise yield a negative value.
    public var percentLeft: Int {
        guard limitTokens > 0 else { return 0 }
        let left = Double(max(0, limitTokens - usedTokens)) / Double(limitTokens)
        return Int((left * 100).rounded())
    }
}

/// Maps a model name to its context-window size.
public enum ContextWindow {
    /// Current Claude models expose a 200K-token window.
    public static let defaultLimit = 200_000

    /// The window for `model`, defaulting to 200K.
    ///
    /// The 1M-token window is a request-header beta that is not reflected in the
    /// model name written to the transcript, so we cannot detect it here and
    /// fall back to the standard window.
    public static func limit(forModel model: String?) -> Int {
        defaultLimit
    }
}
