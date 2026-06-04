# Roadmap: AgentPet Multi-Session Companion

**Created:** 2026-06-04
**Milestone:** v1 - Compact Multi-Session Pet Summary

## Summary

This roadmap implements the approved one-pet, many-sessions behavior as a brownfield enhancement. The current app already stores multiple sessions and renders one pet; the work is to formalize aggregate priority, generate compact summary text, wire that summary into the pet/menu surfaces, and verify behavior.

## Phase Overview

| Phase | Name | Status | Requirements |
|-------|------|--------|--------------|
| 1 | Core Aggregation and Summary Model | Pending | AGG-01, AGG-02, AGG-03, AGG-04, SUM-01, SUM-02, SUM-03, SUM-04, SUM-05, TEST-01, TEST-02 |
| 2 | Pet and Menu Bar UX Wiring | Pending | UX-01, UX-02, UX-03, UX-04 |
| 3 | Verification and Polish | Pending | TEST-03, TEST-04 |

## Phase 1: Core Aggregation and Summary Model

**Goal:** Build deterministic, testable aggregation and summary logic that can be consumed by pet and menu UI.

**Why first:** The current mood resolver is pure and testable. Fixing priority and summary behavior in core code prevents UI-specific duplication.

**Requirements:** AGG-01, AGG-02, AGG-03, AGG-04, SUM-01, SUM-02, SUM-03, SUM-04, SUM-05, TEST-01, TEST-02

**Likely files:**
- `Sources/AgentPetCore/PetMood.swift`
- `Sources/AgentPetCore/AgentSession.swift`
- `Sources/AgentPetCore/AgentState.swift`
- `Tests/AgentPetCoreTests/PetTests.swift`
- `Tests/AgentPetCoreTests/SessionStoreTests.swift`

**Deliverables:**
- Waiting-over-working aggregate priority.
- Compact summary model/function with bounded output.
- Unit tests for mixed states, named detail summaries, count summaries, and no-active-session behavior.

**Risks:**
- Changing mood priority can alter existing expectations. Update tests and confirm intended UX.
- Summary text should avoid depending on localized UI labels unless that is deliberate.

## Phase 2: Pet and Menu Bar UX Wiring

**Goal:** Make the compact multi-session summary visible in the one-pet experience while preserving detailed per-session menu rows.

**Why second:** UI should consume the Phase 1 model rather than reimplementing aggregation.

**Requirements:** UX-01, UX-02, UX-03, UX-04

**Likely files:**
- `Sources/App/PetController.swift`
- `Sources/App/PetView.swift`
- `Sources/App/StatusBarController.swift`
- `Sources/App/MenuBarContentView.swift`

**Deliverables:**
- Pet bubble can show compact active-session summary.
- Menu bar status can surface compact summary when enabled.
- Existing menu rows still show per-session detail.
- Empty/idle state clears summary cleanly.

**Risks:**
- Bubble text can become too wide or visually noisy.
- Menu bar title behavior may need careful truncation to stay native-feeling.

## Phase 3: Verification and Polish

**Goal:** Confirm the feature behaves correctly in tests and in a local app smoke run.

**Why third:** This phase closes gaps the codebase map identified: app-level behavior is less automated than core logic.

**Requirements:** TEST-03, TEST-04

**Likely files:**
- `Tests/AgentPetCoreTests/*.swift`
- `README.md` or docs only if user-facing behavior needs documentation.
- Potentially no source changes if Phase 1 and 2 verification is complete.

**Deliverables:**
- `swift test` passes.
- `swift build` passes.
- Manual smoke checklist for multiple simulated Claude/Codex sessions.
- Any needed README/docs mention of one-pet multi-session summary.

**Risks:**
- macOS UI smoke verification may be environment-dependent.
- Release signing/notarization is out of scope; do not block feature completion on release packaging.

## Dependencies

- Phase 2 depends on Phase 1 summary APIs.
- Phase 3 depends on Phase 1 and Phase 2 implementation.
- Existing codebase map in `.planning/codebase/` should be consulted before each phase.

## Success Criteria

- The product behavior is clearly one pet for all sessions.
- Waiting sessions are not hidden by working sessions.
- Users can glance at the pet/menu bar and understand whether Claude or Codex needs attention.
- Detailed session inspection remains in the menu bar popover.
- Core behavior is covered by deterministic tests.

---
*Roadmap created: 2026-06-04*
*Last updated: 2026-06-04 after initialization*
