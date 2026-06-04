# Architecture

**Analysis Date:** 2026-06-04

## Pattern Overview

**Overall:** Native macOS menu bar app with embedded CLI bridge and event-driven local daemon.

**Key Characteristics:**
- Single SwiftPM executable (`agentpet`) has multiple roles: app, hook CLI, and generic command wrapper.
- Event-driven state pipeline: agent hook -> local JSON event -> socket/queue -> daemon -> in-memory session store -> UI/pet/notifications.
- Core event/session logic is isolated in `AgentPetCore`; UI and macOS integration live in `Sources/App`.
- Persistent user data is local only: UserDefaults plus files under `~/.agentpet`.

## Layers

**Executable Routing Layer:**
- Purpose: Choose app mode or CLI helper mode.
- Contains: `AgentPetMain` switch over `hook`, `run`, and default app launch.
- Location: `Sources/App/AppEntry.swift`.
- Depends on: `HookCLI`, `RunCLI`, `AgentPetApp`.
- Used by: direct binary execution, installed agent hooks, and `agentpet run -- <command>`.

**Core Domain Layer:**
- Purpose: Model agents, events, states, sessions, hook specs, and transport primitives independent of SwiftUI.
- Contains: `AgentEvent`, `AgentSession`, `AgentState`, `AgentKind`, `StateMapper`, `SessionStore`, `EventSocketServer`, `EventSender`, hook parsing/install transforms.
- Location: `Sources/AgentPetCore/`.
- Depends on: Foundation and POSIX socket functions.
- Used by: CLI helpers, daemon, settings, status UI, tests.

**Daemon/Application State Layer:**
- Purpose: Own live session state in the running app.
- Contains: `AppDaemon`, socket startup, queue drain, session pruning, notification triggers, UI refresh propagation.
- Location: `Sources/App/AppDaemon.swift`.
- Depends on: `AgentPetCore`, `NotificationManager`, `PetController`, `StatusBarController`.
- Used by: app startup through `AppDelegate`.

**UI Layer:**
- Purpose: Present state and settings through macOS native surfaces.
- Contains: menu bar controller/content, settings/onboarding, floating pet window, pet view, browse/download UI.
- Location: `Sources/App/`.
- Depends on: SwiftUI, AppKit, `AgentPetCore`.
- Used by: `AgentPetApp` and `AppDelegate`.

**Distribution Layer:**
- Purpose: Build app bundle, sign/notarize, package DMG, update appcast, publish releases.
- Contains: `scripts/build-app.sh`, `scripts/ci-dmg.sh`, `scripts/release.sh`, GitHub workflows.
- Depends on: SwiftPM, codesign, hdiutil/create-dmg, Sparkle signing tools, GitHub Actions.

## Data Flow

**Hook Event Processing:**

1. Agent hook invokes `agentpet hook --agent <kind> ...` or pipes a supported hook payload to stdin.
2. `Sources/App/CLI.swift` parses explicit flags or decodes the agent-native payload through `HookPayload`.
3. The helper creates an `AgentEvent` and calls `EventSender.send`.
4. `EventSender` writes newline-delimited JSON to `~/.agentpet/agentpet.sock`; if unavailable, it writes a queue file in `~/.agentpet/queue/`.
5. `AppDaemon.start()` drains queued events, starts `EventSocketServer`, and applies new events on the main actor.
6. `SessionStore.apply` maps native event names through `StateMapper` and creates/updates/removes sessions.
7. `AppDaemon.refresh()` updates `PetController` and `StatusBarController`; state transitions to waiting/done can trigger notifications and sounds.

**Generic CLI Wrapper Flow:**

1. User runs `agentpet run [flags] -- <command...>`.
2. `RunCLI` emits `working`, starts a heartbeat timer, launches child process with `/usr/bin/env`, waits, then emits `done`.
3. The same socket/queue and daemon path processes those normalized events.

**Pet Download Flow:**

1. `PetBrowser.loadIfNeeded()` fetches the Petdex manifest.
2. User picks a pet; `PetInstaller.download` downloads `pet.json` and spritesheet assets.
3. Files are stored under `~/.agentpet/pets/`.
4. `ImagePetStore.reload()` uses `SpriteSlicer.loadPack` to populate available packs.
5. `PetController.selectedPetID` persists the selected pack in UserDefaults.

