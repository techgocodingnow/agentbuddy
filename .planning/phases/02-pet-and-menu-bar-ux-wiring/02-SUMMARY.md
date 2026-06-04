---
phase: 02-pet-and-menu-bar-ux-wiring
plan: 02-pet-menu-ux-wiring
subsystem: app-ui
tags: [swiftui, appkit, menu-bar, floating-panel, session-cards, reply]
requires:
  - phase: 01-core-aggregation-and-summary-model
    provides: AgentSessionSummary.compact(for:) and waiting-first session ordering
provides:
  - pet-adjacent stacked session card UI
  - compact summary wiring for pet and menu/status surfaces
  - Reply action boundary for waiting sessions
  - dynamic floating panel sizing for active session cards
affects: [phase-3-verification-and-polish]
tech-stack:
  added: []
  patterns: [pet-controller-presentation-state, bounded-floating-card-stack, reply-action-boundary]
key-files:
  created:
    - Sources/App/SessionReplyController.swift
  modified:
    - Sources/App/PetController.swift
    - Sources/App/PetView.swift
    - Sources/App/PetWindowController.swift
    - Sources/App/StatusBarController.swift
    - Sources/App/MenuBarContentView.swift
key-decisions:
  - "Use AgentSessionSummary.compact(for:) as the shared summary source for pet and menu/status UI."
  - "Bound the floating surface to three visible cards plus an overflow row."
  - "Implement Reply as an explicit action boundary that copies session context and opens the detailed popover until sessions have a reliable terminal target."
patterns-established:
  - "PetController owns UI-ready active session and compact summary state."
  - "Pet window sizing is based on pet size plus active card count."
  - "Waiting session actions route through SessionReplyController."
requirements-completed: [UX-01, UX-02, UX-03, UX-04, UX-05, UX-06, UX-07, UX-08]
duration: 18min
completed: 2026-06-04
---

# Phase 2: Pet and Menu Bar UX Wiring Summary

**One-pet floating UI with bounded session cards, compact summary reuse, and a waiting-session Reply boundary**

## Performance

- **Duration:** 18 min
- **Started:** 2026-06-04T10:52:30Z
- **Completed:** 2026-06-04T11:10:51Z
- **Tasks:** 5
- **Files modified:** 6 source files plus 2 phase closeout docs and planning status files

## Accomplishments

- `PetController` now publishes `compactSummary` and active session presentation state derived from `AgentSessionSummary.compact(for:)`.
- `FloatingPetView` now keeps one pet and renders up to three dark rounded session cards below it.
- The floating card stack shows title, truncated message/state, state dot, `Reply` for waiting sessions, and an overflow row for crowded sessions.
- `PetWindowController` resizes the floating panel based on active card count while preserving idle compact sizing.
- `SessionReplyController` provides the explicit Reply boundary; it copies concise session context to the clipboard and opens the detailed popover.
- Menu rows preserve details and clear controls while adding `Reply` for waiting sessions.
- Menu/status text can reuse compact summary when active sessions exist.

## Task Commits

This phase was executed inline and will be committed as one scoped Phase 2 implementation commit.

## Files Created/Modified

- `Sources/App/SessionReplyController.swift` - Reply action boundary for waiting sessions.
- `Sources/App/PetController.swift` - Published compact summary, active sessions, visible/hidden card helpers, and dynamic window size.
- `Sources/App/PetView.swift` - Floating stacked card UI and waiting-card Reply button.
- `Sources/App/PetWindowController.swift` - Resizes the panel when active card count changes.
- `Sources/App/StatusBarController.swift` - Opens popover from Reply and prefers compact summary for menu-bar chat/status text.
- `Sources/App/MenuBarContentView.swift` - Header subtitle uses compact summary; waiting rows expose Reply while keeping clear controls.

## Decisions Made

- Reply does not attempt terminal text injection because the current session model lacks terminal/window/process targeting data.
- Reply copies context and opens the detailed popover as a concrete v1 action.
- The floating UI is bounded to three visible cards plus overflow to avoid desktop occlusion.

## Deviations From Plan

None - plan executed as written.

## Issues Encountered

- Initial window-size approach made the idle pet panel too tall. Adjusted sizing to expand only when active cards exist.

## User Setup Required

None - no external service configuration required.

## Phase 3 Manual Smoke Targets

- Multiple simulated sessions render as stacked cards near the pet.
- Waiting card shows `Reply`.
- More than three active sessions remain bounded with overflow.
- Menu popover still shows detailed rows and clear controls.
- Empty/no-active state clears cards and summary text.
- Reply copies concise session context and opens the detailed popover.

## Next Phase Readiness

Phase 3 can focus on app-level smoke verification, documentation polish if needed, and any visual adjustments discovered when the floating pet is run locally.

---
*Phase: 02-pet-and-menu-bar-ux-wiring*
*Completed: 2026-06-04*
