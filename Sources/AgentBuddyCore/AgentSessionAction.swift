import Foundation

public enum AgentSessionAction: String, Codable, Sendable, Equatable, CaseIterable {
    case reply
    case allow
    case deny
    case apply
    case review
    case `continue`
    case answer

    public var label: String {
        switch self {
        case .reply: return "Reply"
        case .allow: return "Allow"
        case .deny: return "Deny"
        case .apply: return "Apply"
        case .review: return "Review"
        case .continue: return "Continue"
        case .answer: return "Answer"
        }
    }

    public var needsText: Bool {
        switch self {
        case .reply, .answer, .continue: return true
        case .allow, .deny, .apply, .review: return false
        }
    }
}

public enum PendingAgentRequestKind: String, Codable, Sendable, Equatable {
    case permission
    case elicitation
    case question
    case continuation
}

public struct PendingAgentRequest: Codable, Sendable, Equatable {
    public var id: String
    public var kind: PendingAgentRequestKind
    public var actions: [AgentSessionAction]
    public var prompt: String?
    public var toolName: String?
    public var toolInputSummary: String?
    public var responsePath: String?
    public var turnId: String?
    public var transcriptPath: String?

    public init(
        id: String,
        kind: PendingAgentRequestKind,
        actions: [AgentSessionAction],
        prompt: String? = nil,
        toolName: String? = nil,
        toolInputSummary: String? = nil,
        responsePath: String? = nil,
        turnId: String? = nil,
        transcriptPath: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.actions = actions
        self.prompt = prompt
        self.toolName = toolName
        self.toolInputSummary = toolInputSummary
        self.responsePath = responsePath
        self.turnId = turnId
        self.transcriptPath = transcriptPath
    }
}

public struct PendingAgentResponse: Codable, Sendable, Equatable {
    public var action: AgentSessionAction
    public var text: String?

    public init(action: AgentSessionAction, text: String? = nil) {
        self.action = action
        self.text = text
    }
}

public enum PendingAgentResponseStore {
    public static func responsePath(id: String = UUID().uuidString, baseDir: String = AgentBuddyPaths.pendingResponseDir) -> String {
        (baseDir as NSString).appendingPathComponent("\(id).json")
    }

    public static func removeStaleResponses(
        olderThan age: TimeInterval = 1_800,
        now: Date = Date(),
        baseDir: String = AgentBuddyPaths.pendingResponseDir
    ) {
        let directory = URL(fileURLWithPath: baseDir)
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = now.addingTimeInterval(-age)
        for url in urls where url.pathExtension == "json" {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified < cutoff else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    public static func write(_ response: PendingAgentResponse, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(response)
        try data.write(to: url, options: [.atomic])
    }

    public static func waitForResponse(at path: String, timeout: TimeInterval = 600, pollInterval: TimeInterval = 0.2) -> PendingAgentResponse? {
        let deadline = Date().addingTimeInterval(timeout)
        let url = URL(fileURLWithPath: path)
        while Date() < deadline {
            if let data = try? Data(contentsOf: url),
               let response = try? JSONDecoder().decode(PendingAgentResponse.self, from: data) {
                try? FileManager.default.removeItem(at: url)
                return response
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        return nil
    }
}
