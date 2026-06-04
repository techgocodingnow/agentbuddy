---
phase: "01-core-aggregation-and-summary-model"
plan: "01-core-summary-model"
type: "execute"
wave: 1
depends_on: []
files_modified:
  - "Sources/AgentBuddyCore/PetMood.swift"
  - "Sources/AgentBuddyCore/AgentSessionSummary.swift"
  - "Sources/AgentBuddyCore/AgentState.swift"
  - "Sources/AgentBuddyCore/SessionStore.swift"
  - "Tests/AgentBuddyCoreTests/PetTests.swift"
  - "Tests/AgentBuddyCoreTests/SessionStoreTests.swift"
autonomous: true
requirements:
  - "AGG-01"
  - "AGG-02"
  - "AGG-03"
  - "AGG-04"
  - "SUM-01"
  - "SUM-02"
  - "SUM-03"
  - "SUM-04"
  - "SUM-05"
  - "TEST-01"
  - "TEST-02"
requirements_addressed:
  - "AGG-01"
  - "AGG-02"
  - "AGG-03"
  - "AGG-04"
  - "SUM-01"
  - "SUM-02"
  - "SUM-03"
  - "SUM-04"
  - "SUM-05"
  - "TEST-01"
  - "TEST-02"
user_setup: []
must_haves:
  truths:
    - "AGG-02/SUM-04: waiting is the highest attention state and must sort before working everywhere this phase touches."
    - "AGG-04/SUM-05: compact summaries exclude registered and idle sessions, and crowded summaries collapse to bounded count text."
    - "AGG-01: this phase preserves the single-pet model by adding shared core logic, not additional pet windows."
  artifacts:
    - path: "Sources/AgentBuddyCore/AgentSessionSummary.swift"
      provides: "pure compact multi-session summary formatter for Phase 2 UI reuse"
    - path: "Sources/AgentBuddyCore/PetMood.swift"
      provides: "waiting-first aggregate pet mood resolution"
    - path: "Tests/AgentBuddyCoreTests/PetTests.swift"
      provides: "deterministic aggregate and compact-summary regression tests"
---

# Plan 01: Core Aggregation and Summary Model

<objective>
Build deterministic core aggregation and compact summary logic for the approved one-pet, many-sessions behavior. After this phase, app UI can ask core code for the aggregate pet mood and short multi-session status text without duplicating priority rules.
</objective>

<threat_model>
This phase does not add network, file-system, hook ingestion, or process-observation behavior. The main user-facing risk is information disclosure through compact summary text. Keep the summary limited to agent kind and state; do not include project paths, prompts, terminal output, or hook messages. Keep the formatter pure and deterministic so tests can prove ordering and filtering behavior.
</threat_model>

<tasks>

<task type="auto">
<name>Task 1: Update aggregate mood priority</name>
<files>Sources/AgentBuddyCore/PetMood.swift, Tests/AgentBuddyCoreTests/PetTests.swift</files>
<requirements>AGG-01, AGG-02, AGG-03, AGG-04, TEST-01</requirements>
<read_first>

- `Sources/AgentBuddyCore/PetMood.swift`
- `Sources/AgentBuddyCore/AgentSession.swift`
- `Sources/AgentBuddyCore/AgentState.swift`
- `Tests/AgentBuddyCoreTests/PetTests.swift`

</read_first>
<action>

Change `MoodResolver.aggregate(_:)` so `.waiting` outranks `.working`, `.working` outranks `.done`, and `.registered`/`.idle` do not produce an active mood. Update the explanatory comment to match the product behavior: waiting means the user needs to act, so it is the highest attention state.

Update the existing mood resolver tests:

- Replace the working-priority assertion with a waiting-priority assertion covering mixed waiting, working, and done sessions.
- Keep or expand registered/idle coverage so registered sessions remain aggregate idle unless another active state exists.
- Keep done-only coverage so done remains visible when it is the highest active state.

</action>
<acceptance_criteria>

- `MoodResolver.aggregate([working, waiting, done]) == .waiting`.
- `MoodResolver.aggregate([registered, idle]) == .idle`.
- `MoodResolver.aggregate([done, idle]) == .done`.
- Existing tests make the new priority explicit rather than relying on implementation comments.

</acceptance_criteria>
<verify>
  <automated>rtk swift test</automated>
</verify>
<done>Aggregate mood resolution treats waiting as the highest attention state.</done>
</task>

<task type="auto">
<name>Task 2: Add compact session summary formatter</name>
<files>Sources/AgentBuddyCore/AgentSessionSummary.swift, Sources/AgentBuddyCore/AgentState.swift, Tests/AgentBuddyCoreTests/PetTests.swift</files>
<requirements>SUM-01, SUM-02, SUM-03, SUM-04, SUM-05, AGG-04, TEST-02</requirements>
<read_first>

- `Sources/AgentBuddyCore/AgentSession.swift`
- `Sources/AgentBuddyCore/AgentState.swift`
- `Sources/AgentBuddyCore/PetMood.swift`
- `Tests/AgentBuddyCoreTests/PetTests.swift`

</read_first>
<action>

Add a pure formatter in `Sources/AgentBuddyCore/AgentSessionSummary.swift`.

Target API:

```swift
public enum AgentSessionSummary {
    public static func compact(for sessions: [AgentSession], detailLimit: Int = 2) -> String?
}
```

Formatter rules:

- Active states are `waiting`, `working`, and `done`.
- `registered` and `idle` are excluded.
- Return `nil` when there are no active sessions.
- Order active sessions and count groups by attention priority: waiting, working, done.
- When active session count is less than or equal to `detailLimit`, return named detail text joined by ` - `, for example `Codex waiting - Claude working`.
- When active session count is greater than `detailLimit`, return count text joined by ` - `, for example `1 waiting - 2 working - 1 done`.
- Omit zero-count groups.
- Clamp `detailLimit` to at least `1` so callers cannot accidentally force an empty summary for active sessions.

