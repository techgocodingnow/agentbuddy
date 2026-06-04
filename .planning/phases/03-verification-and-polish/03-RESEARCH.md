# Phase 3 Research: Verification and Polish

**Phase:** 03 - Verification and Polish
**Date:** 2026-06-04
**Status:** Complete

## Scope

Phase 3 closes the v1 milestone by verifying the implementation from Phases 1 and 2. It should run automated package checks, exercise the app with simulated Claude/Codex-like hook events, document the smoke results, and apply only small polish fixes if the smoke reveals concrete defects.

Covered requirements:

- TEST-03
- TEST-04
- TEST-05

## Prior Phase Inputs

Phase 1 provided:

- Waiting-first `MoodResolver.aggregate(_:)`.
- `AgentSessionSummary.compact(for:detailLimit:)`.
- Waiting-first `SessionStore.sorted`.
- Core unit test coverage.

Phase 2 provided:

- Floating pet stacked card UI.
- Compact summary wiring in pet/menu/status surfaces.
- `SessionReplyController` reply boundary.
- Menu row `Reply` affordance for waiting sessions.

Phase 3 should not redesign those implementations. It should verify them and apply narrow polish only if the smoke run proves a problem.

## Existing Verification Paths

### Automated Package Checks

The codebase map lists these primary gates:

```bash
swift test
swift build
```

These cover core hook/session tests and compile the SwiftUI/AppKit app code.

### App Launch Path

The repo has `scripts/build-app.sh`, which assembles `build/AgentBuddy.app` from the SwiftPM executable and signs it ad-hoc for local testing.

Recommended local launch:

```bash
./scripts/build-app.sh debug
open build/AgentBuddy.app
```

All shell commands in this workspace should be run through `rtk`.

### Simulated Session Events

`Sources/App/AppEntry.swift` routes `agentbuddy hook ...` to `HookCLI`.

`HookCLI` accepts:

```bash
agentbuddy hook --event <name> --session <id> [--project <path>] [--agent <kind>] [--message <text>]
```

`EventSender` sends events to the running app over the Unix socket, falling back to queue files if the app is not running. `AppDaemon` applies those events and refreshes pet/menu/status UI.

Useful smoke events:

- Codex waiting: `--agent codex --event PermissionRequest`
- Claude working: `--agent claude --event UserPromptSubmit`
- Generic CLI working/done: `--agent cli --event working` or `--event done`
- Session cleanup: send agent-specific session end events where available, or use the menu clear controls during manual smoke.

## Recommended Smoke Matrix

1. Launch the app bundle.
2. Send one Codex waiting session and one Claude working session.
3. Verify one pet is visible with multiple stacked cards.
4. Verify waiting appears first and exposes `Reply`.
5. Send four active sessions and verify only three cards plus overflow appear.
6. Open the menu popover and verify detailed rows, compact summary, `Reply`, and clear controls.
7. Click `Reply` on a waiting session and verify context is copied to the clipboard and the detailed popover opens.
8. Clear/end sessions and verify no stale cards or summary remain.

## Risks

- App-level smoke may be environment-dependent because it needs macOS GUI access.
- The current dirty worktree contains unrelated documentation/release/setup changes. Phase 3 execution must avoid staging or reverting them unless the user explicitly asks.
- README/docs are already modified outside this phase. If documentation polish is needed, first inspect those changes and avoid overwriting unrelated edits.
- Direct terminal reply remains out of scope until sessions carry reliable terminal targeting metadata.

## Recommendation

Plan Phase 3 as one verification/polish plan:

1. Run automated regression gates.
2. Build/open the app and run the simulated hook-event smoke matrix.
3. Record results in a `03-SMOKE.md` artifact.
4. Apply narrow source/docs polish only if smoke reveals a concrete issue.
5. Create Phase 3 summary and verification report, then mark milestone requirements complete.

## Research Complete

No external research is required. The needed verification paths are local and already present in the repo.
