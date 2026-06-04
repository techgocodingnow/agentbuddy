import XCTest
@testable import AgentBuddyCore

final class TaskSummaryTests: XCTestCase {
    func testCompactsPromptToShortTaskLine() {
        let summary = TaskSummary.compact(
            from: "Please implement the MVP version for compact-style pet task summaries in AgentBuddy"
        )

        XCTAssertEqual(summary, "implement the MVP version for compact-style pet task summaries")
    }

    func testStripsConversationalPrefix() {
        let summary = TaskSummary.compact(from: "ok let's do the MVP for this feature")

        XCTAssertEqual(summary, "the MVP for this feature")
    }

    func testReturnsNilForEmptyText() {
        XCTAssertNil(TaskSummary.compact(from: " \n\t "))
    }
}
