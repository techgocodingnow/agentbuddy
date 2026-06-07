import XCTest
@testable import AgentBuddyCore

final class PetProgressTests: XCTestCase {
    func testEggHatchesAtThresholdAndStartsAtLevelOne() {
        var ledger = PetProgressLedger()
        let before = ledger.ingest(TokenProgress(totalTokens: 249_999), petID: "piglet", sessionKey: "claude:s1")
        let hatch = ledger.ingest(TokenProgress(totalTokens: 250_000), petID: "piglet", sessionKey: "claude:s1")

        XCTAssertEqual(before?.progress.isHatched, false)
        XCTAssertEqual(before?.progress.level, 0)
        XCTAssertEqual(hatch?.tokensAdded, 1)
        XCTAssertEqual(hatch?.didHatch, true)
        XCTAssertEqual(hatch?.progress.level, 1)
    }

    func testLevelsRequireMoreTokensAtHigherLevels() {
        XCTAssertEqual(PetProgress(totalTokens: 250_000).level, 1)
        XCTAssertEqual(PetProgress(totalTokens: 349_999).level, 1)
        XCTAssertEqual(PetProgress(totalTokens: 350_000).level, 2)
        XCTAssertEqual(PetProgress(totalTokens: 499_999).level, 2)
        XCTAssertEqual(PetProgress(totalTokens: 500_000).level, 3)
        XCTAssertEqual(PetProgress(totalTokens: 699_999).level, 3)
        XCTAssertEqual(PetProgress(totalTokens: 700_000).level, 4)
    }

    func testCurrentLevelProgressUsesIncreasingRequirements() {
        let levelOne = PetProgress(totalTokens: 300_000)
        XCTAssertEqual(levelOne.level, 1)
        XCTAssertEqual(levelOne.tokensIntoCurrentLevel, 50_000)
        XCTAssertEqual(levelOne.tokensRequiredForCurrentLevel, 100_000)
        XCTAssertEqual(levelOne.tokensUntilNextLevel, 50_000)

        let levelTwo = PetProgress(totalTokens: 425_000)
        XCTAssertEqual(levelTwo.level, 2)
        XCTAssertEqual(levelTwo.tokensIntoCurrentLevel, 75_000)
        XCTAssertEqual(levelTwo.tokensRequiredForCurrentLevel, 150_000)
        XCTAssertEqual(levelTwo.tokensUntilNextLevel, 75_000)
    }

    func testHatchStageBreakpointsAreBeforeHatchThreshold() {
        XCTAssertEqual(PetProgressRules.smallCrackTokens, 50_000)
        XCTAssertEqual(PetProgressRules.largeCrackTokens, 125_000)
        XCTAssertEqual(PetProgressRules.fragmentTokens, 200_000)
        XCTAssertLessThan(PetProgressRules.fragmentTokens, PetProgressRules.hatchTokens)
    }

    func testPerPetProgressIsIndependent() {
        var ledger = PetProgressLedger()
        ledger.ingest(TokenProgress(totalTokens: 6_000), petID: "alpha", sessionKey: "claude:s1")
        ledger.ingest(TokenProgress(totalTokens: 250_000), petID: "beta", sessionKey: "codex:s2")

        XCTAssertEqual(ledger.progress(for: "alpha").totalTokens, 6_000)
        XCTAssertEqual(ledger.progress(for: "beta").totalTokens, 250_000)
        XCTAssertFalse(ledger.progress(for: "alpha").isHatched)
        XCTAssertTrue(ledger.progress(for: "beta").isHatched)
    }

    func testPositiveDeltaAccountingPreventsDoubleCounting() {
        var ledger = PetProgressLedger()
        let first = ledger.ingest(TokenProgress(totalTokens: 5_000), petID: "alpha", sessionKey: "claude:s1")
        let replay = ledger.ingest(TokenProgress(totalTokens: 5_000), petID: "alpha", sessionKey: "claude:s1")
        let increment = ledger.ingest(TokenProgress(totalTokens: 7_500), petID: "alpha", sessionKey: "claude:s1")

        XCTAssertEqual(first?.tokensAdded, 5_000)
        XCTAssertNil(replay)
        XCTAssertEqual(increment?.tokensAdded, 2_500)
        XCTAssertEqual(ledger.progress(for: "alpha").totalTokens, 7_500)
    }

    func testSwitchingPetsDoesNotDoubleCountSessionTokens() {
        var ledger = PetProgressLedger()
        ledger.ingest(TokenProgress(totalTokens: 5_000), petID: "alpha", sessionKey: "codex:s1")
        ledger.ingest(TokenProgress(totalTokens: 8_000), petID: "beta", sessionKey: "codex:s1")
        ledger.ingest(TokenProgress(totalTokens: 9_000), petID: "alpha", sessionKey: "codex:s1")

        XCTAssertEqual(ledger.progress(for: "alpha").totalTokens, 6_000)
        XCTAssertEqual(ledger.progress(for: "beta").totalTokens, 3_000)
    }
}
