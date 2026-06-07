import SwiftUI
import AgentBuddyCore

/// The pet sprite alone (imported pack, reacting to mood). Shows a paw
/// placeholder if no pet is selected yet.
struct PetView: View {
    var size: CGFloat = 120
    @ObservedObject private var pet = PetController.shared
    @ObservedObject private var imagePets = ImagePetStore.shared
    @ObservedObject private var bindings = PetBindingsStore.shared
    @ObservedObject private var progress = PetProgressStore.shared
    @ObservedObject private var game = PetGameStore.shared

    var body: some View {
        content
            .frame(width: size, height: size)
            .contentShape(Rectangle())
    }

    @ViewBuilder private var content: some View {
        if let id = pet.selectedPetID, let pack = imagePets.pack(id: id) {
            let petProgress = progress.progress(for: id)
            let clip = bindings.clipIndex(packId: pack.id, clipCount: pack.clipCount, mood: pet.mood)
            if let start = pet.hatchAnimationStartedAt {
                HatchingPetView(frames: pack.clip(clip), startDate: start, size: size)
            } else if petProgress.isHatched {
                PetDisplayView(
                    frames: pack.clip(clip),
                    mood: pet.mood,
                    size: size,
                    level: petProgress.level,
                    cosmeticID: game.equippedCosmeticID(for: id),
                    levelUpStartedAt: pet.levelUpStartedAt,
                    rewardLabel: pet.rewardLabel
                )
            } else {
                PetEggView(size: size, mood: pet.mood, progress: petProgress)
            }
        } else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: size * 0.4))
                .foregroundStyle(.secondary)
        }
    }
}

private struct PetDisplayView: View {
    let frames: [NSImage]
    let mood: PetMood
    let size: CGFloat
    let level: Int
    let cosmeticID: String?
    let levelUpStartedAt: Date?
    let rewardLabel: String

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let now = context.date
            let elapsed = levelUpStartedAt.map { now.timeIntervalSince($0) }
            let levelUpProgress = elapsed.map { max(0, min(1, $0 / 1.8)) }

            ZStack {
                CosmeticBackdrop(cosmeticID: cosmeticID, size: size, time: now.timeIntervalSinceReferenceDate)

                ImageSpriteView(frames: frames, mood: mood, size: size)
                    .scaleEffect(levelUpProgress == nil ? 1 : 1 + sin((levelUpProgress ?? 0) * .pi) * 0.08)
                    .shadow(color: levelUpProgress == nil ? .clear : Color.systemAccent.opacity(0.45),
                            radius: levelUpProgress == nil ? 0 : 12,
                            y: 0)

                CosmeticForeground(cosmeticID: cosmeticID, level: level, size: size, time: now.timeIntervalSinceReferenceDate)

                if let levelUpProgress {
                    LevelUpBurst(size: size, progress: levelUpProgress)
                }

                if !rewardLabel.isEmpty {
                    RewardLabel(text: rewardLabel, size: size)
                        .transition(.scale(scale: 0.75).combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
        }
    }
}

private struct CosmeticBackdrop: View {
    let cosmeticID: String?
    let size: CGFloat
    let time: TimeInterval

    var body: some View {
        ZStack {
            if cosmeticID == PetCosmeticID.softAura {
                Circle()
                    .fill(Color.systemAccent.opacity(0.22))
                    .frame(width: size * 0.82, height: size * 0.82)
                    .blur(radius: size * 0.08)
            }
            if cosmeticID == PetCosmeticID.idleGlow {
                Circle()
                    .stroke(Color.systemAccent.opacity(0.24 + 0.16 * sin(time * 2.4)), lineWidth: max(2, size * 0.035))
                    .frame(width: size * (0.76 + 0.04 * sin(time * 2.4)), height: size * (0.76 + 0.04 * sin(time * 2.4)))
                    .blur(radius: size * 0.025)
            }
        }
    }
}

private struct CosmeticForeground: View {
    let cosmeticID: String?
    let level: Int
    let size: CGFloat
    let time: TimeInterval

