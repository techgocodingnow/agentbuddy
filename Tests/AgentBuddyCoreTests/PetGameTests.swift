import XCTest
@testable import AgentBuddyCore

final class PetGameTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ value: String) -> Date {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))!
    }

    private func event(
        _ name: String,
        session: String = "s1",
        kind: AgentKind = .claude,
        at timestamp: Date = Date()
    ) -> AgentEvent {
        AgentEvent(sessionId: session, agentKind: kind, eventName: name, timestamp: timestamp)
    }

    func testTokenDeltaCompletesDailyTokenQuest() {
        var ledger = PetGameLedger()
        let update = PetGameEngine.ingest(
            event: event("Stop"),
            progressUpdate: PetProgressUpdate(
                petID: "pig",
                tokensAdded: 50_000,
                progress: PetProgress(totalTokens: 50_000),
                didHatch: false
            ),
            selectedPetID: "pig",
            into: &ledger,
            now: date("2026-06-07"),
            calendar: calendar
        )

        let profile = ledger.profile(for: "pig", today: date("2026-06-07"), calendar: calendar)
        XCTAssertEqual(profile.daily.tokenBurned, 50_000)
        XCTAssertTrue(profile.daily.completedQuestIDs.contains(PetQuestID.tokensToday))
        XCTAssertEqual(update?.completedQuestIDs, [PetQuestID.tokensToday])
    }

    func testDoneEventsCompleteFinishSessionsQuestOncePerSession() {
        var ledger = PetGameLedger()
        for session in ["a", "a", "b", "c"] {
            _ = PetGameEngine.ingest(
                event: event("Stop", session: session),
                progressUpdate: nil,
                selectedPetID: "pig",
                into: &ledger,
                now: date("2026-06-07"),
                calendar: calendar
            )
        }

        let profile = ledger.profile(for: "pig", today: date("2026-06-07"), calendar: calendar)
        XCTAssertEqual(profile.daily.finishedSessions, 3)
        XCTAssertTrue(profile.daily.completedQuestIDs.contains(PetQuestID.finishSessions))
    }

    func testAnsweredPromptQuestTracksWaitingThenNonWaitingTransition() {
        var ledger = PetGameLedger()
        for session in ["a", "b"] {
            _ = PetGameEngine.ingest(
                event: event("Notification", session: session),
                progressUpdate: nil,
                selectedPetID: "pig",
                into: &ledger,
                now: date("2026-06-07"),
                calendar: calendar
            )
            _ = PetGameEngine.ingest(
                event: event("Stop", session: session),
                progressUpdate: nil,
                selectedPetID: "pig",
                into: &ledger,
                now: date("2026-06-07"),
                calendar: calendar
            )
        }

        let profile = ledger.profile(for: "pig", today: date("2026-06-07"), calendar: calendar)
        XCTAssertEqual(profile.daily.answeredPrompts, 2)
        XCTAssertTrue(profile.daily.completedQuestIDs.contains(PetQuestID.answerPrompts))
    }

    func testMultiAgentQuestAndAchievementUseClaudeAndCodexSameDay() {
        var ledger = PetGameLedger()
        _ = PetGameEngine.ingest(
            event: event("Stop", kind: .claude),
            progressUpdate: nil,
            selectedPetID: "pig",
            into: &ledger,
            now: date("2026-06-07"),
            calendar: calendar
        )
        let update = PetGameEngine.ingest(
            event: event("Stop", session: "s2", kind: .codex),
            progressUpdate: nil,
            selectedPetID: "pig",
            into: &ledger,
            now: date("2026-06-07"),
            calendar: calendar
        )

        let profile = ledger.profile(for: "pig", today: date("2026-06-07"), calendar: calendar)
        XCTAssertTrue(profile.daily.completedQuestIDs.contains(PetQuestID.multiAgent))
        XCTAssertTrue(profile.achievementIDs.contains(PetAchievementID.multiAgentDay))
        XCTAssertEqual(update?.completedQuestIDs, [PetQuestID.multiAgent])
    }

    func testDailyQuestProgressResetsByLocalDay() {
        var ledger = PetGameLedger()
        _ = PetGameEngine.ingest(
            event: event("Stop"),
            progressUpdate: PetProgressUpdate(petID: "pig", tokensAdded: 50_000, progress: PetProgress(totalTokens: 50_000), didHatch: false),
            selectedPetID: "pig",
            into: &ledger,
            now: date("2026-06-07"),
            calendar: calendar
        )

        let nextDay = ledger.profile(for: "pig", today: date("2026-06-08"), calendar: calendar)
        XCTAssertEqual(nextDay.daily.dayKey, "2026-06-08")
        XCTAssertEqual(nextDay.daily.tokenBurned, 0)
        XCTAssertTrue(nextDay.daily.completedQuestIDs.isEmpty)
    }

    func testPerPetGameProfilesAreIsolated() {
        var ledger = PetGameLedger()
        _ = PetGameEngine.ingest(
            event: event("Stop"),
            progressUpdate: PetProgressUpdate(petID: "alpha", tokensAdded: 50_000, progress: PetProgress(totalTokens: 50_000), didHatch: false),
            selectedPetID: "alpha",
            into: &ledger,
            now: date("2026-06-07"),
            calendar: calendar
        )
        _ = PetGameEngine.ingest(
            event: event("Stop"),
            progressUpdate: nil,
            selectedPetID: "beta",
            into: &ledger,
            now: date("2026-06-07"),
            calendar: calendar
        )

        XCTAssertTrue(ledger.profile(for: "alpha", today: date("2026-06-07"), calendar: calendar).daily.completedQuestIDs.contains(PetQuestID.tokensToday))
        XCTAssertFalse(ledger.profile(for: "beta", today: date("2026-06-07"), calendar: calendar).daily.completedQuestIDs.contains(PetQuestID.tokensToday))
    }

    func testCosmeticsUnlockAtExactLevelThresholds() {
        var ledger = PetGameLedger()
        let levelTwo = PetGameEngine.ingest(
            event: event("Stop"),
            progressUpdate: PetProgressUpdate(petID: "pig", tokensAdded: 350_000, progress: PetProgress(totalTokens: 350_000), didHatch: false),
            selectedPetID: "pig",
            into: &ledger,
            now: date("2026-06-07"),
            calendar: calendar
        )
        let profile = ledger.profile(for: "pig", today: date("2026-06-07"), calendar: calendar)

        XCTAssertTrue(profile.unlockedCosmeticIDs.contains(PetCosmeticID.softAura))
        XCTAssertFalse(profile.unlockedCosmeticIDs.contains(PetCosmeticID.sparkleTrail))
        XCTAssertEqual(levelTwo?.unlockedCosmeticIDs, [PetCosmeticID.softAura])
    }

    func testAchievementsFireOnceOnly() {
        var ledger = PetGameLedger()
        let first = PetGameEngine.ingest(
            event: event("Stop"),
            progressUpdate: PetProgressUpdate(petID: "pig", tokensAdded: 1_000_000, progress: PetProgress(totalTokens: 1_000_000), didHatch: true),
            selectedPetID: "pig",
            into: &ledger,
            now: date("2026-06-07"),
            calendar: calendar
        )
        let replay = PetGameEngine.ingest(
            event: event("Stop"),
            progressUpdate: PetProgressUpdate(petID: "pig", tokensAdded: 1, progress: PetProgress(totalTokens: 1_000_001), didHatch: false),
            selectedPetID: "pig",
            into: &ledger,
            now: date("2026-06-07"),
            calendar: calendar
        )

        XCTAssertTrue(first?.unlockedAchievementIDs.contains(PetAchievementID.firstHatch) == true)
        XCTAssertTrue(first?.unlockedAchievementIDs.contains(PetAchievementID.firstLevelUp) == true)
        XCTAssertTrue(first?.unlockedAchievementIDs.contains(PetAchievementID.millionTokens) == true)
        XCTAssertFalse(replay?.unlockedAchievementIDs.contains(PetAchievementID.millionTokens) == true)
    }

    func testFiveDayStreakAchievement() {
        var ledger = PetGameLedger()
        var latest: PetGameUpdate?
        for day in 7...11 {
            latest = PetGameEngine.ingest(
                event: event("Stop"),
                progressUpdate: PetProgressUpdate(petID: "pig", tokensAdded: 1, progress: PetProgress(totalTokens: day), didHatch: false),
                selectedPetID: "pig",
                into: &ledger,
                now: date("2026-06-\(String(format: "%02d", day))"),
                calendar: calendar
            )
        }

        let profile = ledger.profile(for: "pig", today: date("2026-06-11"), calendar: calendar)
        XCTAssertEqual(profile.codingStreakDays, 5)
        XCTAssertTrue(profile.achievementIDs.contains(PetAchievementID.fiveDayStreak))
        XCTAssertTrue(latest?.unlockedAchievementIDs.contains(PetAchievementID.fiveDayStreak) == true)
    }

    func testOldSavedGameProfileDecodesWithDefaults() throws {
        let data = #"{"unlockedCosmeticIDs":["soft-aura"]}"#.data(using: .utf8)!
        let profile = try JSONDecoder().decode(PetGameProfile.self, from: data)

        XCTAssertEqual(profile.unlockedCosmeticIDs, [PetCosmeticID.softAura])
        XCTAssertEqual(profile.lastKnownLevel, 0)
        XCTAssertEqual(profile.daily.activeQuestIDs, PetGameRules.dailyQuestIDs)
    }
}