Add a core display-name helper for `AgentKind`, either in the new formatter file or as an `AgentKind` extension. Use stable names: `Claude`, `Codex`, `Gemini`, `Cursor`, `OpenCode`, `Windsurf`, `CLI`, and `Agent`.

</action>
<acceptance_criteria>

- Few-session summary returns `Codex waiting - Claude working` for one Codex waiting session and one Claude working session.
- Crowded summary returns state counts in waiting, working, done order.
- Summary output never includes project paths, hook messages, prompts, or terminal output.
- Summary output is bounded for crowded cases because count mode activates above the detail limit.

</acceptance_criteria>
<verify>
  <automated>rtk swift test</automated>
</verify>
<done>Core code can produce compact named and counted summaries for active sessions.</done>
</task>

<task type="auto">
<name>Task 3: Cover summary edge cases with unit tests</name>
<files>Tests/AgentBuddyCoreTests/PetTests.swift, Sources/AgentBuddyCore/AgentSessionSummary.swift</files>
<requirements>SUM-01, SUM-02, SUM-03, SUM-04, SUM-05, TEST-02</requirements>
<read_first>

- `Tests/AgentBuddyCoreTests/PetTests.swift`
- `Tests/AgentBuddyCoreTests/SessionStoreTests.swift`
- `Sources/AgentBuddyCore/AgentSessionSummary.swift`

</read_first>
<action>

Add focused XCTest coverage for `AgentSessionSummary.compact(for:)`.

Required cases:

- Empty input returns `nil`.
- Only `registered` and `idle` sessions returns `nil`.
- Two active sessions return named detail in priority order.
- More than two active sessions collapse into counts.
- Count groups are ordered waiting, working, done and omit zero-count states.
- The function handles duplicate agent kinds by using count mode when crowded.

Keep test helpers local and deterministic with fixed dates.

</action>
<acceptance_criteria>

- Tests fail if registered/idle sessions appear in compact summaries.
- Tests fail if working is ordered before waiting.
- Tests fail if crowded cases produce a long per-session string instead of count groups.

</acceptance_criteria>
<verify>
  <automated>rtk swift test</automated>
</verify>
<done>Compact-summary behavior is covered for empty, inactive, named, crowded, and ordering cases.</done>
</task>

<task type="auto">
<name>Task 4: Align session store attention sorting</name>
<files>Sources/AgentBuddyCore/SessionStore.swift, Tests/AgentBuddyCoreTests/SessionStoreTests.swift</files>
<requirements>AGG-02, SUM-04, TEST-01</requirements>
<read_first>

- `Sources/AgentBuddyCore/SessionStore.swift`
- `Tests/AgentBuddyCoreTests/SessionStoreTests.swift`
- `Sources/AgentBuddyCore/PetMood.swift`

</read_first>
<action>

Update `SessionStore.sorted` attention priority so detailed session order agrees with aggregate and summary priority:

1. waiting
2. working
3. done
4. registered
5. idle

Update `SessionStoreTests.testSortedByAttentionPriority` to expect `["waiting", "working", "done"]` for the existing active-session fixture. Preserve secondary recency/id ordering behavior.

</action>
<acceptance_criteria>

- Session sorting no longer disagrees with `MoodResolver` and `AgentSessionSummary`.
- Existing prune, clear, and event mapping tests still pass.

</acceptance_criteria>
<verify>
  <automated>rtk swift test</automated>
</verify>
<done>Detailed session ordering agrees with waiting-first aggregate and summary priority.</done>
</task>

<task type="auto">
<name>Task 5: Run focused and package verification</name>
<files>Package.swift, Tests/AgentBuddyCoreTests/PetTests.swift, Tests/AgentBuddyCoreTests/SessionStoreTests.swift</files>
<requirements>TEST-01, TEST-02</requirements>
<read_first>

- `Package.swift`
- `Tests/AgentBuddyCoreTests/PetTests.swift`
- `Tests/AgentBuddyCoreTests/SessionStoreTests.swift`

</read_first>
<action>

Run Swift package verification after implementation:

```bash
swift test
swift build
```

If a test fails, fix the implementation or test expectation within this phase. Do not defer a core priority or formatter failure to Phase 2.

</action>
<acceptance_criteria>

- `swift test` passes.
- `swift build` passes.
- If either command cannot run because of an environment problem, record the exact command and failure in the phase execution summary.

</acceptance_criteria>
<verify>
  <automated>rtk swift test</automated>
  <automated>rtk swift build</automated>
</verify>
<done>Phase 1 core changes pass Swift package verification or document an environment blocker.</done>
</task>

</tasks>

<verification>

Minimum verification for this phase:

```bash
swift test
swift build
```

Expected assertions:

- Waiting outranks working in aggregate mood.
- Registered and idle sessions are not compact-summary active states.
- Done remains visible when it is the highest active state.
- Few active sessions use named detail.
- Crowded active sessions use count summary.
- Detailed session sorting uses the same waiting-first attention order.

</verification>

<success_criteria>

- Phase 1 requirements AGG-01 through AGG-04, SUM-01 through SUM-05, TEST-01, and TEST-02 are covered by implementation and tests.
- The summary API is in `AgentBuddyCore` and is safe for Phase 2 UI reuse.
- No UI behavior is changed in this phase except through future consumers of the new core API.
- The repository passes `swift test` and `swift build`, or any environment blocker is documented with command output.

</success_criteria>
