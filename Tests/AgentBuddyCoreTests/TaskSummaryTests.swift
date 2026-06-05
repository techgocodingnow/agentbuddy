import XCTest
@testable import AgentBuddyCore

final class TaskSummaryTests: XCTestCase {
    func testCompactsPromptToShortTitleLine() {
        let summary = TaskSummary.compact(
            from: "Please implement the MVP version for compact prompt titles in AgentBuddy"
        )

        XCTAssertEqual(summary, "implement the MVP version for compact prompt titles in")
    }

    func testStripsConversationalPrefix() {
        let summary = TaskSummary.compact(from: "ok let's do the MVP for this feature")

        XCTAssertEqual(summary, "the MVP for this feature")
    }

    func testReturnsNilForEmptyText() {
        XCTAssertNil(TaskSummary.compact(from: " \n\t "))
    }
}
