import AppKit
import AgentBuddyCore

@MainActor
final class SessionReplyController: ObservableObject {
    static let shared = SessionReplyController()

    @Published private(set) var lastSessionID: String?
    @Published private(set) var lastError: String?

    func reply(to session: AgentSession) {
        perform(defaultAction(for: session), on: session)
    }

    func perform(_ action: AgentSessionAction, on session: AgentSession) {
        lastSessionID = session.id
        lastError = nil
        if action.needsText {
            promptForText(action: action, session: session)
            return
        }
        submit(action: action, text: nil, session: session)
    }

    func availableActions(for session: AgentSession) -> [AgentSessionAction] {
        if let actions = session.pendingRequest?.actions, !actions.isEmpty {
            return actions
        }
        switch session.state {
        case .waiting:
            return [.reply]
        case .done:
            return [.continue]
        default:
            return []
        }
    }

    private func defaultAction(for session: AgentSession) -> AgentSessionAction {
        availableActions(for: session).first ?? .reply
    }

    private func promptForText(action: AgentSessionAction, session: AgentSession) {
        let alert = NSAlert()
        alert.messageText = "\(action.label) to \(displayTitle(for: session))"
        alert.informativeText = session.pendingRequest?.prompt ?? session.displayMessage ?? "Send a follow-up prompt to this agent session."
        alert.addButton(withTitle: "Send")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        field.placeholderString = action == .continue ? "What should the agent do next?" : "Reply"
        alert.accessoryView = field

        NSApplication.shared.activate(ignoringOtherApps: true)
        let result = alert.runModal()
        guard result == .alertFirstButtonReturn else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        submit(action: action, text: text, session: session)
    }

    private func submit(action: AgentSessionAction, text: String?, session: AgentSession) {
        if let responsePath = session.pendingRequest?.responsePath {
            do {
                try PendingAgentResponseStore.write(PendingAgentResponse(action: action, text: text), to: responsePath)
                AppDaemon.shared.resolvePendingRequest(session.id)
                return
            } catch {
                lastError = "Could not send \(action.label.lowercased()) to waiting hook."
            }
        }

        if action.needsText, let text {
            continueSession(session, prompt: text)
            return
        }

        // Review means "show the native prompt" when a hook is waiting. If the
        // hook is already gone, fall back to bringing the agent forward.
        focusAgent(session)
    }

    private func continueSession(_ session: AgentSession, prompt: String) {
        let process = Process()
        process.currentDirectoryURL = session.project.map { URL(fileURLWithPath: $0) }
        switch session.agentKind {
        case .codex:
            let codexPath = "/Applications/Codex.app/Contents/Resources/codex"
            if FileManager.default.isExecutableFile(atPath: codexPath) {
                process.executableURL = URL(fileURLWithPath: codexPath)
                process.arguments = ["exec", "resume", session.id, prompt]
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["codex", "exec", "resume", session.id, prompt]
            }
        case .claude:
            let claudePath = NSHomeDirectory() + "/.local/bin/claude"
            if FileManager.default.isExecutableFile(atPath: claudePath) {
                process.executableURL = URL(fileURLWithPath: claudePath)
                process.arguments = ["--resume", session.id, "--print", prompt]
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["claude", "--resume", session.id, "--print", prompt]
            }
        default:
            copyContext(for: session)
            StatusBarController.shared.showPopoverFromStatusItem()
            return
        }
        let null = FileHandle(forWritingAtPath: "/dev/null")
        process.standardOutput = null
        process.standardError = null
        do {
            try process.run()
        } catch {
            lastError = "Could not resume \(session.agentKind.displayName)."
            copyContext(for: session)
            focusAgent(session)
        }
    }

    private func focusAgent(_ session: AgentSession) {
        switch session.agentKind {
        case .codex:
            NSWorkspace.shared.launchApplication(withBundleIdentifier: "com.openai.codex", options: [.async], additionalEventParamDescriptor: nil, launchIdentifier: nil)
        case .claude:
            StatusBarController.shared.showPopoverFromStatusItem()
        default:
            StatusBarController.shared.showPopoverFromStatusItem()
        }
    }

    private func copyContext(for session: AgentSession) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(context(for: session), forType: .string)
    }

    private func displayTitle(for session: AgentSession) -> String {
        session.displayTitle ?? session.project.map { ($0 as NSString).lastPathComponent } ?? session.id
    }

    private func context(for session: AgentSession) -> String {
        let title = displayTitle(for: session)
        let state = session.state.rawValue
        let message = session.message?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let message, !message.isEmpty {
            return "\(session.agentKind.displayName) \(title) is \(state): \(message)"
        }
        return "\(session.agentKind.displayName) \(title) is \(state)"
    }
}
