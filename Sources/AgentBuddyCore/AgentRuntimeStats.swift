import Foundation

/// Optional per-session runtime metadata surfaced by agent transcripts.
public struct AgentRuntimeStats: Codable, Sendable, Equatable {
    public var model: String?
    public var speed: String?
    public var serviceTier: String?
    public var effort: String?

    public init(model: String? = nil, speed: String? = nil, serviceTier: String? = nil, effort: String? = nil) {
        self.model = Self.cleaned(model)
        self.speed = Self.cleaned(speed)
        self.serviceTier = Self.cleaned(serviceTier)
        self.effort = Self.cleaned(effort)
    }

    public var isEmpty: Bool {
        model == nil && speed == nil && serviceTier == nil && effort == nil
    }

    public var displayParts: [String] {
        [
            model.map { shortModelName($0) },
            speed.map { "speed \($0)" },
            serviceTier.map { "tier \($0)" },
            effort.map { "effort \($0)" }
        ].compactMap { $0 }
    }

    public var compactModelLabel: String? {
        guard let model else { return nil }
        return compactModelName(model)
    }

    public var compactModeLabel: String? {
        if let speed {
            return titleCase(speed)
        }
        return serviceTier.map(titleCase)
    }

    public var compactDetailLabel: String? {
        if let effort {
            return titleCase(effort)
        }
        guard let serviceTier,
              serviceTier.localizedCaseInsensitiveCompare("standard") != .orderedSame else { return nil }
        return titleCase(serviceTier)
    }

    public var isFastLike: Bool {
        guard let speed = speed?.lowercased() else { return false }
        return speed.contains("fast") || speed.contains("high")
    }

    private static func cleaned(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    private func shortModelName(_ model: String) -> String {
        model
            .replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "gpt-", with: "")
    }

    private func compactModelName(_ model: String) -> String {
        let lowered = model.lowercased()
        let stripped = shortModelName(lowered)
        let parts = stripped.split(separator: "-").map(String.init)
        if let familyIndex = parts.firstIndex(where: { ["opus", "sonnet", "haiku"].contains($0) }) {
            let family = titleCase(parts[familyIndex])
            let afterFamily = parts[(familyIndex + 1)...]
                .prefix { $0.range(of: #"^\d+$"#, options: .regularExpression) != nil && $0.count <= 2 }
            let versionParts: ArraySlice<String>
            if afterFamily.isEmpty {
                versionParts = parts[..<familyIndex]
                    .filter { $0.range(of: #"^\d+$"#, options: .regularExpression) != nil && $0.count <= 2 }
                    .suffix(2)
            } else {
                versionParts = afterFamily.prefix(2)
            }
            guard !versionParts.isEmpty else { return family }
            return "\(family) \(versionParts.joined(separator: "."))"
        }
        let numeric = parts.filter { $0.range(of: #"^\d+(\.\d+)?$"#, options: .regularExpression) != nil }
        if numeric.count >= 2 {
            return numeric.prefix(2).joined(separator: ".")
        }
        if let version = numeric.first {
            return version
        }
        if lowered.contains("opus") { return "Opus" }
        if lowered.contains("sonnet") { return "Sonnet" }
        if lowered.contains("haiku") { return "Haiku" }
        return stripped
    }

    private func titleCase(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}