    var body: some View {
        ZStack {
            if cosmeticID == PetCosmeticID.sparkleTrail {
                SparkleRing(size: size, time: time, opacity: 0.85)
            }
            if cosmeticID == PetCosmeticID.goldenNameplate {
                Text("Lv \(level)")
                    .font(.system(size: max(10, size * 0.11), weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.black.opacity(0.86))
                    .padding(.horizontal, max(7, size * 0.07))
                    .padding(.vertical, max(3, size * 0.025))
                    .background(Capsule().fill(Color.yellow.opacity(0.9)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
                    .offset(y: size * 0.36)
            }
            if cosmeticID == PetCosmeticID.hatchShimmer {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.28), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.24, height: size * 1.2)
                    .rotationEffect(.degrees(28))
                    .offset(x: CGFloat(sin(time * 1.2)) * size * 0.34)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct SparkleRing: View {
    let size: CGFloat
    let time: TimeInterval
    let opacity: Double

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                let phase = time * 1.6 + Double(index) * 0.9
                let radius = size * (0.34 + 0.04 * sin(phase))
                let angle = phase + Double(index) * .pi * 2 / 7
                Circle()
                    .fill(Color.white.opacity(opacity * (0.45 + 0.35 * sin(phase))))
                    .frame(width: max(3, size * 0.04), height: max(3, size * 0.04))
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius * 0.78)
            }
        }
    }
}

private struct LevelUpBurst: View {
    let size: CGFloat
    let progress: Double

    var body: some View {
        ZStack {
            SparkleRing(size: size * (1 + progress * 0.35), time: progress * 6, opacity: 1 - progress * 0.45)
            Circle()
                .stroke(Color.systemAccent.opacity(1 - progress), lineWidth: max(2, size * 0.03))
                .frame(width: size * (0.4 + progress * 0.7), height: size * (0.4 + progress * 0.7))
        }
        .opacity(1 - progress * 0.4)
    }
}

private struct RewardLabel: View {
    let text: String
    let size: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: max(11, size * 0.105), weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, max(9, size * 0.08))
            .padding(.vertical, max(5, size * 0.04))
            .background(Capsule().fill(.black.opacity(0.78)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            .offset(y: -size * 0.42)
    }
}

enum EggVisualStage: Hashable {
    case whole
    case crackSmall
    case crackLarge
    case fragment

    init(progress: PetProgress) {
        switch progress.totalTokens {
        case ..<PetProgressRules.smallCrackTokens:
            self = .whole
        case ..<PetProgressRules.largeCrackTokens:
            self = .crackSmall
        case ..<PetProgressRules.fragmentTokens:
            self = .crackLarge
        default:
            self = .fragment
        }
    }

    var resourceName: String {
        switch self {
        case .whole: return "pet-egg"
        case .crackSmall: return "pet-egg-crack-small"
        case .crackLarge: return "pet-egg-crack-large"
        case .fragment: return "pet-egg-fragment"
        }
    }
}

struct PetEggView: View {
    var size: CGFloat
    var mood: PetMood = .idle
    var progress: PetProgress = PetProgress()
    var stage: EggVisualStage?

    private var resolvedStage: EggVisualStage {
        stage ?? EggVisualStage(progress: progress)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let wiggle = mood == .working || mood == .celebrate ? sin(t * 7) * 2.8 : 0
            let lift = mood == .waiting ? sin(t * 4) * 2.0 : 0

            Group {
                EggStageImage(stage: resolvedStage, size: size)
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(wiggle), anchor: .bottom)
            .offset(y: lift)
            .shadow(color: Color.systemAccent.opacity(mood == .celebrate ? 0.45 : 0.18),
                    radius: mood == .celebrate ? 12 : 5,
                    y: 3)
        }
    }
}

private struct EggStageImage: View {
    let stage: EggVisualStage
    let size: CGFloat

