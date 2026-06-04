# Phase 1 Research: Core Aggregation and Summary Model

**Phase:** 01 - Core Aggregation and Summary Model
**Date:** 2026-06-04
**Status:** Complete

## Scope

Phase 1 is a core-model phase. It should make the one-pet, many-sessions behavior deterministic and testable before Phase 2 wires the summary into the floating pet and menu bar UI.

Covered requirements:

- AGG-01, AGG-02, AGG-03, AGG-04
- SUM-01, SUM-02, SUM-03, SUM-04, SUM-05
- TEST-01, TEST-02

## Current Implementation Findings

### Aggregate Mood Priority

`Sources/AgentPetCore/PetMood.swift` currently contains a pure `MoodResolver.aggregate(_:)` function. It returns `.working` before `.waiting`, then `.done`, then `.idle`.

That directly conflicts with AGG-02. In the approved product behavior, a waiting session is the highest attention state because it means the user is blocking progress. Working is still active, but it should not hide a waiting Claude/Codex session.

Recommended priority:

1. `waiting`
2. `working`
3. `done`
4. `idle`

`registered` and `idle` should not produce an active aggregate state. `done` remains visible only while the existing pruning window keeps a session in `.done`.

### Session Sorting

`SessionStore.sorted` currently sorts sessions through an internal attention priority where `working` outranks `waiting`. Phase 1 should align this with the aggregate priority so detailed lists and summary generation do not disagree.

Recommended sort priority:

1. `waiting`
2. `working`
3. `done`
4. `registered`
5. `idle`

### Summary Formatter

There is no existing compact summary API. `MenuBarContentView` renders individual session rows, and `PetController` emits generic mood chat lines. Phase 1 should add a pure summary formatter to `AgentPetCore` so Phase 2 can consume one implementation instead of duplicating UI logic.

Recommended API shape:

```swift
public enum AgentSessionSummary {
    public static func compact(for sessions: [AgentSession], detailLimit: Int = 2) -> String?
}
```

Behavior:

- Filter active sessions to `waiting`, `working`, and `done`.
- Return `nil` when there are no active sessions.
- Sort by state priority: waiting, working, done.
- For up to `detailLimit` active sessions, return named detail text:
  - `Codex waiting`
  - `Codex waiting - Claude working`
- For more than `detailLimit` active sessions, collapse to state counts:
  - `1 waiting - 2 working - 1 done`
- Omit zero-count groups.
- Keep output bounded by using count mode for crowded cases.

This format satisfies the approved examples and avoids including project paths in compact status text.

### Display Names

`AgentKind` raw values are lower-case identifiers. Summary text needs stable human-facing names. Add a small display-name helper in core code, either as an `AgentKind` extension or inside the summary formatter.

Recommended names:

| Kind | Display |
|------|---------|
| `claude` | `Claude` |
| `codex` | `Codex` |
| `gemini` | `Gemini` |
| `cursor` | `Cursor` |
| `opencode` | `OpenCode` |
| `windsurf` | `Windsurf` |
| `cli` | `CLI` |
| `unknown` | `Agent` |

### Tests To Update

Existing tests already cover the important places:

- `MoodResolverTests.testWorkingWins` should become a waiting-priority test.
- `SessionStoreTests.testSortedByAttentionPriority` should expect waiting before working.

New tests should cover:

- Few-session named summary: `Codex waiting - Claude working`.
- Crowded count summary: `1 waiting - 2 working - 1 done`.
- Registered and idle sessions excluded from summaries.
- Empty/no-active sessions returning `nil`.

## Risks

- Updating priority changes existing expectations, so tests must document the intended behavior rather than silently changing implementation.
- Summary text should not depend on UI-local state or app-layer localization in this phase.
- Using project names in compact status would risk overly long text and possible local path exposure. Use agent kind and state only for Phase 1.
- Duplicate agents can appear when multiple sessions of the same kind are active. Count mode for more than two active sessions avoids ambiguous long named strings.

## Recommendation

Implement Phase 1 as one small core change:

1. Update `MoodResolver.aggregate(_:)` priority to waiting-over-working.
2. Add `AgentSessionSummary` as a pure core formatter.
3. Align `SessionStore.sorted` priority with the new attention order.
4. Update/add deterministic XCTest coverage.

Phase 2 should consume `AgentSessionSummary.compact(for:)` for pet bubble/menu status text without reimplementing aggregation rules.

## Research Complete

This phase can proceed without additional external research. The needed behavior is defined by the local roadmap and current core code.
