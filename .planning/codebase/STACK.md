# Technology Stack

**Analysis Date:** 2026-06-04

## Languages

**Primary:**
- Swift 6.0 - All app, CLI helper, and core library code. The Swift tools version is declared in `Package.swift`.

**Secondary:**
- Bash - Build, CI DMG, and local release automation in `scripts/build-app.sh`, `scripts/ci-dmg.sh`, and `scripts/release.sh`.
- HTML/XML/SVG - Static docs and release assets in `docs/index.html`, `docs/appcast.xml`, and `scripts/dmg-background.svg`.

## Runtime

**Environment:**
- macOS 13+ - Declared as `.macOS(.v13)` in `Package.swift` and reflected in `scripts/AppInfo.plist`.
- Xcode 16 / Swift 6 - CI selects `/Applications/Xcode_16.app` in `.github/workflows/ci.yml`.
- Single executable role split - `Sources/App/AppEntry.swift` launches either the menu bar app or CLI subcommands (`hook`, `run`) from the same `agentpet` binary.

**Package Manager:**
- Swift Package Manager - `Package.swift` and `Package.resolved` are the package definition and dependency lockfile.

## Frameworks

**Core:**
- SwiftUI - Native app UI in `Sources/App/AgentPetApp.swift`, `Sources/App/SetupView.swift`, and menu/pet views.
- AppKit - Menu bar accessory, floating windows, notifications/system settings hooks, and bundle behavior across `Sources/App/*WindowController.swift`, `Sources/App/StatusBarController.swift`, and related files.
- Foundation - Core event models, Unix socket server/client, JSON coding, file queue, timers, and CLI argument parsing in `Sources/AgentPetCore/`.

**Testing:**
- XCTest - Unit tests in `Tests/AgentPetCoreTests/`.

**Build/Dev:**
- SwiftPM build and test commands - `swift build`, `swift test`.
- `codesign`, `hdiutil`, `xcrun notarytool`, `xcrun stapler` - Release and distribution pipeline in `scripts/release.sh` and `scripts/ci-dmg.sh`.
- `create-dmg` - Required by the local `scripts/release.sh` path for branded DMG layout.

## Key Dependencies

**Critical:**
- Sparkle 2.6.0+ - Auto-update framework declared in `Package.swift`, bundled in `scripts/build-app.sh`, and initialized by `Sources/App/UpdaterController.swift`.
- Apple UserNotifications - Native completion/waiting notifications via `Sources/App/NotificationManager.swift` and `Sources/App/SettingsModel.swift`.
- ServiceManagement - Login item support through `Sources/App/LoginItem.swift`.

**Infrastructure:**
- Unix domain sockets - Local event transport implemented in `Sources/AgentPetCore/EventSocketServer.swift` and `Sources/AgentPetCore/EventSender.swift`.
- UserDefaults - User preferences for pet, chat, sounds, onboarding, and migration state across `Sources/App/`.
- File system storage under `~/.agentpet` - Event queue, pet packs, and custom sounds are persisted through `AgentPetPaths` and app storage classes.

## Configuration

**Environment:**
- No required runtime environment variables for normal app usage.
- Release automation uses optional signing/notarization environment variables in `.github/workflows/release.yml`: `MACOS_CERT_P12`, `MACOS_CERT_PASSWORD`, `MACOS_SIGN_IDENTITY`, `AC_API_KEY_P8`, `AC_KEY_ID`, and `AC_ISSUER_ID`.
- Local notarization uses a notarytool keychain profile named by `NOTARY_PROFILE` or default `agentpet` in `scripts/release.sh`.

**Build:**
- `Package.swift` - Swift package targets and dependencies.
- `scripts/AppInfo.plist` - App bundle metadata, identifier, Sparkle feed/public key, and LSUIElement behavior.
- `.github/workflows/ci.yml` - CI build and test.
- `.github/workflows/release.yml` - Tagged release publishing.

## Platform Requirements

**Development:**
- macOS with Xcode 16 / Swift 6.
- Network access to fetch Sparkle via SwiftPM on first dependency resolution.
- `create-dmg` only for local branded release flow; CI uses `hdiutil` directly.

**Production:**
- Distributed as a macOS `.app` inside a DMG.
- App runs as a menu bar accessory with no Dock icon.
- Notarized Developer ID distribution is supported when credentials are available; ad-hoc signed builds are possible for local/unsigned CI paths.

---

*Stack analysis: 2026-06-04*
*Update after major dependency, deployment, or macOS target changes*