    private static let images: [EggVisualStage: NSImage] = {
        Dictionary(uniqueKeysWithValues: [EggVisualStage.whole, .crackSmall, .crackLarge, .fragment].compactMap { stage in
            guard let url = Bundle.module.url(forResource: stage.resourceName, withExtension: "png"),
                  let image = NSImage(contentsOf: url) else { return nil }
            return (stage, image)
        })
    }()

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "circle.fill")
                    .font(.system(size: size * 0.72))
                    .foregroundStyle(Color.systemAccent.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
    }

    private var image: NSImage? {
        Self.images[stage]
    }
}

private struct HatchingPetView: View {
    let frames: [NSImage]
    let startDate: Date
    let size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let reveal = max(0, min(1, (elapsed - 1.05) / 0.8))
            let eggOpacity = elapsed < 1.75 ? 1 : max(0, 1 - (elapsed - 1.75) / 0.45)
            let shake = elapsed < 1.55 ? sin(context.date.timeIntervalSinceReferenceDate * 32) * (5 - min(elapsed * 2, 3)) : 0

            ZStack {
                EggStageImage(stage: hatchStage(elapsed), size: size)
                    .scaleEffect(1 + min(elapsed, 1.5) * 0.04)
                    .rotationEffect(.degrees(shake), anchor: .bottom)
                    .opacity(eggOpacity)

                ImageSpriteView(frames: frames, mood: .celebrate, size: size)
                    .scaleEffect(0.55 + 0.45 * reveal)
                    .offset(y: (1 - reveal) * 18)
                    .opacity(reveal)
            }
            .frame(width: size, height: size)
        }
    }

    private func hatchStage(_ elapsed: TimeInterval) -> EggVisualStage {
        switch elapsed {
        case ..<0.45: return .crackSmall
        case ..<0.95: return .crackLarge
        default: return .fragment
        }
    }
}

/// The full floating window content: a chat bubble above the pet.
struct FloatingPetView: View {
    @ObservedObject private var pet = PetController.shared

    var body: some View {
        VStack(spacing: 8) {
            if pet.showChat && !pet.chatLine.isEmpty && pet.selectedPetID != nil {
                ChatBubble(text: pet.chatLine)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            PetView(size: pet.petPoint)
            if !pet.activeSessions.isEmpty {
                SessionCardStack(
                    sessions: pet.visibleSessions,
                    hiddenCount: pet.hiddenSessionCount,
                    summary: pet.compactSummary
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(width: pet.windowSize.width, height: pet.windowSize.height, alignment: .bottom)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: pet.chatLine)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: pet.activeSessions)
        .animation(.easeInOut, value: pet.showChat)
    }
}

private struct SessionCardStack: View {
    let sessions: [AgentSession]
    let hiddenCount: Int
    let summary: String

    var body: some View {
        VStack(spacing: 6) {
            ForEach(sessions) { session in
                FloatingSessionCard(session: session)
            }
            if hiddenCount > 0 {
                Text("+\(hiddenCount) more" + overflowSuffix)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 330, height: 24)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.black.opacity(0.72)))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
            }
        }
        .frame(width: 330)
    }

    private var overflowSuffix: String {
        summary.isEmpty ? "" : " - \(summary)"
    }
}

