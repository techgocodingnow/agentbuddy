import Foundation
import AgentPetCore

/// Resolves the aggregate session mood, plays a short `celebrate` burst when
/// work finishes, owns the selected (imported) pet, and drives the chat bubble.
@MainActor
final class PetController: ObservableObject {
    static let shared = PetController()

    @Published private(set) var mood: PetMood = .idle
    @Published private(set) var chatLine: String = ""
    @Published private(set) var compactSummary: String = ""
    @Published private(set) var activeSessions: [AgentSession] = []

    @Published var selectedPetID: String? {
        didSet { UserDefaults.standard.set(selectedPetID, forKey: Self.petKey) }
    }
    @Published var showChat: Bool {
        didSet {
            UserDefaults.standard.set(showChat, forKey: Self.chatKey)
            refreshChat()
        }
    }
    /// Sprite point size, freely adjustable via a slider.
    @Published var petPoint: Double {
        didSet { UserDefaults.standard.set(petPoint, forKey: Self.sizeKey) }
    }

    static let minPoint: Double = 60
    static let maxPoint: Double = 240
    static let maxFloatingCards = 3
    static let presets: [(String, Double)] = [("S", 84), ("M", 120), ("L", 168)]

    /// Floating window size for a sprite point size (room for the bubble above).
    static func windowSize(forPoint point: Double, activeCount: Int = 0) -> CGSize {
        guard activeCount > 0 else {
            return CGSize(width: point + 110, height: point + 64)
        }

        let cardWidth: Double = 330
        let cardHeight: Double = 68
        let visibleCards = min(activeCount, maxFloatingCards)
        let overflowHeight = activeCount > maxFloatingCards ? 30.0 : 0.0
        let cardStackHeight = (cardHeight * Double(visibleCards)) + overflowHeight + 16
        return CGSize(width: max(point + 110, cardWidth + 28), height: point + cardStackHeight + 34)
    }
    var windowSize: CGSize { Self.windowSize(forPoint: petPoint, activeCount: activeSessions.count) }
    var visibleSessions: [AgentSession] { Array(activeSessions.prefix(Self.maxFloatingCards)) }
    var hiddenSessionCount: Int { max(0, activeSessions.count - Self.maxFloatingCards) }

    private var lastResolved: PetMood = .idle
    private var latestSessions: [AgentSession] = []
    private var celebrateTimer: Timer?
    private var chatTimer: Timer?

    private static let petKey = "agentpet.selectedPetID"
    private static let chatKey = "agentpet.showChat"
    private static let sizeKey = "agentpet.petSize"
    private static let celebrateDuration: TimeInterval = 3

    init() {
        selectedPetID = UserDefaults.standard.string(forKey: Self.petKey)
        showChat = (UserDefaults.standard.object(forKey: Self.chatKey) as? Bool) ?? true
        let saved = UserDefaults.standard.object(forKey: Self.sizeKey) as? Double ?? 120
        petPoint = min(max(saved, Self.minPoint), Self.maxPoint)
    }