**State Management:**
- Session state is in-memory and deterministic inside `SessionStore`; callers pass `now` for testability.
- Durable state is intentionally small and local: queued events, installed pets/sounds, UserDefaults preferences, hook config files.

## Key Abstractions

**AgentEvent:**
- Purpose: Normalized event envelope from any supported agent.
- Examples: Claude `Stop`, Codex `PermissionRequest`, Cursor `stop`, normalized `working`.
- Pattern: Codable value type passed over local JSON lines.

**StateMapper:**
- Purpose: Translate agent-native lifecycle names into `registered`, `working`, `waiting`, `done`, or `idle`.
- Examples: `.claude` `Notification` -> `.waiting`; `.codex` `PermissionRequest` -> `.waiting`.
- Pattern: Static mapping table with explicit unknown-event ignore behavior.

**SessionStore:**
- Purpose: Pure in-memory reducer plus pruning policy for active sessions.
- Examples: `apply`, `prune`, `sorted`, `remove`, `clear`.
- Pattern: deterministic state store, not internally thread-safe; app confines it to the main actor.

**HookInstaller / AgentHooks:**
- Purpose: Install/remove AgentPet hook entries across different agent config formats.
- Examples: Claude/Codex/Gemini nested hooks, Cursor/Windsurf flat hooks, opencode JS plugin.
- Pattern: pure dictionary/source transforms wrapped by disk I/O helpers.

**PetController:**
- Purpose: Resolve aggregate pet mood and manage chat/size/selection behavior.
- Examples: celebrate burst on done, waiting priority, UserDefaults-backed selected pet.
- Pattern: `@MainActor` singleton observable object.

## Entry Points

**App / CLI Entry:**
- Location: `Sources/App/AppEntry.swift`.
- Triggers: binary invocation.
- Responsibilities: dispatch to `HookCLI`, `RunCLI`, or `AgentPetApp.main()`.

**Menu Bar App Startup:**
- Location: `Sources/App/AgentPetApp.swift`.
- Triggers: default binary launch.
- Responsibilities: accessory app policy, pet/store startup, daemon start, hook migration, updater/status/settings startup.

**Hook CLI:**
- Location: `Sources/App/CLI.swift`.
- Triggers: installed hooks or explicit `agentpet hook`.
- Responsibilities: parse/decode event, send over socket/queue, exit with usage error when no event can be made.

**Run Wrapper CLI:**
- Location: `Sources/App/RunCLI.swift`.
- Triggers: `agentpet run -- <command>`.
- Responsibilities: emit working/done around child process, keep heartbeat alive, preserve child exit status.

## Error Handling

**Strategy:** Fail soft in app/daemon paths and fail explicit in CLI usage/build scripts.

**Patterns:**
- Runtime app setup often uses `try?` to avoid crashing user sessions for optional behavior (`AppDaemon.start`, settings hook toggles, pet reloads).
- Core transport returns Boolean success/fallback results (`EventSender.send`).
- CLI helper returns exit code `2` for missing/invalid hook input and `126` if wrapper child launch fails.
- Release/build scripts use `set -euo pipefail` for fail-fast automation.

## Cross-Cutting Concerns

**Threading:**
- `SessionStore` is deliberately not thread-safe; `AppDaemon` confines access to the main actor.
- Socket accepting runs on a background queue and hops to `@MainActor` before state mutation.

**Persistence:**
- UserDefaults for app preferences.
- File queue for reliable event delivery while app is closed.
- Hook installer writes user agent config files, preserving foreign hooks.

**Security:**
- Local-only Unix socket and hook config writes.
- Release signing/notarization requires external secrets; repo docs reference secret names but do not store secret values.
- `agentpet run` launches user-provided commands through `/usr/bin/env`; callers control the command.

**Notifications and Sounds:**
- `AppDaemon.notifyIfNeeded` only fires when state changes to waiting or done.
- User-facing notification permission and in-app mute live in `SettingsModel` and `NotificationManager`.

---

*Architecture analysis: 2026-06-04*
*Update when major runtime roles, event flow, or layer boundaries change*
