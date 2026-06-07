import Foundation

/// Cumulative token count reported by a local agent transcript for one session.
public struct TokenProgress: Codable, Sendable, Equatable {
    public let totalTokens: Int

    public init(totalTokens: Int) {
        self.totalTokens = max(0, totalTokens)
    }
}

public enum PetProgressRules {
    public static let smallCrackTokens = 50_000
    public static let largeCrackTokens = 125_000
    public static let fragmentTokens = 200_000
    public static let hatchTokens = 250_000
    public static let firstLevelRequirementTokens = 100_000
    public static let levelRequirementGrowthTokens = 50_000

    public static func level(for totalTokens: Int) -> Int {
        guard totalTokens >= hatchTokens else { return 0 }
        var level = 1
        var remaining = totalTokens - hatchTokens
        while remaining >= tokensRequiredToAdvance(from: level) {
            remaining -= tokensRequiredToAdvance(from: level)
            level += 1
        }
        return level
    }

    public static func hatchProgressPercent(for totalTokens: Int) -> Int {
        guard hatchTokens > 0 else { return 100 }
        let clamped = max(0, min(totalTokens, hatchTokens))
        return Int((Double(clamped) / Double(hatchTokens) * 100).rounded())
    }

    public static func tokensRequiredToAdvance(from level: Int) -> Int {
        guard level > 0 else { return hatchTokens }
        return firstLevelRequirementTokens + max(0, level - 1) * levelRequirementGrowthTokens
    }

    public static func levelProgress(for totalTokens: Int) -> (level: Int, tokensIntoLevel: Int, tokensRequired: Int) {
        guard totalTokens >= hatchTokens else {
            return (0, max(0, totalTokens), hatchTokens)
        }
        var level = 1
        var remaining = totalTokens - hatchTokens
        var required = tokensRequiredToAdvance(from: level)
        while remaining >= required {
            remaining -= required
            level += 1
            required = tokensRequiredToAdvance(from: level)
        }
        return (level, remaining, required)
    }
}

public struct PetProgress: Codable, Sendable, Equatable {
    public var totalTokens: Int

    public init(totalTokens: Int = 0) {
        self.totalTokens = max(0, totalTokens)
    }

    public var isHatched: Bool {
        totalTokens >= PetProgressRules.hatchTokens
    }

    public var level: Int {
        PetProgressRules.level(for: totalTokens)
    }

    public var hatchProgressPercent: Int {
        PetProgressRules.hatchProgressPercent(for: totalTokens)
    }

    public var tokensUntilHatch: Int {
        max(0, PetProgressRules.hatchTokens - totalTokens)
    }

    public var tokensIntoCurrentLevel: Int {
        PetProgressRules.levelProgress(for: totalTokens).tokensIntoLevel
    }

    public var tokensRequiredForCurrentLevel: Int {
        PetProgressRules.levelProgress(for: totalTokens).tokensRequired
    }

    public var tokensUntilNextLevel: Int {
        max(0, tokensRequiredForCurrentLevel - tokensIntoCurrentLevel)
    }
}

public struct PetProgressUpdate: Sendable, Equatable {
    public let petID: String
    public let tokensAdded: Int
    public let progress: PetProgress
    public let didHatch: Bool
}

/// Persistent, per-pet progression plus per-session high-water marks.
///
/// Session high-water marks are global instead of per-pet so switching pets
/// mid-session cannot double-count the same locally reported tokens.
public struct PetProgressLedger: Codable, Sendable, Equatable {
    public private(set) var byPetID: [String: PetProgress]
    public private(set) var sessionHighWater: [String: Int]

    public init(
        byPetID: [String: PetProgress] = [:],
        sessionHighWater: [String: Int] = [:]
    ) {
        self.byPetID = byPetID
        self.sessionHighWater = sessionHighWater
    }

    public func progress(for petID: String?) -> PetProgress {
        guard let petID else { return PetProgress() }
        return byPetID[petID] ?? PetProgress()
    }

    @discardableResult
    public mutating func ingest(
        _ progress: TokenProgress,
        petID: String?,
        sessionKey: String
    ) -> PetProgressUpdate? {
        guard let petID, !petID.isEmpty else { return nil }
        let previousSessionTotal = sessionHighWater[sessionKey] ?? 0
        let newSessionTotal = max(previousSessionTotal, progress.totalTokens)
        sessionHighWater[sessionKey] = newSessionTotal

        let delta = max(0, progress.totalTokens - previousSessionTotal)
        guard delta > 0 else { return nil }

        let before = byPetID[petID] ?? PetProgress()
        var after = before
        after.totalTokens += delta
        byPetID[petID] = after

        return PetProgressUpdate(
            petID: petID,
            tokensAdded: delta,
            progress: after,
            didHatch: !before.isHatched && after.isHatched
        )
    }
}
