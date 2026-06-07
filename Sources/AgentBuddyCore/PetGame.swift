import Foundation

public enum PetCosmeticID {
    public static let softAura = "soft-aura"
    public static let sparkleTrail = "sparkle-trail"
    public static let goldenNameplate = "golden-nameplate"
    public static let idleGlow = "idle-glow"
    public static let hatchShimmer = "hatch-shimmer"
}

public struct PetCosmetic: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let unlockLevel: Int
}

public enum PetQuestID {
    public static let tokensToday = "daily.tokens.50k"
    public static let finishSessions = "daily.sessions.3"
    public static let answerPrompts = "daily.prompts.2"
    public static let multiAgent = "daily.multi-agent"
}

public struct PetQuest: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let target: Int
}

public enum PetAchievementID {
    public static let firstHatch = "first-hatch"
    public static let firstLevelUp = "first-level-up"
    public static let millionTokens = "million-tokens"
    public static let multiAgentDay = "multi-agent-day"
    public static let fiveDayStreak = "five-day-streak"
}

public struct PetAchievement: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
}

public struct PetReward: Codable, Sendable, Equatable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct PetGameUpdate: Sendable, Equatable {
    public let petID: String
    public var completedQuestIDs: [String] = []
    public var unlockedCosmeticIDs: [String] = []
    public var unlockedAchievementIDs: [String] = []
    public var didLevelUp = false
    public var newLevel: Int?
    public var reward: PetReward?

    public var hasCelebration: Bool {
        didLevelUp || reward != nil || !completedQuestIDs.isEmpty || !unlockedAchievementIDs.isEmpty
    }

    public init(
        petID: String,
        completedQuestIDs: [String] = [],
        unlockedCosmeticIDs: [String] = [],
        unlockedAchievementIDs: [String] = [],
        didLevelUp: Bool = false,
        newLevel: Int? = nil,
        reward: PetReward? = nil
    ) {
        self.petID = petID
        self.completedQuestIDs = completedQuestIDs
        self.unlockedCosmeticIDs = unlockedCosmeticIDs
        self.unlockedAchievementIDs = unlockedAchievementIDs
        self.didLevelUp = didLevelUp
        self.newLevel = newLevel
        self.reward = reward
    }
}

public struct PetDailyGameProgress: Codable, Sendable, Equatable {
    public var dayKey: String
    public var activeQuestIDs: [String]
    public var completedQuestIDs: Set<String>
    public var tokenBurned: Int
    public var finishedSessions: Int
    public var answeredPrompts: Int
    public var agentKindIDs: Set<String>
    public var finishedSessionKeys: Set<String>
    public var answeredPromptSessionKeys: Set<String>

    public init(
        dayKey: String,
        activeQuestIDs: [String] = PetGameRules.dailyQuestIDs,
        completedQuestIDs: Set<String> = [],
        tokenBurned: Int = 0,
        finishedSessions: Int = 0,
        answeredPrompts: Int = 0,
        agentKindIDs: Set<String> = [],
        finishedSessionKeys: Set<String> = [],
        answeredPromptSessionKeys: Set<String> = []
    ) {
        self.dayKey = dayKey
        self.activeQuestIDs = activeQuestIDs
        self.completedQuestIDs = completedQuestIDs
        self.tokenBurned = max(0, tokenBurned)
        self.finishedSessions = max(0, finishedSessions)
        self.answeredPrompts = max(0, answeredPrompts)
        self.agentKindIDs = agentKindIDs
        self.finishedSessionKeys = finishedSessionKeys
        self.answeredPromptSessionKeys = answeredPromptSessionKeys
    }
}

public struct PetGameProfile: Codable, Sendable, Equatable {
    public var unlockedCosmeticIDs: Set<String>
    public var equippedCosmeticID: String?
    public var completedQuestIDs: Set<String>
    public var achievementIDs: Set<String>
    public var lastRewardCelebrationID: String?
    public var lastKnownLevel: Int
    public var lastKnownTokens: Int
    public var codingStreakDays: Int
    public var lastActiveDayKey: String?
    public var waitingSessionKeys: Set<String>
    public var daily: PetDailyGameProgress