private struct FloatingSessionCard: View {
    let session: AgentSession
    @ObservedObject private var statusBar = StatusBarController.shared
    @ObservedObject private var reply = SessionReplyController.shared

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 9, height: 9)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(hasDetailedSubtitle ? 2 : 1)
                            .truncationMode(.tail)
                    }
                    Spacer(minLength: 0)
                }
                if showMetadata {
                    CompactSessionMetadataView(
                        stats: compactStats,
                        contextUsage: session.usage,
                        quotaUsage: session.quotaUsage,
                        mode: statusBar.usageDisplayMode,
                        showUsage: showUsage
                    )
                    .padding(.top, 1)
                }
                if !actions.isEmpty {
                    actionButtons
                        .padding(.top, 5)
                }
            }
        }
        .frame(width: 302, height: cardContentHeight)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.black.opacity(0.86)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 6, y: 2)
    }

    private var actionButtons: some View {
        HStack(spacing: 7) {
            Spacer(minLength: 0)
            ForEach(actions, id: \.rawValue) { action in
                Button(action.label) {
                    reply.perform(action, on: session)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(color(for: action).opacity(0.9)))
                .lineLimit(1)
            }
        }
    }

    private var actions: [AgentSessionAction] {
        reply.availableActions(for: session)
    }

    private var title: String {
        session.displayTitle ?? session.project.map { ($0 as NSString).lastPathComponent } ?? session.id
    }

    private var subtitle: String {
        session.pendingRequest?.prompt ?? session.displayMessage ?? session.compactStatusText
    }

    private var hasDetailedSubtitle: Bool {
        session.pendingRequest?.prompt != nil || session.displayMessage != nil
    }

    private var showUsage: Bool {
        statusBar.showContextUsage && (session.usage != nil || session.quotaUsage != nil)
    }

    private var compactStats: AgentRuntimeStats? {
        guard statusBar.showSessionStats,
              let stats = session.stats,
              stats.compactModelLabel != nil || stats.isFastLike || stats.compactDetailLabel != nil else { return nil }
        return stats
    }

    private var showMetadata: Bool {
        compactStats != nil || showUsage
    }

    private var cardContentHeight: CGFloat {
        var height: CGFloat = hasDetailedSubtitle ? 58 : 44
        if showMetadata { height += 16 }
        if !actions.isEmpty { height += 30 }
        return height
    }

    private func color(for action: AgentSessionAction) -> Color {
        switch action {
        case .deny: return .red
        case .review: return .blue
        case .allow, .apply, .continue: return .green
        case .reply, .answer: return .orange
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
}

private struct CompactSessionMetadataView: View {
    let stats: AgentRuntimeStats?
    let contextUsage: ContextUsage?
    let quotaUsage: AgentQuotaUsage?
    let mode: UsageDisplayMode
    let showUsage: Bool

    var body: some View {
        HStack(spacing: 9) {
            if let stats {
                CompactStatsView(stats: stats)
            }
            if showUsage {
                CompactUsageMetricsView(
                    contextUsage: contextUsage,
                    quotaUsage: quotaUsage,
                    mode: mode
                )
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CompactStatsView: View {
    let stats: AgentRuntimeStats

    var body: some View {
        HStack(spacing: 5) {
            if stats.isFastLike {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.54))
            }
            if let model = stats.compactModelLabel {
                Text(model)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
            }
            if let detail = stats.compactDetailLabel {
                Text(detail)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CompactUsageMetricsView: View {
    let contextUsage: ContextUsage?
    let quotaUsage: AgentQuotaUsage?
    let mode: UsageDisplayMode

    private var items: [(String, Int)] {
        var values: [(String, Int)] = []
        if let session = quotaUsage?.sessionUsedPercent {
            values.append(("S", AgentQuotaUsage.displayPercent(usedPercent: session, mode: mode)))
        }
        if let weekly = quotaUsage?.weeklyUsedPercent {
            values.append(("W", AgentQuotaUsage.displayPercent(usedPercent: weekly, mode: mode)))
        }
        if let contextUsage {
            let percent = mode == .left ? contextUsage.percentLeft : contextUsage.percentUsed
            values.append(("C", percent))
        }
        return values
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.0) { item in
                Text("\(item.0):\(item.1)%")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

/// A speech bubble with a little downward tail.
private struct ChatBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black.opacity(0.85))
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.06), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
            Triangle()
                .fill(.white)
                .frame(width: 12, height: 7)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
