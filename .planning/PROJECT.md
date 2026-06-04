# AgentPet Multi-Session Companion

## What This Is

AgentPet is a native macOS menu bar utility and floating desktop pet that monitors local AI coding agents. This project focuses the existing app into a clearer "one pet, many sessions" companion: a single pet reacts to all active Claude Code and Codex sessions, while compact text summarizes the most important session state and the menu bar keeps per-session detail.

## Core Value

One ambient pet should tell the user when any coding agent needs attention without forcing them to inspect every terminal.

## Requirements

### Validated

- [x] Single floating pet exists and is controlled by `Sources/App/PetWindowController.swift` and `Sources/App/PetView.swift` - existing.
- [x] Multiple sessions are stored independently by `Sources/AgentPetCore/SessionStore.swift` - existing.
- [x] Menu bar popover lists active sessions via `Sources/App/MenuBarContentView.swift` - existing.
- [x] Claude Code and Codex are represented as agent kinds and hook mappings in `Sources/AgentPetCore/AgentHooks.swift` and `Sources/AgentPetCore/StateMapper.swift` - existing.
- [x] Pet mood is derived from aggregate session state through `Sources/AgentPetCore/PetMood.swift` and `Sources/App/PetController.swift` - existing.

### Active

- [ ] Keep exactly one pet for the whole machine, not one pet per agent or per session.
- [ ] Make waiting sessions the visible priority over working sessions because waiting requires user action.
- [ ] Generate a compact multi-session summary suitable for pet bubbles and menu bar status text.
- [ ] Show the most important session first when summary detail fits, for example `Codex waiting - Claude working`.
- [ ] Collapse crowded session state into counts when detail would be noisy, for example `1 waiting - 2 working - 1 done`.
- [ ] Preserve the menu bar list as the detailed per-session view.
- [ ] Cover aggregation and summary behavior with focused Swift tests.

### Out of Scope

- Multiple pets per agent or project - conflicts with the approved one-pet concept.
- New agent integrations beyond the currently supported agent model - this project improves Claude/Codex multi-session behavior first.
- A new persistence model for sessions - existing in-memory session state is sufficient for this scope.
- Remote sync or cross-machine state - this is a local machine companion.
- Full UI test harness - add focused unit tests and manual app smoke verification for this iteration.

## Context

The existing codebase is already architected around one pet and many sessions. `SessionStore` tracks sessions by id, `MenuBarContentView` renders active sessions as rows, and `MoodResolver.aggregate` produces one pet mood from all sessions. The main gap is product polish: the current pet bubble uses generic mood chat lines, and the aggregate priority currently checks working before waiting. For a Codex Pet-style companion, the pet should communicate a compact multi-agent state summary, not only a generic phrase.

The codebase map in `.planning/codebase/` identifies the key implementation areas:
- Core state and aggregation: `Sources/AgentPetCore/PetMood.swift`, `Sources/AgentPetCore/SessionStore.swift`, `Sources/AgentPetCore/AgentSession.swift`.
- App-level summary and pet text: `Sources/App/PetController.swift`, `Sources/App/StatusBarController.swift`, `Sources/App/MenuBarContentView.swift`.
- Detailed session UI: `Sources/App/MenuBarContentView.swift`.
- Tests: `Tests/AgentPetCoreTests/`.

## Constraints

- **Platform**: macOS 13+ native Swift/SwiftUI/AppKit - match the existing SwiftPM package.
- **Architecture**: Keep core aggregation logic in `AgentPetCore` when it is pure and testable; app controllers should consume it.
- **UX**: One pet remains the only floating desktop companion.
- **Attention priority**: Waiting beats working for visible summary and pet attention because user action is more urgent than background work.
- **Noise control**: Summary text must stay compact enough for a pet bubble and menu bar status.
- **Verification**: Run focused Swift tests and `swift test`/`swift build` when implementing.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Keep one pet for all sessions | The desired concept is a single companion for the machine, not visual clutter per agent. | Pending |
| Show compact multi-session summary in the pet/status surface | This simulates the Codex Pet concept and makes the pet useful beyond generic mood text. | Pending |
| Waiting outranks working | Waiting requires user action and should not be hidden by another agent still working. | Pending |
| Keep menu bar as detailed view | The bubble should stay compact; detailed per-session rows already exist in the menu. | Pending |
| Implement as brownfield enhancement | Existing architecture already supports most of the model, so the work should be incremental. | Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check - still the right priority?
3. Audit Out of Scope - reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-04 after initialization*
