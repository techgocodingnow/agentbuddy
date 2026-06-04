import AppKit
import AgentPetCore

/// Boundary for the pet/menu Reply affordance.
///
/// The current session model does not include a terminal id, TTY, process id,
/// or app window handle, so direct text injection would be unreliable. For v1,
/// Reply copies a concise session context and opens the detailed popover. A
/// later phase can replace this boundary with true focus/reply once sessions
/// carry a reliable local target.
@MainActor
final class SessionReplyController: ObservableObject {
    static let shared = SessionReplyController()

    @Published private(set) var lastSessionID: String?

    func reply(to session: AgentSession) {
        lastSessionID = session.id
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(context(for: session), forType: .string)
        StatusBarController.shared.showPopoverFromStatusItem()
    }

    private func context(for session: AgentSession) -> String {
        let title = session.project.map { ($0 as NSString).lastPathComponent } ?? session.id
        let state = session.state.rawValue
        let message = session.message?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let message, !message.isEmpty {
            return "\(session.agentKind.displayName) \(title) is \(state): \(message)"
        }
        return "\(session.agentKind.displayName) \(title) is \(state)"
    }
}
