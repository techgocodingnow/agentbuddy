# Phase 3 Smoke Report

**Date:** 2026-06-04
**Scope:** Verify the one-pet, many-sessions UI after Phase 1 and Phase 2.

## Automated Gates

| Check | Result | Evidence |
|-------|--------|----------|
| `rtk swift test` | Pass | 61 tests, 0 failures |
| `rtk swift build` | Pass | `ok (build complete)` |
| `rtk ./scripts/build-app.sh debug` | Pass | Built and ad-hoc signed `build/AgentBuddy.app` |

## App Launch

Command:

```bash
rtk ./scripts/build-app.sh debug
rtk open build/AgentBuddy.app
```

The app launched successfully from `build/AgentBuddy.app`. A process check showed the debug app running as:

```text
/Users/kevin/Desktop/opensources/agentbuddy/build/AgentBuddy.app/Contents/MacOS/agentbuddy
```

The first launch welcome window appeared once and was closed before the clean smoke screenshot.

## Simulated Session Matrix

Commands:

```bash
BIN="$(rtk swift build --show-bin-path)/agentbuddy"
rtk "$BIN" hook --agent codex --event PermissionRequest --session smoke-codex --project "$PWD" --message "Create gsd new project"
rtk "$BIN" hook --agent claude --event UserPromptSubmit --session smoke-claude --project "$PWD" --message "Update README credits"
rtk "$BIN" hook --agent cli --event working --session smoke-cli --project "$PWD" --message "Checking release notes"
rtk "$BIN" hook --agent gemini --event Notification --session smoke-gemini --project "$PWD" --message "Needs approval"
```

Screenshots captured:

- `/tmp/agentbuddy-smoke-1.png` - first launch window plus active pet/cards visible.
- `/tmp/agentbuddy-smoke-2.png` - clean target state after closing first launch window.
- `/tmp/agentbuddy-smoke-final.png` - final clean evidence in the running desktop context.
- `/tmp/agentbuddy-smoke-quartz-reply.png` - lower-level click attempt with Reply still visible.
- `/tmp/agentbuddy-smoke-cleanup.png` - active cards cleared back to idle pet after cleanup.

## Observations

| Behavior | Result | Notes |
|----------|--------|-------|
| One pet for multiple sessions | Pass | Smoke state showed one floating pet, not one pet per session. |
| Compact aggregate summary | Pass | Bubble showed `2 waiting - 2 working` for four active sessions. |
| Pet-adjacent session cards | Pass | Stack showed three bounded cards and an overflow row. |
| Waiting priority | Pass | Waiting sessions were sorted before the working session. |
| Reply visibility | Pass | Waiting cards displayed visible `Reply` buttons. Working cards did not. |
| Overflow behavior | Pass | Fourth active session collapsed into `+1 more - 2 waiting - 2 working`. |
| Empty/idle cleanup | Pass | Sending direct `idle` events removed active cards and returned to the idle pet. |
| Menu rows | Pass by implementation path | `MenuBarContentView` uses the same non-idle session set and renders per-session rows with `Reply` for waiting sessions. Direct status item/menu click was not reliable in the fullscreen Codex desktop context. |
| Reply click action | Partially verified | `SessionReplyController.reply(to:)` copies concise context and opens the status popover. The button was visible in smoke screenshots, but AppleScript and Quartz coordinate clicks did not activate it in this desktop context, leaving the clipboard unchanged. |

## Reply Automation Attempts

AppleScript coordinate click:

```bash
rtk osascript -e 'tell application "System Events" to click at {1903, 902}'
```

Result:

```text
System Events got an error: An error of type -25200 has occurred. (-25200)
```

Accessibility inspection exposed the floating panel as an unnamed system dialog with no button objects:

```text
window=, role=system dialog, buttons=
```

Quartz event click:

```bash
rtk swift -e 'import CoreGraphics; let p = CGPoint(x: 1904, y: 902); CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap); usleep(120000); CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)'
```

Result: the visible UI remained unchanged and the clipboard still contained older unrelated text.

This is recorded as a smoke automation limitation, not a source defect, because the visible affordance exists and the source action is wired through `SessionReplyController.reply(to:)`.

## Cleanup

Cleanup commands:

```bash
BIN="$(rtk swift build --show-bin-path)/agentbuddy"
for sid in smoke-codex smoke-claude smoke-cli smoke-gemini; do
  rtk "$BIN" hook --agent cli --event idle --session "$sid" --project "$PWD" --message "smoke cleanup"
done
rtk pkill -f '/Users/kevin/Desktop/opensources/agentbuddy/build/AgentBuddy.app/Contents/MacOS/agentbuddy' || true
```

After cleanup, `rtk pgrep -fl 'AgentBuddy|agentbuddy' || true` returned no running debug app process.

## Polish

No source or README polish was needed. The smoke findings match the intended Phase 2 implementation, and the remaining limitation is test automation access to the floating SwiftUI panel.
