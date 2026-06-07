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
    public let modelName: String?
    public let effort: String?

    public init(usedTokens: Int, limitTokens: Int, modelName: String? = nil, effort: String? = nil) {
        self.usedTokens = usedTokens
        self.limitTokens = limitTokens
        self.modelName = modelName
        self.effort = effort
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

    /// Percentage of the context window already used, `0...100`.
    public var percentUsed: Int {
        max(0, min(100, 100 - percentLeft))
    }

    public var modelDisplayName: String? {
        Self.displayName(forModel: modelName)
    }

    public var effortDisplayName: String? {
        guard let effort = effort?.trimmingCharacters(in: .whitespacesAndNewlines),
              !effort.isEmpty else { return nil }
        return effort
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    public var statsLabel: String? {
        let parts = [modelDisplayName, effortDisplayName].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private static func displayName(forModel model: String?) -> String? {
        guard let model = model?.trimmingCharacters(in: .whitespacesAndNewlines),
              !model.isEmpty else { return nil }
        let parts = model.lowercased().split(separator: "-").map(String.init)
        guard let familyIndex = parts.firstIndex(where: { ["opus", "sonnet", "haiku"].contains($0) }) else {
            return model
        }

        let family = parts[familyIndex].prefix(1).uppercased() + parts[familyIndex].dropFirst()
        let afterFamily = parts[(familyIndex + 1)...]
            .prefix { $0.allSatisfy(\.isNumber) && $0.count <= 2 }
        let versionParts: ArraySlice<String>
        if afterFamily.isEmpty {
            versionParts = parts[..<familyIndex]
                .filter { $0 != "claude" && $0.allSatisfy(\.isNumber) && $0.count <= 2 }
                .suffix(2)
        } else {
            versionParts = afterFamily.prefix(2)
        }
        guard !versionParts.isEmpty else { return String(family) }
        return "\(family) \(versionParts.joined(separator: "."))"
    }
}

public enum UsageDisplayMode: String, Codable, Sendable, CaseIterable {
    case left
    case used
}

/// Agent quota/rate-limit percentages when an agent exposes them locally.
///
/// For Codex, `sessionUsedPercent` maps to the primary short-window limit and
/// `weeklyUsedPercent` maps to the secondary weekly window. Claude Code does
/// not currently expose equivalent quota telemetry in the local transcript.
public struct AgentQuotaUsage: Codable, Sendable, Equatable {
    public var sessionUsedPercent: Int?
    public var weeklyUsedPercent: Int?

    public init(sessionUsedPercent: Int? = nil, weeklyUsedPercent: Int? = nil) {
        self.sessionUsedPercent = Self.clamped(sessionUsedPercent)
        self.weeklyUsedPercent = Self.clamped(weeklyUsedPercent)
    }

    public var isEmpty: Bool {
        sessionUsedPercent == nil && weeklyUsedPercent == nil
    }

    public static func displayPercent(usedPercent: Int, mode: UsageDisplayMode) -> Int {
        switch mode {
        case .used: return usedPercent
        case .left: return max(0, min(100, 100 - usedPercent))
        }
    }

    private static func clamped(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return max(0, min(100, value))
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