    public init(
        unlockedCosmeticIDs: Set<String> = [],
        equippedCosmeticID: String? = nil,
        completedQuestIDs: Set<String> = [],
        achievementIDs: Set<String> = [],
        lastRewardCelebrationID: String? = nil,
        lastKnownLevel: Int = 0,
        lastKnownTokens: Int = 0,
        codingStreakDays: Int = 0,
        lastActiveDayKey: String? = nil,
        waitingSessionKeys: Set<String> = [],
        daily: PetDailyGameProgress
    ) {
        self.unlockedCosmeticIDs = unlockedCosmeticIDs
        self.equippedCosmeticID = equippedCosmeticID
        self.completedQuestIDs = completedQuestIDs
        self.achievementIDs = achievementIDs
        self.lastRewardCelebrationID = lastRewardCelebrationID
        self.lastKnownLevel = max(0, lastKnownLevel)
        self.lastKnownTokens = max(0, lastKnownTokens)
        self.codingStreakDays = max(0, codingStreakDays)
        self.lastActiveDayKey = lastActiveDayKey
        self.waitingSessionKeys = waitingSessionKeys
        self.daily = daily
    }

    private enum CodingKeys: String, CodingKey {
        case unlockedCosmeticIDs, equippedCosmeticID, completedQuestIDs, achievementIDs
        case lastRewardCelebrationID, lastKnownLevel, lastKnownTokens, codingStreakDays
        case lastActiveDayKey, waitingSessionKeys, daily
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        unlockedCosmeticIDs = try values.decodeIfPresent(Set<String>.self, forKey: .unlockedCosmeticIDs) ?? []
        equippedCosmeticID = try values.decodeIfPresent(String.self, forKey: .equippedCosmeticID)
        completedQuestIDs = try values.decodeIfPresent(Set<String>.self, forKey: .completedQuestIDs) ?? []
        achievementIDs = try values.decodeIfPresent(Set<String>.self, forKey: .achievementIDs) ?? []
        lastRewardCelebrationID = try values.decodeIfPresent(String.self, forKey: .lastRewardCelebrationID)
        lastKnownLevel = try values.decodeIfPresent(Int.self, forKey: .lastKnownLevel) ?? 0
        lastKnownTokens = try values.decodeIfPresent(Int.self, forKey: .lastKnownTokens) ?? 0
        codingStreakDays = try values.decodeIfPresent(Int.self, forKey: .codingStreakDays) ?? 0
        lastActiveDayKey = try values.decodeIfPresent(String.self, forKey: .lastActiveDayKey)
        waitingSessionKeys = try values.decodeIfPresent(Set<String>.self, forKey: .waitingSessionKeys) ?? []
        daily = try values.decodeIfPresent(PetDailyGameProgress.self, forKey: .daily)
            ?? PetDailyGameProgress(dayKey: PetGameRules.dayKey(for: Date()))
    }
}

public struct PetGameLedger: Codable, Sendable, Equatable {
    public private(set) var byPetID: [String: PetGameProfile]

    public init(byPetID: [String: PetGameProfile] = [:]) {
        self.byPetID = byPetID
    }

    public func profile(for petID: String?, today: Date = Date(), calendar: Calendar = .current) -> PetGameProfile {
        let dayKey = PetGameRules.dayKey(for: today, calendar: calendar)
        guard let petID, let profile = byPetID[petID] else {
            return PetGameProfile(daily: PetDailyGameProgress(dayKey: dayKey))
        }
        return PetGameRules.profile(profile, preparedFor: dayKey)
    }

    public mutating func setProfile(_ profile: PetGameProfile, for petID: String) {
        byPetID[petID] = profile
    }
}

public enum PetGameRules {
    public static let dailyQuestIDs = [
        PetQuestID.tokensToday,
        PetQuestID.finishSessions,
        PetQuestID.answerPrompts,
        PetQuestID.multiAgent,
    ]

    public static let quests: [PetQuest] = [
        PetQuest(id: PetQuestID.tokensToday, title: "Burn 50k tokens today", target: 50_000),
        PetQuest(id: PetQuestID.finishSessions, title: "Finish 3 agent sessions", target: 3),
        PetQuest(id: PetQuestID.answerPrompts, title: "Answer 2 waiting prompts", target: 2),
        PetQuest(id: PetQuestID.multiAgent, title: "Use Claude and Codex today", target: 2),
    ]

    public static let cosmetics: [PetCosmetic] = [
        PetCosmetic(id: PetCosmeticID.softAura, name: "Soft Aura", unlockLevel: 2),
        PetCosmetic(id: PetCosmeticID.sparkleTrail, name: "Sparkle Trail", unlockLevel: 3),
        PetCosmetic(id: PetCosmeticID.goldenNameplate, name: "Golden Nameplate", unlockLevel: 5),
        PetCosmetic(id: PetCosmeticID.idleGlow, name: "Idle Glow", unlockLevel: 8),
        PetCosmetic(id: PetCosmeticID.hatchShimmer, name: "Hatch Shimmer", unlockLevel: 12),
    ]

