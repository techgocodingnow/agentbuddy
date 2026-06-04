---
phase: "03-verification-and-polish"
plan: "03-verification-polish"
type: "execute"
wave: 1
depends_on:
  - "01-core-aggregation-and-summary-model"
  - "02-pet-and-menu-bar-ux-wiring"
files_modified:
  - ".planning/phases/03-verification-and-polish/03-SMOKE.md"
  - ".planning/phases/03-verification-and-polish/03-SUMMARY.md"
  - ".planning/phases/03-verification-and-polish/03-VERIFICATION.md"
  - "README.md"
  - "Sources/App/PetView.swift"
  - "Sources/App/MenuBarContentView.swift"
  - "Sources/App/PetController.swift"
autonomous: true
requirements:
  - "TEST-03"
  - "TEST-04"
  - "TEST-05"
requirements_addressed:
  - "TEST-03"
  - "TEST-04"
  - "TEST-05"
user_setup: []
must_haves:
  truths:
    - "TEST-03: Swift package regression gates pass after Phase 1 and Phase 2 changes."
    - "TEST-04: manual smoke confirms one pet reacts while multiple Claude/Codex-like sessions appear in the menu."
    - "TEST-05: manual smoke confirms multiple active sessions appear in the pet-adjacent card stack and waiting cards expose Reply."
  artifacts:
    - path: ".planning/phases/03-verification-and-polish/03-SMOKE.md"
      provides: "manual app smoke transcript, commands, observations, and any polish findings"
    - path: ".planning/phases/03-verification-and-polish/03-VERIFICATION.md"
      provides: "final Phase 3 verification report"
    - path: ".planning/phases/03-verification-and-polish/03-SUMMARY.md"
      provides: "milestone closeout summary for Phase 3"
---

# Plan 03: Verification and Polish

<objective>
Verify the v1 one-pet, many-sessions feature end to end: package tests/builds pass, the running app responds to simulated Claude/Codex-like sessions, stacked pet cards and Reply are visible, and the menu remains the detailed session surface.
</objective>

<threat_model>
This phase launches a local macOS app and injects simulated local hook events. Use only local test session ids and messages. Do not send real prompt content, secrets, or full terminal output. Do not stage unrelated worktree changes. If documentation polish is needed, inspect existing dirty files first and preserve unrelated edits.
</threat_model>

<execution_context>
@.planning/phases/01-core-aggregation-and-summary-model/01-SUMMARY.md
@.planning/phases/02-pet-and-menu-bar-ux-wiring/02-SUMMARY.md
@.planning/phases/03-verification-and-polish/03-RESEARCH.md
@.planning/codebase/TESTING.md
</execution_context>

<tasks>

