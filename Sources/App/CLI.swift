import AgentBuddyCore
import Foundation

/// CLI helper invoked by agent hooks: `agentbuddy hook --event ... --session ...`.
enum HookCLI {
    static func run(arguments: [String]) -> Never {
        // Explicit flags win (used by opencode's plugin and the run wrapper);
        // otherwise fall back to the agent's hook payload on stdin, decoded with
        // that agent's field convention. `--agent` selects the agent.
        let now = Date()
        let parsed = HookArguments.parse(arguments)
        let kind = parsed.agent.flatMap(AgentKind.init(rawValue:)) ?? .claude
        let stdin = FileHandle.standardInput.readDataToEndOfFile()
        let hookPayload = ClaudeHookPayload.decode(from: stdin)
        let responsePath = parsed.event == nil && hookPayload?.waitsForAgentBuddyResponse == true
            ? PendingAgentResponseStore.responsePath()
            : nil
        let event = parsed.makeEvent(now: now)
            ?? HookPayload.event(forAgent: kind, stdin: stdin, now: now, pendingResponsePath: responsePath)

        guard let event else {
            FileHandle.standardError.write(Data(
                "usage: agentbuddy hook --event <name> --session <id> [--project <path>] [--agent <kind>] [--title <text>] [--message <text>]\n         or pipe a Claude Code hook JSON payload on stdin\n".utf8
            ))
            exit(2)
        }
        let delivered = EventSender.send(
            event,
            socketPath: AgentBuddyPaths.socketPath,
            queueDir: AgentBuddyPaths.queueDir,
            queueOnFailure: responsePath == nil
        )
        if !delivered, responsePath != nil {
            var observationalEvent = event
            observationalEvent.pendingRequest = nil
            EventSender.send(observationalEvent, socketPath: AgentBuddyPaths.socketPath, queueDir: AgentBuddyPaths.queueDir)
        }
        if delivered, let responsePath, let hookPayload {
            if let response = PendingAgentResponseStore.waitForResponse(at: responsePath),
               let output = hookPayload.hookOutput(for: response, kind: kind) {
                FileHandle.standardOutput.write(output)
                FileHandle.standardOutput.write(Data("\n".utf8))
            }
        }
        exit(0)
    }
}
