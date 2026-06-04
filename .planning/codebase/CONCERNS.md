# Codebase Concerns

**Analysis Date:** 2026-06-04

## Tech Debt

**Flat `Sources/App` target directory:**
- Issue: UI views, controllers, CLI entry points, pet downloads, settings, and release-adjacent app logic all live in one flat directory.
- Files: `Sources/App/*.swift`.
- Why: Small SwiftPM app evolved quickly from MVP.
- Impact: Feature discovery gets harder as app code grows; unrelated changes can cluster in large files like `SetupView.swift`.
- Fix approach: Split app files into feature folders if the project moves beyond the current size (for example `Settings/`, `Pet/`, `MenuBar/`, `CLI/`, `Release/`).

**Silent optional failures in app paths:**
- Issue: Many app operations use `try?` and keep going without surfaced diagnostics.
- Files: `Sources/App/AppDaemon.swift`, `Sources/App/SettingsModel.swift`, `Sources/App/ImagePetStore.swift`, `Sources/App/SoundSettings.swift`.
- Why: Menu bar utility should not crash for optional behaviors.
- Impact: Hook install, socket startup, file deletion, or pet loading failures can be difficult to diagnose.
- Fix approach: Keep fail-soft behavior, but add visible settings/status errors for user-actionable failures.

**Local tooling files are currently untracked:**
- Issue: `.claude/`, `.codegraph/`, `.gitnexusignore`, `AGENTS.md`, and `CLAUDE.md` are present as untracked files during this map.
- Why: Agent/tooling setup appears local to this workspace.
- Impact: Future commits could accidentally include local/runtime state or duplicate instruction files without scope review.
- Fix approach: Run an explicit commit-scope hygiene pass before staging these files; add ignore rules only after classifying source vs local state.

## Known Bugs

**No confirmed runtime bugs from this mapping pass:**
- Symptoms: none verified.
- Trigger: none verified.
- Workaround: none.
- Root cause: this was a static codebase map, not a live runtime QA pass.

## Security Considerations

**Hook config writes into user home directories:**
- Risk: Incorrect install/remove logic could corrupt existing agent hook config.
- Files: `Sources/AgentPetCore/HookInstaller.swift`, `Sources/AgentPetCore/AgentHooks.swift`.
- Current mitigation: install/uninstall transforms identify AgentPet entries by command string and preserve foreign hooks; transform behavior is covered by tests.
- Recommendations: Keep tests for every supported hook shape when adding agents or events.

**opencode plugin generation embeds a binary path into JavaScript:**
- Risk: bad escaping could generate invalid or unsafe plugin source.
- File: `Sources/AgentPetCore/HookInstaller.swift`.
- Current mitigation: `jsString(_:)` JSON-encodes the binary path before embedding.
- Recommendations: Preserve JSON encoding and test special-character paths if path handling changes.

**`agentpet run` executes arbitrary user commands:**
- Risk: wrapper executes exactly what the user passes through `/usr/bin/env`.
- File: `Sources/App/RunCLI.swift`.
- Current mitigation: it is an explicit local wrapper command; it does not interpret shell syntax itself.
- Recommendations: Continue avoiding shell interpolation; preserve argument-array execution.

**Release secrets are external but referenced by name:**
- Risk: leaking real Developer ID/notarization credentials would compromise releases.
- Files: `.github/workflows/release.yml`, `docs/RELEASING.md`, `scripts/release.sh`.
- Current mitigation: docs mention secret variable names only; no secret values are present in repo.
- Recommendations: keep secrets in GitHub Actions or local keychain profiles only.

## Performance Bottlenecks

**Main-actor session/UI refresh on every event:**
- Problem: every incoming event triggers session apply, optional notification, full sorted session refresh, pet update, and status bar update.
- Files: `Sources/App/AppDaemon.swift`, `Sources/AgentPetCore/SessionStore.swift`.
- Measurement: no performance numbers captured.
- Cause: simple in-memory design, appropriate for modest session counts.
- Improvement path: if many agents/events are tracked, debounce UI refreshes or make `SessionStore` updates more incremental.

**Remote pet library loading is direct URLSession in view model:**
- Problem: no cache, retry, or pagination behavior.
- Files: `Sources/App/PetBrowser.swift`, `Sources/App/PetInstaller.swift`.
- Measurement: no performance numbers captured.
- Cause: simple online catalog integration.
- Improvement path: add local manifest cache and explicit retry/status if the Petdex catalog grows or becomes slow.

## Fragile Areas

