# Project State

**Status:** Ready to execute
**Project:** AgentPet Multi-Session Companion
**Current Milestone:** v1 - Compact Multi-Session Pet Summary
**Current Phase:** Phase 2 - Pet and Menu Bar UX Wiring
**Updated:** 2026-06-04T10:59:21Z

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-06-04)

**Core value:** One ambient pet should tell the user when any coding agent needs attention without forcing them to inspect every terminal.
**Current focus:** Execute pet/menu UI wiring for the compact summary, stacked session cards, and Reply affordance.

## Active Context

The user approved the recommended behavior:
- Keep one pet for the machine.
- Show compact multi-session summary.
- Waiting has priority because it requires action.
- Collapse crowded sessions into counts.
- Final UI should show multiple active sessions as stacked cards near the pet.
- Waiting/actionable cards should expose a `Reply` button.
- Keep menu bar as detailed per-session view.

This is a brownfield enhancement. The existing codebase already has:
- One floating pet window.
- Multiple independent sessions in `SessionStore`.
- Claude/Codex agent kinds and hook mappings.
- Menu bar rows for per-session detail.
- Aggregate mood resolver used by `PetController`.

## Current Plan

1. Run `$gsd-execute-phase 2`.
2. Wire UI surfaces to consume `AgentSessionSummary.compact(for:)`.
3. Build the pet-adjacent stacked session card surface and Reply affordance.
4. Verify with Swift tests/build and leave manual smoke targets for Phase 3.

## Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-06-04 | Use one pet for all sessions | Avoids visual clutter and matches the approved companion concept. |
| 2026-06-04 | Compact summary belongs in pet/menu status | Makes the pet useful as a glanceable multi-agent status surface. |
| 2026-06-04 | Waiting outranks working | User attention should prioritize blocked sessions. |
| 2026-06-04 | Compact summaries use only agent kind and state | Avoids leaking project paths, prompts, hook messages, or terminal output into pet/status text. |

## Blockers

None.

## Notes for Next Agent

- Phase 1 is complete. Read `.planning/phases/01-core-aggregation-and-summary-model/01-SUMMARY.md` before executing Phase 2.
- Read `.planning/phases/02-pet-and-menu-bar-ux-wiring/02-RESEARCH.md` and `02-PLAN.md` before implementation.
- Reuse `AgentSessionSummary.compact(for:)` instead of duplicating summary ordering/filtering in app UI.
- Do not touch unrelated untracked local/tooling files unless the user explicitly asks for cleanup.

---
*State initialized: 2026-06-04*
