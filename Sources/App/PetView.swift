import SwiftUI
import AgentPetCore

/// The pet sprite alone (imported pack, reacting to mood). Shows a paw
/// placeholder if no pet is selected yet.
struct PetView: View {
    var size: CGFloat = 120
    @ObservedObject private var pet = PetController.shared
    @ObservedObject private var imagePets = ImagePetStore.shared
    @ObservedObject private var bindings = PetBindingsStore.shared

    var body: some View {
        content
            .frame(width: size, height: size)
            .contentShape(Rectangle())
    }

    @ViewBuilder private var content: some View {
        if let id = pet.selectedPetID, let pack = imagePets.pack(id: id) {
            let clip = bindings.clipIndex(packId: pack.id, clipCount: pack.clipCount, mood: pet.mood)
            ImageSpriteView(frames: pack.clip(clip), mood: pet.mood, size: size)
        } else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: size * 0.4))
                .foregroundStyle(.secondary)
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
        .frame(width: pet.windowSize.width, height: pet.windowSize.height, alignment: .bottom)
        .padding(.bottom, 8)
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

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            if session.state == .waiting {
                Button("Reply") {
                    SessionReplyController.shared.reply(to: session)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.orange.opacity(0.9)))
            }
        }
        .frame(width: 302, height: 44)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.black.opacity(0.86)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 6, y: 2)
    }

    private var title: String {
        session.project.map { ($0 as NSString).lastPathComponent } ?? session.id
    }

    private var subtitle: String {
        session.compactStatusText
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
