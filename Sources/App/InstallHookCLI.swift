import AgentBuddyCore
import Foundation

/// Installs a hook without opening Settings. Useful for scripted setup and
/// repairing stale installs after a binary rename.
enum InstallHookCLI {
    static func run(arguments: [String]) -> Never {
        let kind = parseAgent(arguments: arguments)
        guard let spec = AgentHooks.spec(for: kind) else {
            FileHandle.standardError.write(Data(
                "usage: agentbuddy install-hook --agent <claude|codex|gemini|cursor|opencode|windsurf>\n".utf8))
            exit(2)
        }

        let executable = Bundle.main.executablePath ?? CommandLine.arguments.first ?? "agentbuddy"
        let command = "\"\(executable)\" hook --agent \(kind.rawValue)"

        do {
            try HookInstaller.installToDisk(command: command, path: spec.settingsPath, events: spec.events, style: spec.style)
            FileHandle.standardOutput.write(Data("Installed \(kind.rawValue) hook at \(spec.settingsPath)\n".utf8))
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("agentbuddy install-hook: failed to write \(spec.settingsPath)\n".utf8))
            exit(1)
        }
    }

    private static func parseAgent(arguments: [String]) -> AgentKind {
        guard let index = arguments.firstIndex(of: "--agent"),
              arguments.indices.contains(index + 1),
              let kind = AgentKind(rawValue: arguments[index + 1])
        else { return .unknown }
        return kind
    }
}
