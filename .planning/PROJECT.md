# AgentBuddy Multi-Session Companion

## What This Is

AgentBuddy is a native macOS menu bar utility and floating desktop pet that monitors local AI coding agents. This project focuses the existing app into a clearer "one pet, many sessions" companion: a single pet reacts to all active Claude Code and Codex sessions, while a compact pet-adjacent stack shows multiple session cards and the menu bar keeps deeper per-session detail.

## Core Value

One ambient pet should tell the user when any coding agent needs attention without forcing them to inspect every terminal.

## Requirements

### Validated

- [x] Single floating pet exists and is controlled by `Sources/App/PetWindowController.swift` and `Sources/App/PetView.swift` - existing.
- [x] Multiple sessions are stored independently by `Sources/AgentBuddyCore/SessionStore.swift` - existing.
- [x] Menu bar popover lists active sessions via `Sources/App/MenuBarContentView.swift` - existing.
- [x] Claude Code and Codex are represented as agent kinds and hook mappings in `Sources/AgentBuddyCore/AgentHooks.swift` and `Sources/AgentBuddyCore/StateMapper.swift` - existing.
- [x] Pet mood is derived from aggregate session state through `Sources/AgentBuddyCore/PetMood.swift` and `Sources/App/PetController.swift` - existing.

### Active

- [ ] Keep exactly one pet for the whole machine, not one pet per agent or per session.
- [ ] Make waiting sessions the visible priority over working sessions because waiting requires user action.
- [ ] Generate a compact multi-session summary suitable for pet bubbles and menu bar status text.
- [ ] Show the most important session first when summary detail fits, for example `Codex waiting - Claude working`.
- [ ] Collapse crowded session state into counts when detail would be noisy, for example `1 waiting - 2 working - 1 done`.
- [ ] Show multiple active sessions as stacked cards near the pet, matching the final reference direction.
- [ ] Provide a `Reply` action on actionable/waiting session cards.
- [ ] Preserve the menu bar list as the detailed per-session view.
- [ ] Cover aggregation and summary behavior with focused Swift tests.

### Out of Scope

- Multiple pets per agent or project - conflicts with the approved one-pet concept.
- New agent integrations beyond the currently supported agent model - this project improves Claude/Codex multi-session behavior first.
- A new persistence model for sessions - existing in-memory session state is sufficient for this scope.
- Remote sync or cross-machine state - this is a local machine companion.
- Full UI test harness - add focused unit tests and manual app smoke verification for this iteration.

## Context

The existing codebase is already architected around one pet and many sessions. `SessionStore` tracks sessions by id, `MenuBarContentView` renders active sessions as rows, and `MoodResolver.aggregate` produces one pet mood from all sessions. The main gap is product polish: the current pet bubble uses generic mood chat lines, and the aggregate priority currently checks working before waiting. For a Codex Pet-style companion, the pet should communicate a compact multi-agent state summary and, in the final UI, show stacked session cards beside the pet.

Final UI direction from the 2026-06-04 reference screenshot:
- Keep one pet visible above or beside the status surface.
- Show multiple active sessions as dark rounded cards in a vertical stack.
- Each card should show a short task/project title and a truncated latest status/message.
- Cards should expose a clear per-session `Reply` action for waiting/actionable sessions.
- The stack should remain compact and glanceable; the menu bar remains the place for full detail and management.

The codebase map in `.planning/codebase/` identifies the key implementation areas:
- Core state and aggregation: `Sources/AgentBuddyCore/PetMood.swift`, `Sources/AgentBuddyCore/SessionStore.swift`, `Sources/AgentBuddyCore/AgentSession.swift`.
- App-level summary and pet text: `Sources/App/PetController.swift`, `Sources/App/StatusBarController.swift`, `Sources/App/MenuBarContentView.swift`.
- Detailed session UI: `Sources/App/MenuBarContentView.swift`.
- Tests: `Tests/AgentBuddyCoreTests/`.

## Constraints

- **Platform**: macOS 13+ native Swift/SwiftUI/AppKit - match the existing SwiftPM package.
- **Architecture**: Keep core aggregation logic in `AgentBuddyCore` when it is pure and testable; app controllers should consume it.
- **UX**: One pet remains the only floating desktop companion.
- **Attention priority**: Waiting beats working for visible summary and pet attention because user action is more urgent than background work.
- **Noise control**: Summary text must stay compact enough for a pet bubble and menu bar status.
- **Verification**: Run focused Swift tests and `swift test`/`swift build` when implementing.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Keep one pet for all sessions | The desired concept is a single companion for the machine, not visual clutter per agent. | Pending |
| Show compact multi-session summary in the pet/status surface | This simulates the Codex Pet concept and makes the pet useful beyond generic mood text. | Pending |
| Use stacked session cards for the final pet-adjacent UI | The desired final state should show multiple sessions at once, not only a single summary line. | Pending |
| Add Reply on actionable session cards | Waiting sessions should let the user act directly from the pet surface. | Pending |
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
*Last updated: 2026-06-04 after final UI reference capture*
