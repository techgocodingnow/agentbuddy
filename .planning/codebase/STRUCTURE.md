# Codebase Structure

**Analysis Date:** 2026-06-04

## Directory Layout

```
agentbuddy/
├── Sources/
│   ├── AgentPetCore/        # Pure core models, hook transforms, event transport, session state
│   └── App/                 # SwiftUI/AppKit app, CLI entry points, settings, pet UI, release-facing app code
├── Tests/
│   └── AgentPetCoreTests/   # XCTest coverage for core logic and hook integrations
├── scripts/                 # App bundle assembly, icon/banner generation, DMG/release automation
├── docs/                    # Static docs site, release appcast, localized READMEs, design specs
├── assets/                  # README/demo media and screenshots
├── .github/                 # CI/release workflows and issue templates
├── Package.swift            # SwiftPM package manifest
├── Package.resolved         # SwiftPM dependency lockfile
└── README.md                # User-facing project documentation
```

## Directory Purposes

**Sources/AgentPetCore:**
- Purpose: Platform-adjacent but UI-free core logic for event/session handling and hook installation.
- Contains: Swift source files for agent models, hook payloads, hook config transforms, event coding, socket transport, state mapping, and session storage.
- Key files: `StateMapper.swift`, `SessionStore.swift`, `EventSocketServer.swift`, `EventSender.swift`, `HookInstaller.swift`, `AgentHooks.swift`.
- Subdirectories: none.

**Sources/App:**
- Purpose: Executable target code: macOS app, CLI commands, pet UI, settings, updater, and local storage helpers.
- Contains: SwiftUI views, AppKit window/status controllers, CLI entry points, browser/download logic for pet packs, notification/sound/settings controllers.
- Key files: `AppEntry.swift`, `AgentPetApp.swift`, `AppDaemon.swift`, `CLI.swift`, `RunCLI.swift`, `SetupView.swift`, `StatusBarController.swift`, `PetController.swift`.
- Subdirectories: none; app code is currently a flat target directory.

**Tests/AgentPetCoreTests:**
- Purpose: XCTest suite for core behavior.
- Contains: tests for event mapping, session pruning/sorting, socket transport, hook installation shapes, hook payload decoding, pet mood mapping, and argument/sender behavior.
- Key files: `SessionStoreTests.swift`, `EventSocketServerTests.swift`, `HookInstallerTests.swift`, `MultiAgentHookTests.swift`, `HookAndSenderTests.swift`.

**scripts:**
- Purpose: Local and CI build/release support plus generated visual assets.
- Contains: shell scripts, app Info.plist, icon/banner generation Swift scripts, DMG background assets.
- Key files: `build-app.sh`, `ci-dmg.sh`, `release.sh`, `AppInfo.plist`, `AppIcon.icns`.

**docs:**
- Purpose: Release/distribution docs and project design/reference material.
- Contains: static landing page, Sparkle appcast, release instructions, localized README copies, specs.
- Key files: `docs/appcast.xml`, `docs/RELEASING.md`, `docs/specs/2026-05-29-agentpet-design.md`.

**assets:**
- Purpose: README visuals and demo media.
- Contains: banner, screenshots, demo GIF/video assets.

**.github:**
- Purpose: GitHub automation and contribution surfaces.
- Contains: workflows and issue templates.
- Key files: `.github/workflows/ci.yml`, `.github/workflows/release.yml`.

## Key File Locations

**Entry Points:**
- `Sources/App/AppEntry.swift` - `@main` entry and binary role dispatch.
- `Sources/App/AgentPetApp.swift` - SwiftUI app and `AppDelegate` startup.
- `Sources/App/CLI.swift` - `agentpet hook` command.
- `Sources/App/RunCLI.swift` - `agentpet run` command wrapper.

**Configuration:**
- `Package.swift` - SwiftPM package, targets, platform, Sparkle dependency.
- `Package.resolved` - dependency resolution lockfile.
- `scripts/AppInfo.plist` - macOS bundle metadata and Sparkle settings.
- `.github/workflows/ci.yml` - build/test CI.
- `.github/workflows/release.yml` - tagged release publishing.
- `.gitignore` - build/user scratch exclusions.

**Core Logic:**
- `Sources/AgentPetCore/StateMapper.swift` - event-name-to-state mapping.
- `Sources/AgentPetCore/SessionStore.swift` - session reducer and pruning/sorting policy.
- `Sources/AgentPetCore/EventSocketServer.swift` - socket listener and queue draining.
- `Sources/AgentPetCore/EventSender.swift` - socket client and fallback queue writer.
- `Sources/AgentPetCore/HookInstaller.swift` - hook config install/remove transforms and disk I/O.
- `Sources/AgentPetCore/HookPayloads.swift` and `ClaudeHookPayload.swift` - stdin payload decoding.

