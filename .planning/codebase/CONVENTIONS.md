# Coding Conventions

**Analysis Date:** 2026-06-04

## Naming Patterns

**Files:**
- PascalCase Swift files named after the primary type or view: `SessionStore.swift`, `EventSocketServer.swift`, `SetupView.swift`.
- XCTest files end with `Tests.swift`: `HookInstallerTests.swift`, `MultiAgentHookTests.swift`.
- Shell scripts use descriptive lowercase/kebab-case names: `build-app.sh`, `ci-dmg.sh`, `release.sh`.

**Functions:**
- Swift lowerCamelCase for methods and functions: `applicationDidFinishLaunching`, `toggleInstall`, `refreshNotificationState`.
- Boolean predicates use `is`/`has` style where natural: `isInstalled`, `isAvailable`, `isSessionEnd`.
- Internal helper functions are often private and narrow: `notifyIfNeeded`, `settleAfterCelebrate`, `writeToSocket`.

**Variables:**
- lowerCamelCase for variables and properties: `selectedPetID`, `notificationState`, `installedKinds`.
- Static singleton instances are named `shared`: `AppDaemon.shared`, `SettingsModel.shared`, `PetController.shared`.
- Constants are usually `static let` lowerCamelCase, not all-caps: `petKey`, `manifestURL`, `celebrateDuration`.

**Types:**
- PascalCase for structs, enums, classes, and protocols.
- Enum cases are lowerCamelCase: `.working`, `.waiting`, `.claudeNested`.
- Observable app controllers are often `@MainActor final class ...: ObservableObject`.

## Code Style

**Formatting:**
- Standard Swift formatting with 4-space indentation.
- Short guard/if expressions are sometimes compact but still readable (`guard bound == 0 else { close(fd); throw ... }`).
- UI code favors SwiftUI view builders and small private subviews inside `SetupView.swift`.

**Linting:**
- No SwiftLint or formatter config is currently present.
- CI enforces compilation and tests through `.github/workflows/ci.yml`, not style linting.

## Import Organization

**Order:**
1. Apple/system frameworks (`Foundation`, `SwiftUI`, `AppKit`, `UserNotifications`).
2. Package/internal modules (`AgentBuddyCore`, `Sparkle`).

**Grouping:**
- Imports are simple and not separated by blank-line groups.
- Avoid adding path aliases; SwiftPM target imports are direct module imports.

## Error Handling

**Patterns:**
- Core pure logic returns optionals/booleans for expected failures: `StateMapper.state` returns `nil` for unknown events; `EventSender.send` returns socket delivery success.
- App startup and optional feature paths frequently use `try?` to keep the app resilient: queue directory creation, server startup, hook toggles, pet file operations.
- CLI usage errors exit explicitly with messages (`CLI.swift`, `RunCLI.swift`).
- Build and release scripts use `set -euo pipefail`.

**Error Types:**
- Transport setup has typed errors in `SocketError`.
- User-facing download/setup failures are usually state properties such as `PetBrowser.errorText`.
- There is no project-wide custom error hierarchy.

## Logging

**Framework:**
- No logging framework is used.
- Shell scripts use `echo` progress output.
- CLI helpers write usage/launch errors to stderr with `FileHandle.standardError`.

**Patterns:**
- Runtime app errors are mostly silent or surfaced as UI state. Add explicit user-facing state for errors that affect workflows.
- Avoid adding noisy console output to app code unless it is part of a CLI path.

## Comments

**When to Comment:**
- Existing comments explain architectural intent or edge-case rationale, not line-by-line mechanics.
- Examples: `AppDaemon.swift` explains queued event replay timestamps; `RunCLI.swift` explains signal handling; `HookInstaller.swift` explains config shapes.
- Keep comments short and targeted around non-obvious macOS, socket, or hook behavior.

**Documentation Comments:**
- Public core types and important app controllers commonly have `///` comments.
- Continue this pattern for public APIs in `AgentBuddyCore`.

**TODO Comments:**
- No strong TODO convention is present. Prefer issue-backed docs or concise comments if a limitation is intentionally deferred.

## Function Design

**Size:**
- Core functions are generally small and testable.
- SwiftUI view files can be large but are split into private nested view structs and computed properties.

**Parameters:**
- Initializers use explicit named parameters.
- Core helpers pass dependency/time values explicitly for testability, e.g. `SessionStore.apply(_:now:)` and `prune(now:)`.

**Return Values:**
- Return optionals for ignored/unparseable events.
- Return booleans for transport delivery fallback.
- CLI commands return `Never` and exit with status codes.

## Module Design

**Exports:**
- `AgentBuddyCore` exposes public value types and services used by the app target and tests.
- `Sources/App` types are mostly internal by default.
- No barrel/index files; SwiftPM module membership is directory based.

**Singletons:**
- The app uses shared observable singletons for UI/controller state (`AppDaemon`, `SettingsModel`, `PetController`, `ImagePetStore`, `UpdaterController`).
- Keep new singleton state `@MainActor` if it mutates UI-observed properties.

**Threading:**
- UI/state mutation should happen on the main actor.
- Background callbacks should hop to `Task { @MainActor ... }` before touching observable state.

---

*Convention analysis: 2026-06-04*
*Update when formatting/linting or code organization rules are introduced*
