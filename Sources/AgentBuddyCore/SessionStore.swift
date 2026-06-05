import Foundation

/// In-memory store of agent sessions.
///
/// Pure logic, deliberately not thread-safe and free of wall-clock reads:
/// callers pass `now` so behaviour is deterministic and testable. The daemon
/// confines all access to a single queue (see issue #3).
public final class SessionStore {
    /// `done` sessions fall back to `idle` after this much quiet time.
    public var doneToIdleAfter: TimeInterval
    /// `idle` sessions are removed after this much quiet time.
    public var removeIdleAfter: TimeInterval
    /// Working/waiting sessions with no update for this long are removed: the
    /// agent almost certainly died without a `Stop` event.
    public var staleActiveAfter: TimeInterval
    /// A merely `registered` session (agent open but never started working) is
    /// dropped sooner: it reappears as `working` the moment the agent does
    /// anything, so a quiet/abandoned one shouldn't linger as "running".
    public var staleRegisteredAfter: TimeInterval

    private var byID: [String: AgentSession] = [:]

    public init(doneToIdleAfter: TimeInterval = 30,
                removeIdleAfter: TimeInterval = 600,
                staleActiveAfter: TimeInterval = 300,
                staleRegisteredAfter: TimeInterval = 90) {
        self.doneToIdleAfter = doneToIdleAfter
        self.removeIdleAfter = removeIdleAfter
        self.staleActiveAfter = staleActiveAfter
        self.staleRegisteredAfter = staleRegisteredAfter
    }

    /// Removes all sessions (e.g. after the user disconnects an integration).
    public func clear() {
        byID.removeAll()
    }

    /// Removes a single session (e.g. dismissing a stuck agent).
    public func remove(id: String) {
        byID.removeValue(forKey: id)
    }

    /// Optimistically clears a hook request after AgentBuddy has written the
    /// response file, before the agent emits its next working event.
    @discardableResult
    public func resolvePendingRequest(id: String, now: Date) -> AgentSession? {
        guard var existing = byID[id], existing.pendingRequest != nil else {
            return nil
        }
        let stateChanged = existing.state != .working
        if stateChanged {
            existing.stateSince = now
            existing.message = nil
        }
        existing.state = .working
        existing.updatedAt = now
        existing.pendingRequest = nil
        byID[id] = existing
        return existing
    }

    /// Applies an event, creating or updating the matching session.
    /// Returns the updated session, or `nil` if the event maps to no state.
    @discardableResult
    public func apply(_ event: AgentEvent, now: Date) -> AgentSession? {
        // A session-end event (agent quit/closed) removes the session at once,
        // so it doesn't linger as "done" until the idle timeout.
        if StateMapper.isSessionEnd(for: event.agentKind, eventName: event.eventName) {
            byID.removeValue(forKey: event.sessionId)
            return nil
        }
        guard let state = StateMapper.state(for: event.agentKind, eventName: event.eventName) else {
            return nil
        }
        if var existing = byID[event.sessionId] {
            let stateChanged = existing.state != state
            if stateChanged { existing.stateSince = now }
            existing.state = state
            existing.updatedAt = now
            // Keep the last known usage when an event carries none (e.g. a
            // non-Claude event), so the indicator doesn't blink away.
            if let usage = event.usage { existing.usage = usage }
            if let quotaUsage = event.quotaUsage { existing.quotaUsage = quotaUsage }
            if let stats = event.stats { existing.stats = stats }
            existing.pendingRequest = event.pendingRequest
            if state != .waiting {
                existing.pendingRequest = nil
            }
            if let project = event.project { existing.project = project }
            let eventTitle = cleaned(event.title)
            if let eventTitle {
                existing.title = eventTitle
            } else if existing.title == nil {
                existing.title = inferredTitle(from: event.message, state: state)
            }
            if let message = event.message {
                existing.message = message
            } else if stateChanged {
                existing.message = nil
                if state == .registered || state == .idle {
                    if eventTitle == nil {
                        existing.title = nil
                    }
                }
            }
            byID[event.sessionId] = existing
            return existing
        }
        let session = AgentSession(
            id: event.sessionId,
            agentKind: event.agentKind,
            project: event.project,
            title: cleaned(event.title) ?? inferredTitle(from: event.message, state: state),
            state: state,
            message: event.message,
            source: .hook,
            updatedAt: now,
            usage: event.usage,
            quotaUsage: event.quotaUsage,
            stats: event.stats,
            pendingRequest: state == .waiting ? event.pendingRequest : nil
        )
        byID[event.sessionId] = session
        return session
    }

    /// Demotes stale `done` sessions to `idle`, removes long-idle ones, and
    /// drops active sessions that have gone quiet (agent died without `Stop`).
    public func prune(now: Date) {
        for id in Array(byID.keys) {
            guard let session = byID[id] else { continue }
            let quiet = now.timeIntervalSince(session.updatedAt)
            switch session.state {
            case .done:
                if quiet >= doneToIdleAfter {
                    var s = session
                    s.state = .idle
                    s.updatedAt = now
                    s.stateSince = now
                    byID[id] = s
                }
            case .idle:
                if quiet >= removeIdleAfter {
                    byID.removeValue(forKey: id)
                }
            case .registered:
                if quiet >= staleRegisteredAfter {
                    byID.removeValue(forKey: id)
                }
            case .working, .waiting:
                if quiet >= staleActiveAfter {
                    byID.removeValue(forKey: id)
                }
            }
        }
    }

    public var sessions: [AgentSession] {
        Array(byID.values)
    }

    /// Sessions ordered by attention priority then recency, for display.
    public var sorted: [AgentSession] {
        byID.values.sorted { lhs, rhs in
            let lp = lhs.state.attentionPriority
            let rp = rhs.state.attentionPriority
            if lp != rp { return lp > rp }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    public func session(id: String) -> AgentSession? {
        byID[id]
    }

    private func cleaned(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    private func inferredTitle(from message: String?, state: AgentState) -> String? {
        guard state == .working else { return nil }
        return TaskSummary.compact(from: message)
    }
}

extension AgentState {
    /// Higher means more deserving of the user's attention.
    var attentionPriority: Int {
        switch self {
        case .waiting: return 4
        case .working: return 3
        case .done: return 2
        case .registered: return 1
        case .idle: return 0
        }
    }
}
