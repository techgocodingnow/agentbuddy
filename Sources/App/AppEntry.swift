import Foundation

/// Single binary, two roles:
/// - `agentbuddy hook ...` runs the lightweight CLI helper (issue #4).
/// - `agentbuddy install-hook ...` installs an agent hook from terminal.
/// - no arguments launches the menu bar app.
@main
struct AgentBuddyMain {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        switch args.first {
        case "hook":
            HookCLI.run(arguments: Array(args.dropFirst()))
        case "install-hook":
            InstallHookCLI.run(arguments: Array(args.dropFirst()))
        case "run":
            RunCLI.run(arguments: Array(args.dropFirst()))
        default:
            AgentBuddyApp.main()
        }
    }
}