<task type="auto">
<name>Task 1: Run automated regression gates</name>
<files>Package.swift, Tests/AgentPetCoreTests/*.swift</files>
<requirements>TEST-03</requirements>
<read_first>

- `Package.swift`
- `.planning/codebase/TESTING.md`
- `.planning/phases/01-core-aggregation-and-summary-model/01-SUMMARY.md`
- `.planning/phases/02-pet-and-menu-bar-ux-wiring/02-SUMMARY.md`

</read_first>
<action>

Run the package gates:

```bash
rtk swift test
rtk swift build
```

Record exact pass/fail evidence in `03-SMOKE.md` or the Phase 3 summary. If either command fails, fix only defects related to Phase 1/2 work and rerun the command.

</action>
<acceptance_criteria>

- `swift test` passes.
- `swift build` passes.
- Existing hook/session tests still pass.
- Any failure is either fixed in this phase or documented as a blocker.

</acceptance_criteria>
<verify>
  <automated>rtk swift test</automated>
  <automated>rtk swift build</automated>
</verify>
<done>Package regression gates pass after the aggregation and UI changes.</done>
</task>

<task type="auto">
<name>Task 2: Build and launch the local app for smoke testing</name>
<files>scripts/build-app.sh, build/AgentPet.app, .planning/phases/03-verification-and-polish/03-SMOKE.md</files>
<requirements>TEST-04, TEST-05</requirements>
<read_first>

- `scripts/build-app.sh`
- `README.md`
- `Sources/App/AppEntry.swift`
- `Sources/App/CLI.swift`
- `Sources/App/AppDaemon.swift`

</read_first>
<action>

Build and launch the local app bundle:

```bash
rtk ./scripts/build-app.sh debug
rtk open build/AgentPet.app
```

Wait for the menu bar item and floating pet to appear. If GUI launch is not possible in the current environment, record the exact blocker in `03-SMOKE.md` and continue with automated evidence only.

</action>
<acceptance_criteria>

- App bundle builds successfully, or the exact environment blocker is recorded.
- Running app is available to receive hook events before manual smoke commands are sent.
- No release/signing/notarization workflow is changed.

</acceptance_criteria>
<verify>
  <manual>Confirm AgentPet.app launches and the floating pet/menu item appear.</manual>
</verify>
<done>Local app is ready for simulated session smoke testing, or the GUI blocker is documented.</done>
</task>

<task type="auto">
<name>Task 3: Run simulated multi-session smoke matrix</name>
<files>.planning/phases/03-verification-and-polish/03-SMOKE.md</files>
<requirements>TEST-04, TEST-05</requirements>
<read_first>

- `Sources/App/CLI.swift`
- `Sources/App/AppDaemon.swift`
- `Sources/App/PetView.swift`
- `Sources/App/MenuBarContentView.swift`
- `Sources/App/SessionReplyController.swift`

</read_first>
<action>

Use the built `agentpet` helper to send local smoke events. Resolve the binary with SwiftPM if needed:

```bash
BIN="$(rtk swift build --show-bin-path)/agentpet"
rtk "$BIN" hook --agent codex --event PermissionRequest --session smoke-codex --project "$PWD" --message "Create gsd new project"
rtk "$BIN" hook --agent claude --event UserPromptSubmit --session smoke-claude --project "$PWD" --message "Update README credits"
rtk "$BIN" hook --agent cli --event working --session smoke-cli --project "$PWD" --message "Checking release notes"
rtk "$BIN" hook --agent gemini --event Notification --session smoke-gemini --project "$PWD" --message "Needs approval"
```

Observe and record:

- one pet is visible, not one pet per session
- stacked pet cards show multiple sessions
- waiting sessions are visually prominent and expose `Reply`
- more than three active sessions show a bounded overflow state
- menu popover shows detailed rows with compact summary and clear controls
- clicking `Reply` copies concise context and opens the detailed popover
- clearing or ending sessions removes cards/summary without stale text

Record observations, screenshots if available, and cleanup commands in `03-SMOKE.md`.

</action>
<acceptance_criteria>

- `03-SMOKE.md` records the exact smoke commands used.
- `03-SMOKE.md` records pass/fail status for one-pet behavior, menu rows, stacked cards, overflow, Reply, and empty state.
- Any failure has a concrete fix or blocker note.

</acceptance_criteria>
<verify>
  <manual>Inspect the running app after simulated events and record observations.</manual>
</verify>
<done>Manual smoke evidence exists for multiple sessions, stacked cards, menu rows, and Reply.</done>
</task>

<task type="auto">
<name>Task 4: Apply narrow polish only if smoke reveals defects</name>
<files>Sources/App/PetView.swift, Sources/App/MenuBarContentView.swift, Sources/App/PetController.swift, README.md</files>
<requirements>TEST-04, TEST-05</requirements>
<read_first>

- `.planning/phases/03-verification-and-polish/03-SMOKE.md`
- `Sources/App/PetView.swift`
- `Sources/App/MenuBarContentView.swift`
- `Sources/App/PetController.swift`
- `README.md`

</read_first>
<action>

If smoke testing reveals layout, truncation, stale-state, Reply, or documentation gaps, apply minimal targeted fixes. Do not broaden scope.

Allowed fixes:

- card spacing, truncation, width, or overflow text
- empty-state cleanup if stale cards/summary remain
- Reply copy/action wording if unclear
- README/docs note describing one-pet multi-session cards and v1 Reply behavior

Before editing `README.md` or any already-dirty file, inspect current diffs and preserve unrelated changes. Do not stage unrelated work.

</action>
<acceptance_criteria>

- Only smoke-proven defects are changed.
- No unrelated dirty worktree changes are reverted or staged.
- `swift test` and `swift build` pass after any polish.
- If no defects are found, this task records "no source/docs changes needed" in `03-SMOKE.md`.

</acceptance_criteria>
<verify>
  <automated>rtk swift test</automated>
  <automated>rtk swift build</automated>
</verify>
<done>Any needed smoke-driven polish is complete and verified, or no polish was needed.</done>
</task>

<task type="verify">
<name>Task 5: Close Phase 3 and milestone verification</name>
<files>.planning/REQUIREMENTS.md, .planning/ROADMAP.md, .planning/STATE.md, .planning/phases/03-verification-and-polish/03-SUMMARY.md, .planning/phases/03-verification-and-polish/03-VERIFICATION.md</files>
<requirements>TEST-03, TEST-04, TEST-05</requirements>
<read_first>

- `.planning/phases/03-verification-and-polish/03-SMOKE.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`

</read_first>
<action>

Create Phase 3 closeout docs:

- `03-SUMMARY.md`
- `03-VERIFICATION.md`

Update planning status:

- Mark TEST-03, TEST-04, and TEST-05 complete if evidence passes.
- Mark Phase 3 complete in `ROADMAP.md`.
- Set project state to milestone-ready for `$gsd-verify-work` or `$gsd-complete-milestone`.

Run final checks:

```bash
rtk node /Users/kevin/Desktop/hobby/quicknotelm/.codex/get-shit-done/bin/gsd-tools.cjs validate consistency
rtk git diff --check
```

</action>
<acceptance_criteria>

- Phase 3 summary and verification report exist.
- Requirement traceability is updated for TEST-03 through TEST-05.
- GSD consistency validation passes.
- Final diff stages only Phase 3-related files.

</acceptance_criteria>
<verify>
  <automated>rtk node /Users/kevin/Desktop/hobby/quicknotelm/.codex/get-shit-done/bin/gsd-tools.cjs validate consistency</automated>
  <automated>rtk git diff --check</automated>
</verify>
<done>Phase 3 is closed with smoke evidence and milestone-ready planning state.</done>
</task>

</tasks>

<verification>

Minimum automated verification:

```bash
rtk swift test
rtk swift build
rtk node /Users/kevin/Desktop/hobby/quicknotelm/.codex/get-shit-done/bin/gsd-tools.cjs validate consistency
rtk git diff --check
```

Minimum manual smoke observations:

- one pet is visible for all sessions
- multiple Claude/Codex-like sessions appear in the menu
- pet-adjacent stacked cards show multiple sessions
- waiting card exposes `Reply`
- overflow remains bounded above three cards
- empty/no-active state clears cards and summary

</verification>

<success_criteria>

- TEST-03, TEST-04, and TEST-05 are backed by explicit evidence.
- App-level smoke results are captured in `03-SMOKE.md`.
- Any needed polish is scoped to observed defects.
- The milestone is ready for `$gsd-verify-work` or `$gsd-complete-milestone`.

</success_criteria>
