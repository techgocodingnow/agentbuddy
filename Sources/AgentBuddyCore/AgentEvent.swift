import Foundation

/// A single state-change report from an agent, sent by the CLI helper to the
/// daemon. `eventName` is the agent-native event (e.g. Claude Code's "Stop");
/// `StateMapper` turns it into an `AgentState`.
public struct AgentEvent: Codable, Sendable, Equatable {
    public var sessionId: String
    public var agentKind: AgentKind
    public var eventName: String
    public var project: String?
    public var title: String?
    public var message: String?
    public var timestamp: Date
    /// Context-window usage at the time of the event. Only Claude reports the
    /// token counts this needs; other agents leave it `nil`.
    public var usage: ContextUsage?
    /// Cumulative local token progress for this session, when the agent exposes
    /// enough transcript data to account for it.
    public var tokenProgress: TokenProgress?
    /// Agent quota/rate-limit usage when exposed by the agent transcript.
    public var quotaUsage: AgentQuotaUsage?
    /// Optional runtime metadata such as model, speed mode, or service tier.
    public var stats: AgentRuntimeStats?
    /// Details for a user-visible request that AgentBuddy can answer directly
    /// while the agent hook is still waiting.
    public var pendingRequest: PendingAgentRequest?

    public init(
        sessionId: String,
        agentKind: AgentKind,
        eventName: String,
        project: String? = nil,
        title: String? = nil,
        message: String? = nil,
        timestamp: Date,
        usage: ContextUsage? = nil,
        tokenProgress: TokenProgress? = nil,
        quotaUsage: AgentQuotaUsage? = nil,
        stats: AgentRuntimeStats? = nil,
        pendingRequest: PendingAgentRequest? = nil
    ) {
        self.sessionId = sessionId
        self.agentKind = agentKind
        self.eventName = eventName
        self.project = project
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.usage = usage
        self.tokenProgress = tokenProgress
        self.quotaUsage = quotaUsage?.isEmpty == true ? nil : quotaUsage
        self.stats = stats?.isEmpty == true ? nil : stats
        self.pendingRequest = pendingRequest
    }
}
