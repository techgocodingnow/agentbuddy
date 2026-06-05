import XCTest
@testable import AgentBuddyCore

final class StateMapperTests: XCTestCase {
    func testClaudeEventMapping() {
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: "SessionStart"), .registered)
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: "UserPromptSubmit"), .working)
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: "PreToolUse"), .working)
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: "PostToolUse"), .working)
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: "Notification"), .waiting)
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: "PermissionRequest"), .waiting)
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: "Elicitation"), .waiting)
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: "ElicitationResult"), .working)
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: "Stop"), .done)
        XCTAssertEqual(StateMapper.state(for: .claude, eventName: "SubagentStop"), .done)
    }

    func testUnknownEventIsIgnored() {
        XCTAssertNil(StateMapper.state(for: .claude, eventName: "Bogus"))
        XCTAssertNil(StateMapper.state(for: .codex, eventName: "Bogus"))
        XCTAssertNil(StateMapper.state(for: .unknown, eventName: "Stop"))
    }

    func testDirectStateNameMapsForAnyKind() {
        XCTAssertEqual(StateMapper.state(for: .cli, eventName: "working"), .working)
        XCTAssertEqual(StateMapper.state(for: .cli, eventName: "done"), .done)
        XCTAssertEqual(StateMapper.state(for: .unknown, eventName: "waiting"), .waiting)
    }

    func testCodexMapping() {
        XCTAssertEqual(StateMapper.state(for: .codex, eventName: "SessionStart"), .registered)
        XCTAssertEqual(StateMapper.state(for: .codex, eventName: "PreToolUse"), .working)
        XCTAssertEqual(StateMapper.state(for: .codex, eventName: "PostToolUse"), .working)
        XCTAssertEqual(StateMapper.state(for: .codex, eventName: "SubagentStart"), .working)
        XCTAssertEqual(StateMapper.state(for: .codex, eventName: "PermissionRequest"), .waiting)
        XCTAssertEqual(StateMapper.state(for: .codex, eventName: "item/tool/requestUserInput"), .waiting)
        XCTAssertEqual(StateMapper.state(for: .codex, eventName: "Stop"), .done)
    }

    func testGeminiMapping() {
        XCTAssertEqual(StateMapper.state(for: .gemini, eventName: "BeforeTool"), .working)
        XCTAssertEqual(StateMapper.state(for: .gemini, eventName: "Notification"), .waiting)
        XCTAssertEqual(StateMapper.state(for: .gemini, eventName: "AfterAgent"), .done)
    }

    func testHookSpecsCoverInstallEvents() {
        // Every event we register must either map to a state or end the session.
        for kind in [AgentKind.claude, .codex, .gemini] {
            let spec = AgentHooks.spec(for: kind)!
            for event in spec.events where !StateMapper.isSessionEnd(for: kind, eventName: event) {
                XCTAssertNotNil(StateMapper.state(for: kind, eventName: event), "\(kind) \(event)")
            }
        }
    }
}