    public static let achievements: [PetAchievement] = [
        PetAchievement(id: PetAchievementID.firstHatch, title: "First Hatch"),
        PetAchievement(id: PetAchievementID.firstLevelUp, title: "First Level Up"),
        PetAchievement(id: PetAchievementID.millionTokens, title: "1M Local Tokens"),
        PetAchievement(id: PetAchievementID.multiAgentDay, title: "Multi-Agent Day"),
        PetAchievement(id: PetAchievementID.fiveDayStreak, title: "Five-Day Coding Streak"),
    ]

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 1970
        let month = parts.month ?? 1
        let day = parts.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func profile(_ profile: PetGameProfile, preparedFor dayKey: String) -> PetGameProfile {
        guard profile.daily.dayKey != dayKey else { return profile }
        var prepared = profile
        prepared.daily = PetDailyGameProgress(dayKey: dayKey)
        return prepared
    }

    public static func questProgress(_ questID: String, in profile: PetGameProfile) -> Int {
        switch questID {
        case PetQuestID.tokensToday:
            return min(profile.daily.tokenBurned, questTarget(questID))
        case PetQuestID.finishSessions:
            return min(profile.daily.finishedSessions, questTarget(questID))
        case PetQuestID.answerPrompts:
            return min(profile.daily.answeredPrompts, questTarget(questID))
        case PetQuestID.multiAgent:
            let hasClaude = profile.daily.agentKindIDs.contains(AgentKind.claude.rawValue)
            let hasCodex = profile.daily.agentKindIDs.contains(AgentKind.codex.rawValue)
            return (hasClaude ? 1 : 0) + (hasCodex ? 1 : 0)
        default:
            return 0
        }
    }

    public static func questTarget(_ questID: String) -> Int {
        quests.first { $0.id == questID }?.target ?? 1
    }

    static func consecutiveDayCount(previousDayKey: String?, newDayKey: String, currentStreak: Int, calendar: Calendar) -> Int {
        guard let previousDayKey, previousDayKey != newDayKey else {
            return max(1, currentStreak)
        }
        guard let previous = date(from: previousDayKey, calendar: calendar),
              let current = date(from: newDayKey, calendar: calendar) else {
            return 1
        }
        let delta = calendar.dateComponents([.day], from: previous, to: current).day ?? 0
        if delta == 1 { return max(1, currentStreak) + 1 }
        if delta == 0 { return max(1, currentStreak) }
        return 1
    }