**UI and App Behavior:**
- `Sources/App/AppDaemon.swift` - live state owner and notification trigger.
- `Sources/App/MenuBarContentView.swift` - menu bar dropdown content.
- `Sources/App/StatusBarController.swift` - status item state.
- `Sources/App/PetController.swift` - aggregate pet mood and chat.
- `Sources/App/PetWindowController.swift` and `PetView.swift` - floating pet surface.
- `Sources/App/SetupView.swift` and `SettingsModel.swift` - settings/onboarding.
- `Sources/App/PetBrowser.swift`, `PetInstaller.swift`, `ImagePetStore.swift`, `SpriteSlicer.swift` - pet library and local pet pack handling.

**Testing:**
- `Tests/AgentPetCoreTests/*.swift` - all current automated tests.

**Documentation:**
- `README.md` - main user documentation.
- `docs/readme/*.md` - localized README variants.
- `docs/RELEASING.md` - release process.
- `docs/specs/2026-05-29-agentpet-design.md` - original design spec.

## Naming Conventions

**Files:**
- PascalCase Swift files for types and views (`SessionStore.swift`, `SetupView.swift`, `PetController.swift`).
- Shell scripts are kebab-case or short descriptive names in `scripts/`.
- Important docs are uppercase markdown (`README.md`, `CONTRIBUTING.md`, `LICENSE`).

**Directories:**
- SwiftPM conventional directories: `Sources/<TargetName>/`, `Tests/<TargetName>Tests/`.
- Lowercase utility/doc directories: `scripts/`, `docs/`, `assets/`.

**Special Patterns:**
- Test files end with `Tests.swift`.
- App target files are flat rather than grouped by feature subdirectories.
- Runtime data is outside the repo under `~/.agentpet`, not committed.

## Where to Add New Code

**New agent integration:**
- Core hook spec and event mapping: `Sources/AgentPetCore/AgentHooks.swift`, `StateMapper.swift`, `AgentCatalog.swift`.
- Payload parser if stdin shape differs: `Sources/AgentPetCore/HookPayloads.swift`.
- Settings UI should usually update automatically through `AgentCatalog.all`.
- Tests: add/extend `Tests/AgentPetCoreTests/MultiAgentHookTests.swift` and `SessionStoreTests.swift`.

**New event/session behavior:**
- Core implementation: `Sources/AgentPetCore/SessionStore.swift` or `StateMapper.swift`.
- App reaction: `Sources/App/AppDaemon.swift`, `PetController.swift`, `StatusBarController.swift`.
- Tests: `Tests/AgentPetCoreTests/SessionStoreTests.swift`.

**New settings/control:**
- Model/state: `Sources/App/SettingsModel.swift` or a dedicated settings object if already established for that domain.
- UI: `Sources/App/SetupView.swift`.
- Persistence: UserDefaults unless it is a file-backed asset.

**New pet-pack behavior:**
- Local pack parsing/loading: `Sources/App/SpriteSlicer.swift`, `ImagePetStore.swift`, `PetBindings.swift`.
- Remote browser/download: `Sources/App/PetBrowser.swift`, `PetInstaller.swift`, `BrowsePetsView.swift`.
- UI controls: `Sources/App/SetupView.swift` pet tab.

**New release/build behavior:**
- Local app bundle assembly: `scripts/build-app.sh`.
- Local signed/notarized release: `scripts/release.sh`.
- CI release: `scripts/ci-dmg.sh` and `.github/workflows/release.yml`.

## Special Directories

**build/ and .build/:**
- Purpose: generated app bundle, DMGs, SwiftPM build output.
- Source: `swift build`, release scripts.
- Committed: No, ignored by `.gitignore`.

**.planning/:**
- Purpose: GSD planning and codebase map artifacts.
- Source: local planning workflow.
- Committed: Yes when `commit_docs` is true.

**.claude/, .codegraph/, .gitnexusignore, AGENTS.md, CLAUDE.md:**
- Purpose: currently untracked local/tooling files detected during mapping.
- Source: local agent/tooling state.
- Committed: undecided; do not assume these are project source without an explicit commit-scope review.

---

*Structure analysis: 2026-06-04*
*Update when directory layout or target boundaries change*
