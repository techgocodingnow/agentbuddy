# External Integrations

**Analysis Date:** 2026-06-04

## APIs & External Services

**Petdex Manifest API:**
- Petdex public pet library - In-app browse/download source for community pet packs.
  - Integration method: `URLSession.shared.data(from:)` in `Sources/App/PetBrowser.swift` and `Sources/App/PetInstaller.swift`.
  - Endpoint: `https://petdex.crafter.run/api/manifest`.
  - Auth: none in code.
  - Failure behavior: shows user-facing error text in the browse UI or silently skips starter-pet bootstrap if the manifest cannot be loaded.

**GitHub Releases:**
- GitHub Releases - DMG publishing for `v*` tags.
  - Integration method: GitHub Actions workflow `.github/workflows/release.yml`.
  - Client: `gh release view/create/upload` using `GH_TOKEN`.
  - Artifacts: `build/*.dmg`.

**Sparkle Appcast:**
- Sparkle update feed - App update discovery.
  - SDK/Client: Sparkle framework from `Package.swift`.
  - App configuration: `SUFeedURL` and `SUPublicEDKey` in `scripts/AppInfo.plist`.
  - Feed file: `docs/appcast.xml`.
  - Runtime owner: `Sources/App/UpdaterController.swift`.

## Data Storage

**Local Files:**
- `~/.agentpet/agentpet.sock` - Unix socket used by hooks and CLI wrappers to send events to the app daemon.
- `~/.agentpet/queue/` - Queue for events emitted while the app daemon is not listening; drained by `EventSocketServer.drainQueue`.
- `~/.agentpet/pets/` - Installed pet packs loaded by `Sources/App/ImagePetStore.swift`.
- App preferences - UserDefaults store pet selection, size, chat visibility/content, notification toggle, sound settings, onboarding, and hook migration flags.

**Databases:**
- None. Session state is in-memory in `Sources/AgentPetCore/SessionStore.swift`; durable state is file/UserDefaults based.

**Caching:**
- No server-side or shared cache. Remote pet results live in memory in `PetBrowser` during the UI session.

## Authentication & Identity

**User Authentication:**
- None. This is a local macOS utility.

**Agent Hook Identity:**
- Agent type is selected from CLI flags or hook payloads and mapped through `AgentKind`.
- Supported hook config locations are defined in `Sources/AgentPetCore/AgentHooks.swift`.

## Monitoring & Observability

**Error Tracking:**
- None. There is no Sentry or remote error reporter.

**Analytics:**
- None. No product analytics integration is present.

**Logs:**
- Build/release scripts print command progress.
- Runtime errors are mostly handled with optional `try?` paths and user-facing state, not centralized logs.

## CI/CD & Deployment

**CI Pipeline:**
- GitHub Actions CI in `.github/workflows/ci.yml`.
  - Runs on `macos-15`.
  - Selects Xcode 16.
  - Runs `swift build` and `swift test`.

**Release Pipeline:**
- GitHub Actions release in `.github/workflows/release.yml`.
  - Trigger: pushing tags matching `v*`.
  - Imports Developer ID certificate when signing secrets exist.
  - Runs `./scripts/ci-dmg.sh`.
  - Uploads DMG to the matching GitHub Release.

**Local Release:**
- `scripts/release.sh` builds, signs, notarizes, staples, builds a branded DMG, and prints a Sparkle appcast item.
- `scripts/build-app.sh` builds a universal app bundle and copies Sparkle.framework into `Contents/Frameworks`.

## Environment Configuration

**Development:**
- Required env vars: none for build/test.
- Optional release tools: Developer ID identity, notarytool profile, `create-dmg`.

**Production:**
- Code signing and notarization secrets live outside the repo or in GitHub Actions secrets.
- Sparkle appcast is hosted from the repo docs site/release URL configured in `scripts/AppInfo.plist`.

## Webhooks & Callbacks

**Incoming Local Hooks:**
- Claude Code, Codex, Gemini, Cursor, Windsurf, and opencode integrations are local config/plugin hooks that invoke the bundled binary.
- Hook target: `"agentpet" hook --agent <kind>`.
- Install/remove logic: `Sources/AgentPetCore/HookInstaller.swift`.
- Config paths: `~/.claude/settings.json`, `~/.codex/hooks.json`, `~/.gemini/settings.json`, `~/.cursor/hooks.json`, `~/.codeium/windsurf/hooks.json`, and `~/.config/opencode/plugin/agentpet.js`.

**Outgoing Network Calls:**
- Pet library manifest and pet asset downloads.
- Sparkle update checks.
- Release-time GitHub upload and Apple notarization calls.

---

*Integration audit: 2026-06-04*
*Update when adding/removing services, hooks, release channels, or external feeds*
