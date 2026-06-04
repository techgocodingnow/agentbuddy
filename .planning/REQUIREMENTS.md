# Requirements: AgentBuddy Multi-Session Companion

**Defined:** 2026-06-04
**Core Value:** One ambient pet should tell the user when any coding agent needs attention without forcing them to inspect every terminal.

## v1 Requirements

### Session Aggregation

- [x] **AGG-01**: The app keeps a single pet surface for all active sessions on the machine.
- [x] **AGG-02**: Waiting sessions outrank working sessions when deriving the user-facing aggregate attention state.
- [x] **AGG-03**: Done sessions remain visible briefly without overriding active waiting or working sessions.
- [x] **AGG-04**: Registered and idle sessions are excluded from compact summaries unless no active sessions exist.

### Compact Summary

- [x] **SUM-01**: The app can generate compact text summarizing active Claude/Codex sessions.
- [x] **SUM-02**: When few sessions are active, the summary names important agent states, for example `Codex waiting - Claude working`.
- [x] **SUM-03**: When many sessions are active, the summary collapses into counts, for example `1 waiting - 2 working - 1 done`.
- [x] **SUM-04**: The summary orders state groups by attention priority: waiting, working, done.
- [x] **SUM-05**: Summary text has a bounded length suitable for the pet bubble and menu bar status.

### Pet and Menu Bar UX

- [x] **UX-01**: The floating pet bubble can show the compact multi-session summary instead of only generic mood chat.
- [x] **UX-02**: The menu bar status can reuse or expose the compact summary without removing the existing per-session popover.
- [x] **UX-03**: The menu bar popover continues to show individual sessions with project, state/message, timer, and clear controls.
- [x] **UX-04**: The UI clearly handles the no-active-session state without stale summary text.
- [x] **UX-05**: The final pet-adjacent UI can show multiple active sessions as a compact vertical stack of session cards.
- [x] **UX-06**: Each session card shows a short title/project label and a truncated latest message or state.
- [x] **UX-07**: Waiting/actionable session cards expose a visible `Reply` button.
- [x] **UX-08**: The stacked card surface stays bounded and does not create one pet per session.

### Verification

- [x] **TEST-01**: Unit tests cover aggregate priority with mixed waiting, working, done, registered, and idle sessions.
- [x] **TEST-02**: Unit tests cover compact summary output for few-session and crowded-session cases.
- [x] **TEST-03**: Existing hook/session tests still pass after the aggregation changes.
- [x] **TEST-04**: Manual smoke verification confirms one pet reacts while multiple Claude/Codex-like sessions appear in the menu.
- [x] **TEST-05**: Manual smoke verification confirms multiple active sessions appear in the pet-adjacent card stack and waiting cards expose `Reply`.

## v2 Requirements

### Future Enhancements

- **FUT-01**: User-configurable summary format.
- **FUT-02**: Per-project grouping in the menu bar.
- **FUT-03**: More detailed diagnostics when hook events are not arriving.
- **FUT-04**: Automated UI or app-level integration tests for the pet/menu surfaces.

## Out of Scope

| Feature | Reason |
|---------|--------|
| One pet per agent | Conflicts with the approved one-pet concept. |
| New remote service or sync backend | This feature is local machine state only. |
| New agent family support | Existing Claude/Codex support is enough for this milestone. |
| Major settings redesign | The implementation can fit current settings/menu surfaces. |
| Full release pipeline rewrite | Not needed to deliver the UX behavior. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AGG-01 | Phase 1 | Complete |
| AGG-02 | Phase 1 | Complete |
| AGG-03 | Phase 1 | Complete |
| AGG-04 | Phase 1 | Complete |
| SUM-01 | Phase 1 | Complete |
| SUM-02 | Phase 1 | Complete |
| SUM-03 | Phase 1 | Complete |
| SUM-04 | Phase 1 | Complete |
| SUM-05 | Phase 1 | Complete |
| UX-01 | Phase 2 | Complete |
| UX-02 | Phase 2 | Complete |
| UX-03 | Phase 2 | Complete |
| UX-04 | Phase 2 | Complete |
| UX-05 | Phase 2 | Complete |
| UX-06 | Phase 2 | Complete |
| UX-07 | Phase 2 | Complete |
| UX-08 | Phase 2 | Complete |
| TEST-01 | Phase 1 | Complete |
| TEST-02 | Phase 1 | Complete |
| TEST-03 | Phase 3 | Complete |
| TEST-04 | Phase 3 | Complete |
| TEST-05 | Phase 3 | Complete |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0

## Definition of Done

- Compact summary logic is deterministic and covered by Swift tests.
- The single pet can display multi-session status without creating additional pet windows.
- The pet-adjacent surface can show multiple session cards and expose `Reply` for waiting sessions.
- The menu bar remains the detailed session inspection surface.
- `swift test` and `swift build` pass.

---
*Requirements defined: 2026-06-04*
*Last updated: 2026-06-04 after Phase 3 execution*
