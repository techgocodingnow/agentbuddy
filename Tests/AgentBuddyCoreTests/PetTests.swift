import XCTest
@testable import AgentBuddyCore

final class MoodResolverTests: XCTestCase {
    private func session(_ state: AgentState, id: String, agentKind: AgentKind = .claude) -> AgentSession {
        AgentSession(id: id, agentKind: agentKind, state: state, source: .hook,
                     updatedAt: Date(timeIntervalSince1970: 0))
    }

    func testEmptyIsIdle() {
        XCTAssertEqual(MoodResolver.aggregate([]), .idle)
    }

    func testWaitingWins() {
        let sessions = [session(.working, id: "a"), session(.waiting, id: "b"), session(.done, id: "c")]
        XCTAssertEqual(MoodResolver.aggregate(sessions), .waiting, "waiting work needs user attention first")
    }

    func testWaitingBeatsDone() {
        XCTAssertEqual(MoodResolver.aggregate([session(.done, id: "a"), session(.waiting, id: "b")]), .waiting)
    }

    func testRegisteredIsNotWorking() {
        // An agent that is merely open (registered) but not doing anything keeps
        // the pet idle, not "working".
        XCTAssertEqual(MoodResolver.aggregate([session(.registered, id: "a")]), .idle)
        XCTAssertEqual(MoodResolver.aggregate([session(.registered, id: "a"), session(.working, id: "b")]), .working)
    }

    func testDoneOnly() {
        XCTAssertEqual(MoodResolver.aggregate([session(.done, id: "a"), session(.idle, id: "b")]), .done)
    }
}

final class AgentSessionSummaryTests: XCTestCase {
    private func session(
        _ state: AgentState,
        id: String,
        agentKind: AgentKind,
        updatedAt: TimeInterval = 0
    ) -> AgentSession {
        AgentSession(
            id: id,
            agentKind: agentKind,
            state: state,
            source: .hook,
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }

    func testEmptySummaryIsNil() {
        XCTAssertNil(AgentSessionSummary.compact(for: []))
    }

    func testRegisteredAndIdleAreExcluded() {
        let sessions = [
            session(.registered, id: "registered", agentKind: .claude),
            session(.idle, id: "idle", agentKind: .codex)
        ]

        XCTAssertNil(AgentSessionSummary.compact(for: sessions))
    }

    func testFewActiveSessionsUseNamedPrioritySummary() {
        let sessions = [
            session(.working, id: "claude-working", agentKind: .claude, updatedAt: 2),
            session(.waiting, id: "codex-waiting", agentKind: .codex, updatedAt: 1)
        ]

        XCTAssertEqual(AgentSessionSummary.compact(for: sessions), "Codex waiting - Claude working")
    }

    func testCrowdedSessionsCollapseToCounts() {
        let sessions = [
            session(.waiting, id: "codex-waiting", agentKind: .codex),
            session(.working, id: "claude-working", agentKind: .claude),
            session(.working, id: "gemini-working", agentKind: .gemini),
            session(.done, id: "cursor-done", agentKind: .cursor)
        ]

        XCTAssertEqual(AgentSessionSummary.compact(for: sessions), "1 waiting - 2 working - 1 done")
    }

    func testCountSummaryOmitsZeroGroups() {
        let sessions = [
            session(.working, id: "claude-working", agentKind: .claude),
            session(.working, id: "codex-working", agentKind: .codex),
            session(.working, id: "gemini-working", agentKind: .gemini)
        ]

        XCTAssertEqual(AgentSessionSummary.compact(for: sessions), "3 working")
    }

    func testDetailLimitIsClamped() {
        let sessions = [
            session(.waiting, id: "codex-waiting", agentKind: .codex)
        ]

        XCTAssertEqual(AgentSessionSummary.compact(for: sessions, detailLimit: 0), "Codex waiting")
    }

    func testCompactStatusTextIgnoresRawHookMessage() {
        let session = AgentSession(
            id: "codex-working",
            agentKind: .codex,
            state: .working,
            message: "Using AskUserQuestion",
            source: .hook,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(session.compactStatusText, "Codex working")
    }

    func testDisplayMessageKeepsWorkingProgressMessage() {
        let session = AgentSession(
            id: "codex-working",
            agentKind: .codex,
            state: .working,
            message: "Reviewing the hook flow",
            source: .hook,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(session.displayMessage, "Reviewing the hook flow")
    }

    func testDisplayTitleTrimsTitle() {
        let session = AgentSession(
            id: "codex-working",
            agentKind: .codex,
            title: "  Assess Codex Pet clone idea  ",
            state: .working,
            source: .hook,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(session.displayTitle, "Assess Codex Pet clone idea")
    }

    func testDisplayMessageKeepsHumanFacingStates() {
        let waiting = AgentSession(
            id: "codex-waiting",
            agentKind: .codex,
            state: .waiting,
            message: "  Needs approval  ",
            source: .hook,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let done = AgentSession(
            id: "codex-done",
            agentKind: .codex,
            state: .done,
            message: "Finished the patch.",
            source: .hook,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(waiting.displayMessage, "Needs approval")
        XCTAssertEqual(done.displayMessage, "Finished the patch.")
    }
}