    func start() {
        // Vary the chat line periodically while the pet is active.
        chatTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.refreshChat() }
        }
    }

    private var sizeAnimTimer: Timer?
    private var sizeAnimStep = 0
    private var sizeAnimStart = 0.0
    private var sizeAnimTarget = 0.0
    private static let sizeAnimSteps = 14

    /// Eases `petPoint` to a target so a preset tap resizes as smoothly as a
    /// slider drag (each step drives the same smooth window resize).
    func animateSize(to target: Double) {
        sizeAnimTimer?.invalidate()
        sizeAnimTarget = min(max(target, Self.minPoint), Self.maxPoint)
        sizeAnimStart = petPoint
        sizeAnimStep = 0
        sizeAnimTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.tickSize() }
        }
    }

    private func tickSize() {
        sizeAnimStep += 1
        let t = min(Double(sizeAnimStep) / Double(Self.sizeAnimSteps), 1)
        let eased = t * t * (3 - 2 * t)   // smoothstep
        petPoint = sizeAnimStart + (sizeAnimTarget - sizeAnimStart) * eased
        if sizeAnimStep >= Self.sizeAnimSteps {
            petPoint = sizeAnimTarget
            sizeAnimTimer?.invalidate()
        }
    }

    /// Called by the daemon whenever the session list changes.
    func update(sessions: [AgentSession]) {
        latestSessions = sessions
        refreshSessionPresentation(sessions)
        let resolved = MoodResolver.aggregate(sessions)
        defer { lastResolved = resolved }

        if resolved == .done && lastResolved != .done {
            setMood(.celebrate)
            celebrateTimer?.invalidate()
            celebrateTimer = Timer.scheduledTimer(withTimeInterval: Self.celebrateDuration, repeats: false) { _ in
                Task { @MainActor [weak self] in self?.settleAfterCelebrate() }
            }
            return
        }
        if mood == .celebrate && resolved == .done {
            return  // let the celebration finish
        }
        celebrateTimer?.invalidate()
        setMood(resolved)
    }

    private func settleAfterCelebrate() {
        setMood(MoodResolver.aggregate(latestSessions))
    }

    private func setMood(_ newMood: PetMood) {
        mood = newMood
        refreshChat()
    }

    private func refreshChat() {
        let pool = ChatSettings.shared.lines(for: mood)
        guard showChat, mood != .idle else {
            chatLine = ""
            StatusBarController.shared.refreshTitle()
            return
        }
        // Speak the agent's real message when it has finished or needs input;
        // otherwise use pet-style chat. The compact summary still belongs to
        // the status cards/menu, not the floating speech bubble.
        if let spoken = spokenMessage() {
            chatLine = spoken
        } else {
            chatLine = fallbackChatLine(from: pool)
        }
        StatusBarController.shared.refreshTitle()
    }

    private func fallbackChatLine(from pool: [String]) -> String {
        let lead = leadSessionForChat()
        if ChatSettings.shared.source == .system,
           let systemLine = PetChat.line(for: mood, agentKind: lead?.agentKind) {
            return systemLine
        }
        return render(pool.randomElement() ?? compactSummary, for: lead)
    }

    private func render(_ line: String, for session: AgentSession?) -> String {
        guard let session else { return line }
        return line.replacingOccurrences(of: "{agent}", with: session.agentKind.displayName)
    }

    private func leadSessionForChat() -> AgentSession? {
        switch mood {
        case .working:
            return activeSessions.first { $0.state == .working }
        case .waiting:
            return activeSessions.first { $0.state == .waiting }
        case .done, .celebrate:
            return activeSessions.first { $0.state == .done }
        case .idle:
            return nil
        }
    }

    /// The lead waiting/done session's own message, if any — the pet voices
    /// this instead of a generic "Claude done". Skipped during the celebrate
    /// burst so the celebration plays first.
    private func spokenMessage() -> String? {
        guard mood == .done || mood == .waiting else { return nil }
        let lead = activeSessions.first {
            ($0.state == .waiting || $0.state == .done) && $0.displayMessage != nil
        }
        return lead?.displayMessage
    }

    private func refreshSessionPresentation(_ sessions: [AgentSession]) {
        compactSummary = AgentSessionSummary.compact(for: sessions) ?? ""
        activeSessions = sessions.filter { $0.state != .idle && $0.state != .registered }
    }
}

/// Built-in (system) chat lines per mood.
enum PetChat {
    static func line(for mood: PetMood, agentKind: AgentKind?) -> String? {
        guard let agentKind else { return lines[mood]?.randomElement() }
        let templates = agentLines[mood]?[agentKind] ?? agentTemplates[mood]
        return templates?
            .randomElement()?
            .replacingOccurrences(of: "{agent}", with: agentKind.displayName)
            ?? lines[mood]?.randomElement()
    }

    static let lines: [PetMood: [String]] = [
        .working: [
            "Thinking…", "Working on it…", "On it!", "Crunching code…",
            "Hmm, let me see…", "Cooking something up…", "Deep in thought…",
            "Brain go brrr…", "Almost there…", "Wiring it up…",
        ],
        .waiting: [
            "I need you!", "Your turn 👀", "Waiting on you…", "Can you check this?",
            "Psst, need input!", "Awaiting orders…", "Help me out?", "Stuck, need you!",
        ],
        .done: [
            "All done! ✅", "Finished!", "Ta-da!", "Done and dusted!",
            "Nailed it!", "That's a wrap!", "Mission complete!",
        ],
        .celebrate: [
            "🎉 Woohoo!", "We did it!", "Victory!", "Yesss!", "High five! 🙌", "Champion!",
        ],
    ]

    private static let agentTemplates: [PetMood: [String]] = [
        .working: [
            "{agent} pet is working on it…",
            "{agent} pet is deep in the code…",
            "{agent} pet is thinking it through…",
        ],
        .waiting: [
            "{agent} pet needs your input.",
            "{agent} pet is waiting on you.",
            "{agent} pet needs a quick decision.",
        ],
        .done: [
            "{agent} pet finished the turn.",
            "{agent} pet wrapped it up.",
            "{agent} pet is done.",
        ],
        .celebrate: [
            "{agent} pet nailed it!",
            "{agent} pet is celebrating!",
            "{agent} pet got it done!",
        ],
    ]

    private static let agentLines: [PetMood: [AgentKind: [String]]] = [
        .working: [
            .claude: [
                "Claude pet is thinking through the prompt…",
                "Claude pet is drafting carefully…",
                "Claude pet is reading the context…",
            ],
            .codex: [
                "Codex pet is working through the code…",
                "Codex pet is patching the app…",
                "Codex pet is checking the flow…",
            ],
        ],
    ]
}
