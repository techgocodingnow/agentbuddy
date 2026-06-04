---
phase: "02-pet-and-menu-bar-ux-wiring"
plan: "02-pet-menu-ux-wiring"
type: "execute"
wave: 1
depends_on:
  - "01-core-aggregation-and-summary-model"
files_modified:
  - "Sources/App/PetController.swift"
  - "Sources/App/PetView.swift"
  - "Sources/App/PetWindowController.swift"
  - "Sources/App/StatusBarController.swift"
  - "Sources/App/MenuBarContentView.swift"
  - "Sources/App/SessionReplyController.swift"
  - "Tests/AgentBuddyCoreTests/PetTests.swift"
autonomous: true
requirements:
  - "UX-01"
  - "UX-02"
  - "UX-03"
  - "UX-04"
  - "UX-05"
  - "UX-06"
  - "UX-07"
  - "UX-08"
requirements_addressed:
  - "UX-01"
  - "UX-02"
  - "UX-03"
  - "UX-04"
  - "UX-05"
  - "UX-06"
  - "UX-07"
  - "UX-08"
user_setup: []
must_haves:
  truths:
    - "UX-01/UX-02: pet and menu/status surfaces consume AgentSessionSummary.compact(for:) rather than duplicating summary logic."
    - "UX-05/UX-08: the floating pet keeps one pet and renders a bounded stacked card surface for multiple active sessions."
    - "UX-06/UX-07: session cards show title/message/state detail and waiting cards expose a concrete Reply action."
  artifacts:
    - path: "Sources/App/PetView.swift"
      provides: "floating pet layout with bounded stacked session cards"
    - path: "Sources/App/PetController.swift"
      provides: "published compact summary and active session presentation state"
    - path: "Sources/App/SessionReplyController.swift"
      provides: "explicit Reply action boundary for waiting/actionable sessions"
---

# Plan 02: Pet and Menu Bar UX Wiring

<objective>
Wire Phase 1 summary and priority behavior into the app UI so one pet can show multiple active sessions as a compact stacked card surface, expose a visible Reply action for waiting sessions, and keep the menu bar detailed per-session view intact.
</objective>

<threat_model>
This phase displays local session metadata on the desktop. Avoid leaking prompts, terminal output, or full filesystem paths in the floating pet surface. Use short project labels, state, and existing bounded messages. Do not implement unreliable direct terminal input unless the code has a proven target channel; Reply must be a concrete handler boundary with honest behavior, not a silent no-op.
</threat_model>

<execution_context>
@.planning/phases/01-core-aggregation-and-summary-model/01-SUMMARY.md
@.planning/phases/02-pet-and-menu-bar-ux-wiring/02-RESEARCH.md
@.planning/codebase/ARCHITECTURE.md
@.planning/codebase/STRUCTURE.md
@.planning/codebase/TESTING.md
</execution_context>

<tasks>

<task type="auto">
<name>Task 1: Publish UI-ready session summary state</name>
<files>Sources/App/PetController.swift, Sources/App/MenuBarContentView.swift</files>
<requirements>UX-01, UX-02, UX-04</requirements>
<read_first>

- `Sources/App/PetController.swift`
- `Sources/App/MenuBarContentView.swift`
- `Sources/App/StatusBarController.swift`
- `Sources/AgentBuddyCore/AgentSessionSummary.swift`
- `.planning/phases/01-core-aggregation-and-summary-model/01-SUMMARY.md`

</read_first>
<action>

Update app-level state so UI surfaces can consume Phase 1 core summary behavior.

Required behavior:

- `PetController` publishes the latest active sessions or a UI-ready presentation list for the floating pet.
- `PetController` publishes a compact summary from `AgentSessionSummary.compact(for:)`.
- Active sessions for the pet surface exclude `.idle` and `.registered`, matching Phase 1 summary filtering.
- Generic mood chat can remain available, but compact session summary should be preferred whenever active sessions exist.
- Empty/no-active state clears summary/card state and does not leave stale text behind.

