import XCTest
import AgentBuddyCore
@testable import agentbuddy

@MainActor
final class PetGameStoreTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let suiteName = "agentbuddy-game-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testBootstrapsCosmeticsFromExistingProgressLedger() {
        var progressLedger = PetProgressLedger()
        progressLedger.ingest(
            TokenProgress(totalTokens: 350_000),
            petID: "pig",
            sessionKey: "claude:s1"
        )
        let store = PetGameStore(defaults: defaults(), progressLedger: progressLedger)

        let profile = store.profile(for: "pig")
        XCTAssertTrue(profile.unlockedCosmeticIDs.contains(PetCosmeticID.softAura))
        XCTAssertEqual(profile.equippedCosmeticID, PetCosmeticID.softAura)
        XCTAssertTrue(profile.achievementIDs.contains(PetAchievementID.firstHatch))
        XCTAssertTrue(profile.achievementIDs.contains(PetAchievementID.firstLevelUp))
    }

    func testCosmeticPickerPersistsEquippedCosmetic() {
        var progressLedger = PetProgressLedger()
        progressLedger.ingest(
            TokenProgress(totalTokens: 500_000),
            petID: "pig",
            sessionKey: "claude:s1"
        )
        let defaults = defaults()
        let first = PetGameStore(defaults: defaults, progressLedger: progressLedger)
        first.setEquippedCosmeticID(PetCosmeticID.sparkleTrail, for: "pig")

        let second = PetGameStore(defaults: defaults, progressLedger: PetProgressLedger())
        XCTAssertEqual(second.profile(for: "pig").equippedCosmeticID, PetCosmeticID.sparkleTrail)
    }

    func testLevelUpCelebrationSetsShortLivedPresentationState() {
        let controller = PetController.shared
        controller.celebrateGameUpdate(
            PetGameUpdate(
                petID: "pig",
                didLevelUp: true,
                newLevel: 2,
                reward: PetReward(id: "level-2", title: "Level 2")
            )
        )

        XCTAssertNotNil(controller.levelUpStartedAt)
        XCTAssertEqual(controller.rewardLabel, "Level 2")
    }
}