final class SessionStoreTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func event(_ name: String, session: String = "s1", project: String? = "/proj",
                       usage: ContextUsage? = nil,
                       quotaUsage: AgentQuotaUsage? = nil,
                       stats: AgentRuntimeStats? = nil) -> AgentEvent {
        AgentEvent(sessionId: session, agentKind: .claude, eventName: name, project: project,
                   message: nil, timestamp: t0, usage: usage, quotaUsage: quotaUsage, stats: stats)
    }

    func testApplyStoresUsage() {
        let store = SessionStore()
        let usage = ContextUsage(usedTokens: 82_720, limitTokens: 200_000)
        let s = store.apply(event("SessionStart", usage: usage), now: t0)
        XCTAssertEqual(s?.usage, usage)
    }

    func testApplyPreservesUsageWhenEventHasNone() {
        let store = SessionStore()
        let usage = ContextUsage(usedTokens: 50_000, limitTokens: 200_000)
        store.apply(event("UserPromptSubmit", usage: usage), now: t0)
        // A later event carrying no usage must not erase the last known value.
        let updated = store.apply(event("Stop", usage: nil), now: t0.addingTimeInterval(5))
        XCTAssertEqual(updated?.state, .done)
        XCTAssertEqual(updated?.usage, usage)
    }

    func testApplyUpdatesUsageWhenEventHasNewer() {
        let store = SessionStore()
        store.apply(event("UserPromptSubmit", usage: ContextUsage(usedTokens: 50_000, limitTokens: 200_000)), now: t0)
        let newer = ContextUsage(usedTokens: 120_000, limitTokens: 200_000)
        let updated = store.apply(event("PreToolUse", usage: newer), now: t0.addingTimeInterval(5))
        XCTAssertEqual(updated?.usage, newer)
    }

    func testApplyStoresAndPreservesRuntimeStats() {
        let store = SessionStore()
        let stats = AgentRuntimeStats(model: "claude-opus-4-8", speed: "standard", serviceTier: "standard")
        store.apply(event("UserPromptSubmit", stats: stats), now: t0)

        let updated = store.apply(event("PreToolUse", stats: nil), now: t0.addingTimeInterval(5))

        XCTAssertEqual(updated?.stats, stats)
    }

    func testApplyStoresPendingRequestOnlyWhileWaiting() {
        let store = SessionStore()
        let pending = PendingAgentRequest(
            id: "p1",
            kind: .permission,
            actions: [.allow, .deny, .review],
            prompt: "Run tests?",
            responsePath: "/tmp/agentbuddy-response.json"
        )
        let waiting = AgentEvent(
            sessionId: "s1",
            agentKind: .claude,
            eventName: "PermissionRequest",
            project: "/proj",
            message: "Run tests?",
            timestamp: t0,
            pendingRequest: pending
        )

        let created = store.apply(waiting, now: t0)
        XCTAssertEqual(created?.pendingRequest, pending)

        let working = store.apply(event("PreToolUse"), now: t0.addingTimeInterval(1))
        XCTAssertNil(working?.pendingRequest)
    }

    func testResolvePendingRequestImmediatelyMarksSessionWorking() {
        let store = SessionStore()
        let pending = PendingAgentRequest(
            id: "p1",
            kind: .permission,
            actions: [.allow, .deny, .review],
            prompt: "Run tests?",
            responsePath: "/tmp/agentbuddy-response.json"
        )
        let waiting = AgentEvent(
            sessionId: "s1",
            agentKind: .claude,
            eventName: "PermissionRequest",
            project: "/proj",
            message: "Run tests?",
            timestamp: t0,
            pendingRequest: pending
        )
        store.apply(waiting, now: t0)

        let resolved = store.resolvePendingRequest(id: "s1", now: t0.addingTimeInterval(0.1))

        XCTAssertEqual(resolved?.state, .working)
        XCTAssertNil(resolved?.pendingRequest)
        XCTAssertNil(resolved?.message)
        XCTAssertEqual(resolved?.stateSince, t0.addingTimeInterval(0.1))
        XCTAssertEqual(store.session(id: "s1")?.pendingRequest, nil)
    }

    func testApplyStoresAndPreservesQuotaUsage() {
        let store = SessionStore()
        let quota = AgentQuotaUsage(sessionUsedPercent: 10, weeklyUsedPercent: 20)
        store.apply(event("UserPromptSubmit", quotaUsage: quota), now: t0)

        let updated = store.apply(event("PreToolUse", quotaUsage: nil), now: t0.addingTimeInterval(5))

        XCTAssertEqual(updated?.quotaUsage, quota)
    }

    func testApplyCreatesSession() {
        let store = SessionStore()
        let s = store.apply(event("SessionStart"), now: t0)
        XCTAssertEqual(s?.state, .registered)
        XCTAssertEqual(s?.project, "/proj")
        XCTAssertEqual(s?.source, .hook)
        XCTAssertEqual(store.sessions.count, 1)
    }

    func testApplyStoresExplicitTitle() {
        let store = SessionStore()
        let started = AgentEvent(
            sessionId: "s1",
            agentKind: .codex,
            eventName: "UserPromptSubmit",
            project: "/proj",
            title: "Assess Codex Pet clone idea",
            message: "Check the pet flow",
            timestamp: t0
        )

        let session = store.apply(started, now: t0)

        XCTAssertEqual(session?.title, "Assess Codex Pet clone idea")
        XCTAssertEqual(session?.displayTitle, "Assess Codex Pet clone idea")
    }

    func testApplyDerivesTitleFromFirstMessageAndPreservesIt() {
        let store = SessionStore()
        let prompt = AgentEvent(
            sessionId: "s1",
            agentKind: .codex,
            eventName: "UserPromptSubmit",
            project: "/proj",
            message: "Please assess the Codex Pet clone idea and report risk",
            timestamp: t0
        )
        store.apply(prompt, now: t0)

        let updated = store.apply(event("PreToolUse", project: nil), now: t0.addingTimeInterval(5))

        XCTAssertEqual(updated?.title, "assess the Codex Pet clone idea and report risk")
        XCTAssertEqual(updated?.message, "Please assess the Codex Pet clone idea and report risk")
    }

    func testApplyPreservesPromptTitleUntilAgentMessageArrives() {
        let store = SessionStore()
        let prompt = AgentEvent(
            sessionId: "s1",
            agentKind: .codex,
            eventName: "UserPromptSubmit",
            project: "/proj",
            title: "okay let me check",
            message: nil,
            timestamp: t0
        )
        store.apply(prompt, now: t0)

        let done = AgentEvent(
            sessionId: "s1",
            agentKind: .codex,
            eventName: "Stop",
            project: "/proj",
            message: "Sounds good. I will stay here while you check it.",
            timestamp: t0.addingTimeInterval(5)
        )
        let updated = store.apply(done, now: t0.addingTimeInterval(5))

        XCTAssertEqual(updated?.title, "okay let me check")
        XCTAssertEqual(updated?.displayMessage, "Sounds good. I will stay here while you check it.")
    }

    func testApplyDoesNotDeriveTitleFromWaitingMessage() {
        let store = SessionStore()
        let waiting = AgentEvent(
            sessionId: "s1",
            agentKind: .codex,
            eventName: "PermissionRequest",
            project: "/proj",
            message: "Needs approval",
            timestamp: t0
        )

        let session = store.apply(waiting, now: t0)

        XCTAssertNil(session?.title)
        XCTAssertEqual(session?.displayMessage, "Needs approval")
    }

    func testApplyUpdatesExistingAndKeepsProjectWhenNil() {
        let store = SessionStore()
        store.apply(event("SessionStart"), now: t0)
        let updated = store.apply(event("Stop", project: nil), now: t0.addingTimeInterval(5))
        XCTAssertEqual(updated?.state, .done)
        XCTAssertEqual(updated?.project, "/proj", "project should persist when event omits it")
        XCTAssertEqual(store.sessions.count, 1)
    }

    func testApplyPreservesMessageAcrossSameStateEvents() {
        let store = SessionStore()
        let prompt = AgentEvent(
            sessionId: "s1",
            agentKind: .claude,
            eventName: "UserPromptSubmit",
            project: "/proj",
            message: "Working on hook messages",
            timestamp: t0
        )
        store.apply(prompt, now: t0)

        let updated = store.apply(event("PreToolUse"), now: t0.addingTimeInterval(5))

        XCTAssertEqual(updated?.state, .working)
        XCTAssertEqual(updated?.message, "Working on hook messages")
    }

    func testApplyClearsMessageOnStateChangeWithoutNewMessage() {
        let store = SessionStore()
        let prompt = AgentEvent(
            sessionId: "s1",
            agentKind: .claude,
            eventName: "UserPromptSubmit",
            project: "/proj",
            message: "Working on hook messages",
            timestamp: t0
        )
        store.apply(prompt, now: t0)

        let updated = store.apply(event("Stop"), now: t0.addingTimeInterval(5))

        XCTAssertEqual(updated?.state, .done)
        XCTAssertNil(updated?.message)
    }

    func testApplyClearsTitleWhenSessionRegistersAgainWithoutTitle() {
        let store = SessionStore()
        let prompt = AgentEvent(
            sessionId: "s1",
            agentKind: .claude,
            eventName: "UserPromptSubmit",
            project: "/proj",
            message: "Working on hook messages",
            timestamp: t0
        )
        store.apply(prompt, now: t0)

        let updated = store.apply(event("SessionStart"), now: t0.addingTimeInterval(5))

        XCTAssertEqual(updated?.state, .registered)
        XCTAssertNil(updated?.message)
        XCTAssertNil(updated?.title)
    }

    func testApplyIgnoresUnmappedEvent() {
        let store = SessionStore()
        XCTAssertNil(store.apply(event("Bogus"), now: t0))
        XCTAssertEqual(store.sessions.count, 0)
    }

    func testPruneDemotesDoneToIdle() {
        let store = SessionStore(doneToIdleAfter: 30, removeIdleAfter: 600)
        store.apply(event("Stop"), now: t0)
        store.prune(now: t0.addingTimeInterval(10))
        XCTAssertEqual(store.session(id: "s1")?.state, .done, "still done before threshold")
        store.prune(now: t0.addingTimeInterval(40))
        XCTAssertEqual(store.session(id: "s1")?.state, .idle, "demoted to idle after threshold")
    }

    func testPruneRemovesLongIdle() {
        let store = SessionStore(doneToIdleAfter: 30, removeIdleAfter: 600)
        store.apply(event("Stop"), now: t0)
        store.prune(now: t0.addingTimeInterval(40))   // -> idle at t0+40
        store.prune(now: t0.addingTimeInterval(40 + 600))
        XCTAssertNil(store.session(id: "s1"), "removed after idle timeout")
    }

    func testPruneRemovesStaleActiveSession() {
        let store = SessionStore(staleActiveAfter: 300)
        store.apply(event("UserPromptSubmit"), now: t0)   // working
        store.prune(now: t0.addingTimeInterval(120))
        XCTAssertNotNil(store.session(id: "s1"), "kept before stale timeout")
        store.prune(now: t0.addingTimeInterval(300))
        XCTAssertNil(store.session(id: "s1"), "stale working session removed")
    }

    func testPruneRemovesStaleRegisteredSooner() {
        let store = SessionStore(staleActiveAfter: 300, staleRegisteredAfter: 90)
        store.apply(event("SessionStart"), now: t0)   // registered, never worked
        store.prune(now: t0.addingTimeInterval(60))
        XCTAssertNotNil(store.session(id: "s1"), "kept before registered timeout")
        store.prune(now: t0.addingTimeInterval(90))
        XCTAssertNil(store.session(id: "s1"), "idle registered session removed sooner than working")
    }

    func testClearRemovesAll() {
        let store = SessionStore()
        store.apply(event("UserPromptSubmit", session: "a"), now: t0)
        store.apply(event("UserPromptSubmit", session: "b"), now: t0)
        store.clear()
        XCTAssertTrue(store.sessions.isEmpty)
    }

    func testSortedByAttentionPriority() {
        let store = SessionStore()
        store.apply(event("UserPromptSubmit", session: "working"), now: t0)
        store.apply(event("Notification", session: "waiting"), now: t0)
        store.apply(event("Stop", session: "done"), now: t0)
        let order = store.sorted.map(\.id)
        XCTAssertEqual(order, ["waiting", "working", "done"])
    }
}