Keep the presentation helper small and local to the app layer unless a reusable core abstraction is clearly needed.

</action>
<acceptance_criteria>

- Pet/UI consumers can access current compact summary without recomputing it.
- No UI code reimplements waiting/working/done ordering.
- Empty session arrays clear published summary and cards.
- Existing mood and celebrate behavior are preserved.

</acceptance_criteria>
<verify>
  <automated>rtk swift test</automated>
  <automated>rtk swift build</automated>
</verify>
<done>App UI has a single source of truth for compact active-session summary state.</done>
</task>

<task type="auto">
<name>Task 2: Render bounded stacked session cards beside the pet</name>
<files>Sources/App/PetView.swift, Sources/App/PetController.swift, Sources/App/PetWindowController.swift</files>
<requirements>UX-01, UX-04, UX-05, UX-06, UX-08</requirements>
<read_first>

- `Sources/App/PetView.swift`
- `Sources/App/PetWindowController.swift`
- `Sources/App/ClickThroughHostingView.swift`
- `Sources/App/PetController.swift`
- `Sources/AgentBuddyCore/AgentSession.swift`

</read_first>
<action>

Replace the single generic chat-only floating layout with a one-pet layout plus a bounded pet-adjacent stack.

Required behavior:

- Keep exactly one `PetView`.
- Add a compact vertical stack of active session cards near the pet.
- Show up to three session cards in the floating surface.
- If more active sessions exist, show a compact overflow indicator using the Phase 1 summary or `+N more` copy.
- Each card uses a stable width/height, dark rounded styling, one-line title, and one-line truncated message/state.
- Title should be project basename when available, falling back to session id or agent display name.
- Subtitle should be existing session message when present, falling back to state text.
- Window sizing should expand through `PetController.windowSize(forPoint:)` so `PetWindowController` keeps resize/drag behavior centralized.
- Text must not overlap the pet, buttons, or other cards at small/large pet sizes.

Use SwiftUI system controls and keep card radius at 8px or less unless existing styling requires otherwise.

</action>
<acceptance_criteria>

- Multiple sessions are visible in one floating pet window.
- More than three sessions remain bounded and do not create additional pet windows.
- Long titles/messages truncate cleanly and card dimensions remain stable.
- Existing pet sizing slider still works.
- Empty/no-active state does not show stale cards.

</acceptance_criteria>
<verify>
  <automated>rtk swift build</automated>
</verify>
<done>The floating pet surface shows a bounded stacked session card UI while preserving one pet.</done>
</task>

<task type="auto">
<name>Task 3: Add Reply action boundary and waiting-card affordance</name>
<files>Sources/App/SessionReplyController.swift, Sources/App/PetView.swift, Sources/App/MenuBarContentView.swift</files>
<requirements>UX-06, UX-07</requirements>
<read_first>

- `Sources/App/MenuBarContentView.swift`
- `Sources/App/StatusBarController.swift`
- `Sources/App/PetWindowController.swift`
- `Sources/AgentBuddyCore/AgentSession.swift`
- `.planning/phases/02-pet-and-menu-bar-ux-wiring/02-RESEARCH.md`

</read_first>
<action>

Add a real Reply action boundary and expose it in the UI.

Required behavior:

- Add a small `SessionReplyController` or equivalent app-level action object.
- Waiting session cards show a visible `Reply` button.
- Non-waiting cards do not show Reply, or show it disabled only if the visual design makes the limitation clear.
- Reply button must call a concrete handler; it must not be a silent no-op.
- If exact terminal reply/focus is not possible with current session data, the handler should open or surface the existing detailed session context and make the limitation explicit in code comments or action naming.
- Add the same waiting-session Reply affordance to the detailed menu row if it fits without crowding the existing clear/timer controls.

Do not add terminal injection, AppleScript typing, or process targeting unless the implementer can prove the current session model provides a reliable target.

