import SwiftUI
import AgentBuddyCore

/// Compact context-window gauge: a thin capsule whose fill tracks remaining
/// headroom, plus a "<n>% left" label. Shown only for agents that report usage.
struct ContextUsageBar: View {
    let usage: ContextUsage
    var mode: UsageDisplayMode = .left

    private var displayPercent: Int {
        switch mode {
        case .left: return usage.percentLeft
        case .used: return usage.percentUsed
        }
    }

    private var color: Color {
        switch usage.percentLeft {
        case ..<15: return .red
        case 15...40: return .yellow
        default: return .green
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(displayPercent) / 100)
                }
            }
            .frame(height: 3)
            Text("\(displayPercent)% \(mode.rawValue)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize()
        }
    }
}
