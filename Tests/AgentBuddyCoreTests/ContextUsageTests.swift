import XCTest
@testable import AgentBuddyCore

final class ContextUsageTests: XCTestCase {
    func testPercentLeftRoundsToNearest() {
        // 82,720 / 200,000 used -> 58.64% left -> 59.
        let usage = ContextUsage(usedTokens: 82_720, limitTokens: 200_000)
        XCTAssertEqual(usage.percentLeft, 59)
    }

    func testPercentLeftIsFullWhenUnused() {
        XCTAssertEqual(ContextUsage(usedTokens: 0, limitTokens: 200_000).percentLeft, 100)
    }

    func testPercentLeftClampsWhenOverLimit() {
        // Context can momentarily exceed the window before auto-compaction.
        XCTAssertEqual(ContextUsage(usedTokens: 250_000, limitTokens: 200_000).percentLeft, 0)
    }

    func testPercentLeftZeroWhenNoLimit() {
        XCTAssertEqual(ContextUsage(usedTokens: 10, limitTokens: 0).percentLeft, 0)
    }

    func testContextWindowDefaultLimit() {
        XCTAssertEqual(ContextWindow.limit(forModel: "claude-opus-4-8"), 200_000)
        XCTAssertEqual(ContextWindow.limit(forModel: nil), 200_000)
    }
}
