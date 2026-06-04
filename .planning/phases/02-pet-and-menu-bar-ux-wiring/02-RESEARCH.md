# Phase 2 Research: Pet and Menu Bar UX Wiring

**Phase:** 02 - Pet and Menu Bar UX Wiring
**Date:** 2026-06-04
**Status:** Complete

## Scope

Phase 2 is the UI wiring phase. It should consume Phase 1 core summary behavior and make the one-pet, many-sessions experience visible in the floating pet and menu bar surfaces.

Covered requirements:

- UX-01, UX-02, UX-03, UX-04
- UX-05, UX-06, UX-07, UX-08

## Prior Phase Inputs

Phase 1 completed these reusable core behaviors:

- `MoodResolver.aggregate(_:)` now treats waiting as higher priority than working.
- `AgentSessionSummary.compact(for:detailLimit:)` returns UI-safe compact status text.
- `SessionStore.sorted` is waiting-first, then working, then done.

Phase 2 should use those APIs directly. It should not duplicate summary ordering/filtering in app UI.

## Current UI Findings

### Floating Pet Window

`Sources/App/PetView.swift` currently renders:

- Optional `ChatBubble(text: pet.chatLine)`
- `PetView(size: pet.petPoint)`
- A window frame from `PetController.windowSize(forPoint:)`

`PetController.chatLine` is generated from mood-specific generic text. There is no session card stack and no per-session action.

Implication: Phase 2 needs a new pet-adjacent UI component. It should be bounded and coexist with the pet sprite instead of creating multiple pet windows.

### Pet Window Controller

`Sources/App/PetWindowController.swift` hosts `FloatingPetView()` in a borderless non-activating `NSPanel`. Window size follows `PetController.windowSize(forPoint:)`.

Implication: stacked cards require a larger dynamic window size. The plan should update the size calculation in one place and preserve existing bottom-center resize behavior.

### Pet Controller

`Sources/App/PetController.swift` stores latest sessions privately, derives aggregate mood, and publishes `mood` and `chatLine`.

Implication: this is the natural owner for UI-friendly derived state:

- compact summary text from `AgentSessionSummary`
- active sessions for the pet-adjacent stack
- optional card model/helpers if kept app-local

### Menu Bar Popover

`Sources/App/MenuBarContentView.swift` already renders active sessions as rows with project/title, subtitle/message, elapsed time, dot color, and clear controls. It filters idle/registered sessions.

Implication: preserve this detailed view. Phase 2 can improve it by adding a visible `Reply` action on waiting rows and by reusing the same session-title/subtitle helpers as the pet cards if practical.

### Status Bar Title

`Sources/App/StatusBarController.swift` currently shows a count badge and can show generic chat text in a transient menu-bar bubble. It does not currently use the Phase 1 compact summary.

Implication: Phase 2 should use `AgentSessionSummary.compact(for:)` where short status text is displayed, while preserving the existing count badge behavior.

## Final UI Reference

The 2026-06-04 screenshot target shows:

- One pet sprite above/near the status surface.
- Multiple dark rounded session cards in a vertical stack.
- Each card has a bold title and truncated latest message/state.
- Cards are compact and glanceable.
- Waiting/actionable cards need a `Reply` button.

Recommended implementation shape:

- Show at most three cards in the floating surface.
- If more than three active sessions exist, add a compact overflow row such as `+2 more - 1 waiting - 3 working`.
- Use stable card height and width so the pet window does not jump as text changes.
- Use one-line truncation for title and message.
- Use a visible `Reply` button for `.waiting` sessions and hide or disable it for non-actionable states.

## Reply Affordance Constraint

The current session model has no terminal window id, process id, TTY path, or direct input channel. That means Phase 2 should not claim to inject a reply into the exact running Claude/Codex process unless new ownership data is added.

Recommended Phase 2 behavior:

- Add a concrete `Reply` action boundary instead of a no-op.
- For v1, the action should surface the existing detailed session context and make the waiting session easy to act on.
- If exact terminal focus/reply is not possible from current data, make the limitation explicit in code structure and UI behavior rather than silently pretending to reply.
- Keep direct terminal input/focus as future work unless the implementer can prove a reliable local route from existing data.

This satisfies UX-07's visible `Reply` button while avoiding an unreliable fake direct-reply implementation.

## Risks

- The floating window can become too large or occlude the desktop if card count is unbounded.
- Long project names/messages can overlap or resize cards unless the UI fixes card dimensions and truncates text.
- Button controls in a non-activating panel need to remain clickable on first click; existing `ClickThroughHostingView` is relevant.
- `Reply` is under-specified by current runtime data. The plan should require a real handler boundary and honest behavior.
- Phase 2 should avoid changing hook ingestion/session storage; that belongs in a later phase if direct terminal reply needs more metadata.

## Recommendation

Implement Phase 2 as one UI wiring plan:

1. Add app-level presentation helpers for active sessions/cards using Phase 1 core summary.
2. Expand `FloatingPetView` into one pet plus a bounded stacked session-card surface.
3. Add a concrete `Reply` action boundary and visible buttons for waiting sessions.
4. Reuse compact summary in menu/status surfaces while preserving existing per-session menu rows.
5. Verify with `swift test` and `swift build`; leave manual smoke of card positioning and Reply affordance to Phase 3.

## Research Complete

No external research is needed. The required work is local SwiftUI/AppKit wiring over existing `AgentBuddyCore` APIs and current app surfaces.
