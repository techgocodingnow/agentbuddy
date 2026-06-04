import Foundation

/// Compact, UI-safe status text for a group of active agent sessions.
public enum AgentSessionSummary {
    private static let activeStateOrder: [AgentState] = [.waiting, .working, .done]

    public static func compact(for sessions: [AgentSession], detailLimit: Int = 2) -> String? {
        let active = sessions.filter { activeStateOrder.contains($0.state) }
        guard !active.isEmpty else { return nil }

        let clampedDetailLimit = max(1, detailLimit)
        if active.count <= clampedDetailLimit {
            return active
                .sorted(by: sortForSummary)
                .map { "\($0.agentKind.displayName) \($0.state.rawValue)" }
                .joined(separator: " - ")
        }

        let groups = activeStateOrder.compactMap { state -> String? in
            let count = active.count { $0.state == state }
            guard count > 0 else { return nil }
            return "\(count) \(state.rawValue)"
        }

        return groups.joined(separator: " - ")
    }

    private static func sortForSummary(_ lhs: AgentSession, _ rhs: AgentSession) -> Bool {
        let lp = lhs.state.attentionPriority
        let rp = rhs.state.attentionPriority
        if lp != rp { return lp > rp }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        if lhs.agentKind.displayName != rhs.agentKind.displayName {
            return lhs.agentKind.displayName < rhs.agentKind.displayName
        }
        return lhs.id < rhs.id
    }
}

public extension AgentKind {
    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        case .cursor: return "Cursor"
        case .opencode: return "OpenCode"
        case .windsurf: return "Windsurf"
        case .cli: return "CLI"
        case .unknown: return "Agent"
        }
    }
}