**Unix socket path and queue reliability:**
- Why fragile: local socket path length, stale socket files, and queue drain ordering affect event delivery.
- Files: `Sources/AgentPetCore/EventSocketServer.swift`, `Sources/AgentPetCore/EventSender.swift`, `Sources/App/AppDaemon.swift`.
- Common failures: bind failure, path too long, daemon not running, stale queued events.
- Safe modification: preserve queue fallback and add tests when changing socket/queue format.
- Test coverage: socket receive and queue drain are tested; app-level daemon startup failure is not directly tested.

**Agent event mapping tables:**
- Why fragile: each agent has different event names and config format.
- Files: `Sources/AgentPetCore/StateMapper.swift`, `Sources/AgentPetCore/AgentHooks.swift`, `Sources/AgentPetCore/HookPayloads.swift`.
- Common failures: registering an event that does not map to state, missing waiting/done events, incorrect stdin field names.
- Safe modification: update mapping, hook spec, payload parser, and tests together.
- Test coverage: existing tests check registered event coverage for several agents and payload decoding for Cursor/Windsurf/Claude paths.

**Release pipeline differences between local and CI:**
- Why fragile: `scripts/release.sh` uses `create-dmg`, notarizes app then DMG, and emits Sparkle appcast; `scripts/ci-dmg.sh` uses `hdiutil` and conditional CI secrets.
- Files: `scripts/release.sh`, `scripts/ci-dmg.sh`, `.github/workflows/release.yml`.
- Common failures: unsigned/ad-hoc DMG behavior differs from notarized local release; Sparkle appcast updates are manual after local release script output.
- Safe modification: keep local/CI intent documented in `docs/RELEASING.md`; test tagged releases on a private/draft release path when changing signing.
- Test coverage: no automated script tests.

**SwiftUI settings file size:**
- Why fragile: `Sources/App/SetupView.swift` combines multiple tabs, rows, and settings behavior.
- Common failures: unrelated UI changes causing layout/state regressions.
- Safe modification: split new complex UI into small private views or separate files and verify manually on macOS.
- Test coverage: no UI tests.

## Scaling Limits

**Session count:**
- Current capacity: intended for a developer running a small number of local agents.
- Limit: no explicit hard cap; UI usefulness and sorted refresh cost degrade with many sessions.
- Symptoms at limit: noisy menu bar list, frequent notification/sound changes.
- Scaling path: project grouping, filtering, notification throttling, and incremental UI updates.

**Pet assets:**
- Current capacity: local packs under `~/.agentpet/pets/` loaded by scanning directories.
- Limit: no pagination/index for many installed packs.
- Symptoms at limit: slow settings/pet list reload.
- Scaling path: cache pack metadata and lazy-load spritesheets.

## Dependencies at Risk

**Sparkle framework:**
- Risk: update/security behavior depends on correct framework bundling and signing.
- Impact: auto-update breaks or app signing fails.
- Migration plan: keep Sparkle pinned by SwiftPM lockfile and verify `scripts/build-app.sh` after dependency updates.

**Petdex public API:**
- Risk: external manifest schema or availability could change.
- Impact: browse/download pet feature degrades; app core still works.
- Migration plan: keep lenient decoding and add fallback messaging/cache.

**Apple signing/notarization tooling:**
- Risk: command behavior, credentials, or hardened runtime requirements can change.
- Impact: release process fails or distributed app triggers Gatekeeper warnings.
- Migration plan: maintain `docs/RELEASING.md`, test release scripts before public tags.

## Missing Critical Features

**No active diagnostics surface:**
- Problem: hook install/socket/pet load failures are often swallowed.
- Current workaround: user may infer failure from missing state updates.
- Blocks: reliable support/debugging for users whose agent hooks do not report.
- Implementation complexity: medium.

**No automated UI/E2E coverage:**
- Problem: settings, menu bar, pet window, and notifications are manually verified.
- Current workaround: unit tests cover core logic.
- Blocks: confidence in UI-heavy refactors.
- Implementation complexity: medium to high due to macOS UI harness needs.

## Test Coverage Gaps

**AppDaemon and UI state propagation:**
- What's not tested: queue drain into `SessionStore`, notification triggers, pet/status updates at app level.
- Risk: app can compile while real state propagation regresses.
- Priority: High for daemon changes.
- Difficulty to test: requires isolating singleton UI controllers or introducing injectable collaborators.

**Pet browser and installer network paths:**
- What's not tested: manifest fetch, download failure states, malformed remote pet data.
- Risk: remote catalog changes break browse/download silently.
- Priority: Medium.
- Difficulty to test: needs URLSession abstraction or local URLProtocol stubs.

**Release scripts:**
- What's not tested: signing, notarization, Sparkle appcast output, DMG layout.
- Risk: release-only failures appear after tagging.
- Priority: Medium.
- Difficulty to test: requires macOS signing credentials or CI dry-run mode.

---

*Concerns audit: 2026-06-04*
*Update as issues are fixed or new ones discovered*