    private static func date(from dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

public enum PetGameEngine {
    public static func syncExistingProgress(
        progressLedger: PetProgressLedger,
        into gameLedger: inout PetGameLedger,
        today: Date = Date(),
        calendar: Calendar = .current
    ) {
        let dayKey = PetGameRules.dayKey(for: today, calendar: calendar)
        for (petID, progress) in progressLedger.byPetID {
            var profile = PetGameRules.profile(gameLedger.profile(for: petID, today: today, calendar: calendar), preparedFor: dayKey)
            var ignoredUpdate = PetGameUpdate(petID: petID)
            applyProgress(progress, to: &profile, update: &ignoredUpdate)
            unlockAchievements(in: &profile, update: &ignoredUpdate)
            gameLedger.setProfile(profile, for: petID)
        }
    }

    @discardableResult
    public static func ingest(
        event: AgentEvent,
        progressUpdate: PetProgressUpdate?,
        selectedPetID: String?,
        into gameLedger: inout PetGameLedger,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PetGameUpdate? {
        guard let petID = progressUpdate?.petID ?? selectedPetID, !petID.isEmpty else { return nil }
        let dayKey = PetGameRules.dayKey(for: now, calendar: calendar)
        var profile = PetGameRules.profile(gameLedger.profile(for: petID, today: now, calendar: calendar), preparedFor: dayKey)
        var update = PetGameUpdate(petID: petID)

        if let progressUpdate {
            profile.daily.tokenBurned += progressUpdate.tokensAdded
            if progressUpdate.tokensAdded > 0 {
                profile.codingStreakDays = PetGameRules.consecutiveDayCount(
                    previousDayKey: profile.lastActiveDayKey,
                    newDayKey: dayKey,
                    currentStreak: profile.codingStreakDays,
                    calendar: calendar
                )
                profile.lastActiveDayKey = dayKey
            }
            applyProgress(progressUpdate.progress, to: &profile, update: &update)
        }

        applyEvent(event, to: &profile)
        completeQuests(in: &profile, update: &update)
        unlockAchievements(in: &profile, update: &update)
        chooseReward(for: &update)
        profile.lastRewardCelebrationID = update.reward?.id ?? profile.lastRewardCelebrationID

        gameLedger.setProfile(profile, for: petID)
        return update.hasCelebration ? update : nil
    }

    private static func applyProgress(_ progress: PetProgress, to profile: inout PetGameProfile, update: inout PetGameUpdate) {
        let oldLevel = profile.lastKnownLevel
        profile.lastKnownLevel = max(profile.lastKnownLevel, progress.level)
        profile.lastKnownTokens = max(profile.lastKnownTokens, progress.totalTokens)

        if progress.level > oldLevel {
            update.didLevelUp = oldLevel > 0
            update.newLevel = progress.level
        }

        for cosmetic in PetGameRules.cosmetics where progress.level >= cosmetic.unlockLevel {
            if profile.unlockedCosmeticIDs.insert(cosmetic.id).inserted {
                if profile.equippedCosmeticID == nil {
                    profile.equippedCosmeticID = cosmetic.id
                }
                update.unlockedCosmeticIDs.append(cosmetic.id)
            }
        }
    }

    private static func applyEvent(_ event: AgentEvent, to profile: inout PetGameProfile) {
        profile.daily.agentKindIDs.insert(event.agentKind.rawValue)
        let sessionKey = "\(event.agentKind.rawValue):\(event.sessionId)"
        guard let state = StateMapper.state(for: event.agentKind, eventName: event.eventName) else { return }

        if state == .waiting {
            profile.waitingSessionKeys.insert(sessionKey)
            return
        }

        if state == .done, profile.daily.finishedSessionKeys.insert(sessionKey).inserted {
            profile.daily.finishedSessions += 1
        }

        if state != .waiting,
           profile.waitingSessionKeys.remove(sessionKey) != nil,
           profile.daily.answeredPromptSessionKeys.insert(sessionKey).inserted {
            profile.daily.answeredPrompts += 1
        }
    }

    private static func completeQuests(in profile: inout PetGameProfile, update: inout PetGameUpdate) {
        for questID in profile.daily.activeQuestIDs {
            guard !profile.daily.completedQuestIDs.contains(questID) else { continue }
            guard PetGameRules.questProgress(questID, in: profile) >= PetGameRules.questTarget(questID) else { continue }
            profile.daily.completedQuestIDs.insert(questID)
            profile.completedQuestIDs.insert(questID)
            update.completedQuestIDs.append(questID)
        }
    }

    private static func unlockAchievements(in profile: inout PetGameProfile, update: inout PetGameUpdate) {
        unlock(PetAchievementID.firstHatch, when: profile.lastKnownLevel >= 1, profile: &profile, update: &update)
        unlock(PetAchievementID.firstLevelUp, when: profile.lastKnownLevel >= 2, profile: &profile, update: &update)
        unlock(PetAchievementID.millionTokens, when: profile.lastKnownTokens >= 1_000_000, profile: &profile, update: &update)
        unlock(PetAchievementID.multiAgentDay, when: profile.daily.completedQuestIDs.contains(PetQuestID.multiAgent), profile: &profile, update: &update)
        unlock(PetAchievementID.fiveDayStreak, when: profile.codingStreakDays >= 5, profile: &profile, update: &update)
    }

    private static func unlock(
        _ achievementID: String,
        when condition: Bool,
        profile: inout PetGameProfile,
        update: inout PetGameUpdate
    ) {
        guard condition, profile.achievementIDs.insert(achievementID).inserted else { return }
        update.unlockedAchievementIDs.append(achievementID)
    }

    private static func chooseReward(for update: inout PetGameUpdate) {
        if let cosmeticID = update.unlockedCosmeticIDs.first,
           let cosmetic = PetGameRules.cosmetics.first(where: { $0.id == cosmeticID }) {
            update.reward = PetReward(id: cosmetic.id, title: "\(cosmetic.name) unlocked")
        } else if update.didLevelUp, let level = update.newLevel {
            update.reward = PetReward(id: "level-\(level)", title: "Level \(level)")
        } else if let questID = update.completedQuestIDs.first,
                  let quest = PetGameRules.quests.first(where: { $0.id == questID }) {
            update.reward = PetReward(id: quest.id, title: quest.title)
        } else if let achievementID = update.unlockedAchievementIDs.first,
                  let achievement = PetGameRules.achievements.first(where: { $0.id == achievementID }) {
            update.reward = PetReward(id: achievement.id, title: achievement.title)
        }
    }
}
