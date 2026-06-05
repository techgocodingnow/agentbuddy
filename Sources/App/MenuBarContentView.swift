import SwiftUI
import AppKit
import AgentBuddyCore

/// Rich menu bar popover: a blurred dark card with an arrow pointing at the
/// status item, a live agent list, and a footer bar.
struct MenuContentView: View {
    @ObservedObject private var daemon = AppDaemon.shared
    @ObservedObject private var petWindow = PetWindowController.shared
    @ObservedObject private var statusBar = StatusBarController.shared
    @ObservedObject private var pet = PetController.shared
    @ObservedObject private var reply = SessionReplyController.shared
    var dismiss: () -> Void

    /// Show agents that are doing something or just finished. Idle and merely
    /// `registered` (open but not working) sessions are hidden, so an idle
    /// terminal doesn't sit in the list; they reappear the moment they work.
    private var agents: [AgentSession] {
        daemon.sessions.filter { $0.state != .idle && $0.state != .registered }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            agentSection
            divider
            controls
            divider
            footer
        }
        .frame(width: 300)
        .background(.regularMaterial)
        .environment(\.colorScheme, .dark)
        .noFocusRing()
    }

    private var divider: some View { Divider().overlay(Color.white.opacity(0.08)) }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            appIcon
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("AgentBuddy").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }
            Spacer()
        }
        .padding(14)
    }

    /// The app's own bundle icon. Falls back to a paw glyph when the icon is
    /// unavailable, e.g. running unbundled via `swift run` in dev.
    private var appIcon: Image {
        if let icon = NSApplication.shared.applicationIconImage {
            return Image(nsImage: icon)
        }
        return Image(systemName: "pawprint.fill")
    }

    private var subtitle: String {
        let total = agents.count
        if total == 0 { return "No agents running" }
        if !pet.compactSummary.isEmpty { return pet.compactSummary }
        return "\(total) agent\(total == 1 ? "" : "s")"
    }

    // MARK: Agents

    private var agentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionLabel("Agents")
                Spacer()
                if !agents.isEmpty {
                    Button("Clear all") { daemon.clearSessions() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.trailing, 14).padding(.top, 12).padding(.bottom, 6)
                }
            }
            if agents.isEmpty {
                Text("Nothing running right now.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 14).padding(.bottom, 12)
            } else {
                ForEach(agents) { session in
                    AgentRow(
                        session: session,
                        onReply: { reply.reply(to: session) },
                        onClear: { daemon.removeSession(session.id) }
                    )
                }
                .padding(.bottom, 6)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold)).tracking(1.4)
            .foregroundStyle(.white.opacity(0.35))
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 6)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 0) {
            controlRow(icon: "pawprint", label: "Show pet", isOn: $petWindow.isVisible)
            controlRow(icon: "number", label: "Show count on menu bar", isOn: $statusBar.showCount)
            controlRow(icon: "bubble.left", label: "Show chat on menu bar", isOn: $statusBar.showChatOnMenuBar)
            controlRow(icon: "cpu", label: "Show session stats", isOn: $statusBar.showSessionStats)
            controlRow(icon: "gauge", label: "Show context usage", isOn: $statusBar.showContextUsage)
            usageModeRow
            sizeRow
        }
    }

    private var usageModeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "percent")
                .foregroundStyle(.white.opacity(0.8)).frame(width: 16)
            Text("Usage value").font(.system(size: 13)).foregroundStyle(.white)
            Spacer()
            Picker("", selection: $statusBar.usageDisplayMode) {
                Text("Left").tag(UsageDisplayMode.left)
                Text("Used").tag(UsageDisplayMode.used)
            }
            .pickerStyle(.segmented)
            .controlSize(.mini)
            .frame(width: 92)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private var sizeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .foregroundStyle(.white.opacity(0.8)).frame(width: 16)
            Text("Pet size").font(.system(size: 13)).foregroundStyle(.white)
            Slider(value: $pet.petPoint, in: PetController.minPoint...PetController.maxPoint)
                .controlSize(.mini)
                .tint(Color.systemAccent)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private func controlRow(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.white.opacity(0.8)).frame(width: 16)
            Text(label).font(.system(size: 13)).foregroundStyle(.white)
            Spacer()
            ColorSwitch(isOn: isOn)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            FooterButton(icon: "gearshape", label: "Settings") {
                dismiss()
                // Open after the popover finishes closing so the window
                // reliably comes to the front.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    SettingsWindowController.shared.show()
                }
            }
            FooterButton(icon: "arrow.triangle.2.circlepath", label: "Updates") {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    UpdaterController.shared.checkForUpdates()
                }
            }
            Spacer()
            FooterButton(icon: "power", label: "Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

private struct FooterButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}

private struct AgentRow: View {
    let session: AgentSession
    var onReply: () -> Void = {}
    var onClear: () -> Void = {}
    @ObservedObject private var statusBar = StatusBarController.shared
    @ObservedObject private var reply = SessionReplyController.shared
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Circle().fill(dotColor).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(project).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1).truncationMode(.tail)
                }
                Spacer(minLength: 8)
                trailingControl
            }
            if !actions.isEmpty {
                actionButtons
                    .padding(.leading, 18)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var project: String {
        session.displayTitle ?? session.project.map { ($0 as NSString).lastPathComponent } ?? session.id
    }

    /// Compact UI-safe status. Raw hook messages can contain tool/workflow
    /// internals, so the menu mirrors the pet cards instead.
    private var subtitle: String {
        session.pendingRequest?.prompt ?? session.compactStatusText
    }

    private var actions: [AgentSessionAction] {
        reply.availableActions(for: session)
    }

    @ViewBuilder private var trailingControl: some View {
        if hovering {
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
        } else if actions.isEmpty {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(timeString(now: context.date))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            ForEach(actions, id: \.rawValue) { action in
                Button(action.label) {
                    reply.perform(action, on: session)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color(for: action))
                .lineLimit(1)
            }
        }
    }

    private var dotColor: Color {
        switch session.state {
        case .working, .registered: return .blue
        case .waiting: return .orange
        case .done: return .green
        case .idle: return .gray
        }
    }

    private func timeString(now: Date) -> String {
        switch session.state {
        case .done, .idle:
            return session.updatedAt.formatted(date: .omitted, time: .shortened)
        default:
            let s = max(0, Int(now.timeIntervalSince(session.stateSince)))
            return s < 60 ? "\(s)s" : "\(s / 60)m \(s % 60)s"
        }
    }

    private func color(for action: AgentSessionAction) -> Color {
        switch action {
        case .deny: return .red
        case .review: return .blue
        case .allow, .apply, .continue: return .green
        case .reply, .answer: return .orange
        }
    }
}
