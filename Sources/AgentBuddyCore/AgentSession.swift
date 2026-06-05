import Foundation

/// Current known state of one agent session.
public struct AgentSession: Identifiable, Sendable, Equatable {
    public let id: String
    public var agentKind: AgentKind
    public var project: String?
    public var state: AgentState
    public var message: String?
    public var taskSummary: String?
    public var source: AgentSource
    public var updatedAt: Date
    /// When the session entered its current `state`; resets on state change.
    public var stateSince: Date
    /// Latest known context-window usage, or `nil` for agents that don't report
    /// it. Preserved across events that carry no usage (see `SessionStore.apply`).
    public var usage: ContextUsage?

    public init(
        id: String,
        agentKind: AgentKind,
        project: String? = nil,
        state: AgentState,
        message: String? = nil,
        taskSummary: String? = nil,
        source: AgentSource,
        updatedAt: Date,
        stateSince: Date? = nil,
        usage: ContextUsage? = nil
    ) {
        self.id = id
        self.agentKind = agentKind
        self.project = project
        self.state = state
        self.message = message
        self.taskSummary = taskSummary
        self.source = source
        self.updatedAt = updatedAt
        self.stateSince = stateSince ?? updatedAt
        self.usage = usage
    }
}