</action>
<acceptance_criteria>

- Waiting/actionable cards expose a visible `Reply` button.
- Button action is wired to a concrete handler.
- There is no misleading fake direct-reply behavior.
- Existing row clear controls still work.

</acceptance_criteria>
<verify>
  <automated>rtk swift build</automated>
</verify>
<done>Waiting sessions expose a visible, wired Reply affordance through a dedicated action boundary.</done>
</task>

<task type="auto">
<name>Task 4: Reuse compact summary in menu/status surfaces</name>
<files>Sources/App/StatusBarController.swift, Sources/App/MenuBarContentView.swift, Sources/App/PetController.swift</files>
<requirements>UX-02, UX-03, UX-04</requirements>
<read_first>

- `Sources/App/StatusBarController.swift`
- `Sources/App/MenuBarContentView.swift`
- `Sources/App/PetController.swift`
- `Sources/AgentBuddyCore/AgentSessionSummary.swift`

</read_first>
<action>

Wire compact summary into menu/status areas without removing the existing detailed popover.

Required behavior:

- Menu bar transient chat/status text can show the compact summary when active sessions exist.
- Menu popover header subtitle can show compact summary or a close variant of it when active sessions exist.
- Existing per-session rows remain visible with project, message/state, timer, clear controls, and optional Reply.
- No-active-session state remains explicit and clears any old compact summary.
- Count badge behavior remains compatible with waiting-first priority.

</action>
<acceptance_criteria>

- Existing detailed session popover is preserved.
- Compact summary appears in an appropriate status/menu location when active sessions exist.
- Stale summary text does not persist after sessions become idle/empty.
- Waiting sessions continue to get visual priority in badge/status behavior.

</acceptance_criteria>
<verify>
  <automated>rtk swift build</automated>
</verify>
<done>Menu/status surfaces reuse compact summary while preserving detailed session rows.</done>
</task>

<task type="verify">
<name>Task 5: Run package verification and record manual smoke targets</name>
<files>Package.swift, .planning/phases/02-pet-and-menu-bar-ux-wiring/02-SUMMARY.md</files>
<requirements>UX-01, UX-02, UX-03, UX-04, UX-05, UX-06, UX-07, UX-08</requirements>
<read_first>

- `Package.swift`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`

</read_first>
<action>

Run package verification after implementation:

```bash
swift test
swift build
```

Record Phase 3 manual smoke targets in the execution summary:

- Multiple simulated sessions render as stacked cards near the pet.
- Waiting card shows `Reply`.
- More than three active sessions remain bounded.
- Menu popover still shows detailed rows and clear controls.
- Empty/no-active state clears cards and summary text.

</action>
<acceptance_criteria>

- `swift test` passes.
- `swift build` passes.
- Manual smoke targets are listed for Phase 3.
- Any environment blocker is recorded with exact command output.

</acceptance_criteria>
<verify>
  <automated>rtk swift test</automated>
  <automated>rtk swift build</automated>
</verify>
<done>Phase 2 is ready for Phase 3 smoke verification after package checks pass.</done>
</task>

</tasks>

<verification>

Minimum automated verification:

```bash
swift test
swift build
```

Expected implementation assertions:

- UI code imports and uses `AgentSessionSummary.compact(for:)`.
- Floating surface renders one pet and a bounded card stack.
- Waiting sessions show a wired `Reply` button.
- Existing menu popover remains detailed and clear controls still compile.
- Empty/no-active state clears session summary/cards.

</verification>

<success_criteria>

- Phase 2 requirements UX-01 through UX-08 are covered by implementation.
- The final screenshot direction is represented by one pet plus multiple stacked session cards.
- `Reply` exists for waiting/actionable sessions through a concrete handler boundary.
- Menu bar remains a detailed inspection/control surface.
- The repository passes `swift test` and `swift build`, or any environment blocker is documented.

</success_criteria>
