# Testing Patterns

**Analysis Date:** 2026-06-04

## Test Framework

**Runner:**
- XCTest through Swift Package Manager.
- Tests live in the `AgentBuddyCoreTests` test target declared in `Package.swift`.

**Assertion Library:**
- XCTest assertions: `XCTAssertEqual`, `XCTAssertNil`, `XCTAssertTrue`, `XCTAssertFalse`, `XCTAssertNotNil`, expectations.

**Run Commands:**
```bash
swift test                 # Run all tests
swift test --filter Name   # Run tests matching a filter
swift build                # Compile all package targets
```

## Test File Organization

**Location:**
- Tests are centralized under `Tests/AgentBuddyCoreTests/`.
- There are currently no UI test targets or app snapshot tests.

**Naming:**
- Test files end with `Tests.swift`.
- Test classes use `final class <Area>Tests: XCTestCase`.

**Structure:**
```
Tests/
└── AgentBuddyCoreTests/
    ├── SessionStoreTests.swift
    ├── HookInstallerTests.swift
    ├── EventSocketServerTests.swift
    ├── HookAndSenderTests.swift
    ├── ClaudeHookPayloadTests.swift
    ├── MultiAgentHookTests.swift
    ├── AgentCatalogTests.swift
    └── PetTests.swift
```

## Test Structure

**Suite Organization:**
```swift
final class SessionStoreTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testApplyCreatesSession() {
        let store = SessionStore()
        let result = store.apply(event("SessionStart"), now: t0)
        XCTAssertEqual(result?.state, .registered)
    }
}
```

**Patterns:**
- Test names start with `test` and describe behavior.
- Time-dependent logic passes fixed `Date` values into core APIs.
- Temporary files/directories use `NSTemporaryDirectory()` plus UUID and `defer` cleanup.
- Socket tests use XCTest expectations with a short timeout.

## Mocking

**Framework:**
- No mocking framework is used.
- Tests construct concrete value types and temporary files directly.

**Patterns:**
```swift
let tmp = NSTemporaryDirectory() + "agentbuddy-test-\(UUID().uuidString)/"
defer { try? FileManager.default.removeItem(atPath: tmp) }
```

**What to Mock:**
- Prefer temporary files/directories over mocks for file-system behavior.
- Prefer deterministic injected inputs (`Date`, event values, paths) over global state.

**What NOT to Mock:**
- Pure core logic such as `StateMapper`, `SessionStore`, and hook transform functions.
- JSON encode/decode paths; tests should exercise real coders.

## Fixtures and Factories

**Test Data:**
- Small helper methods inside test classes create events, e.g. `private func event(_ name:session:project:)`.
- Inline JSON strings are used for hook payload decoding tests.

**Location:**
- No shared fixture directory exists.
- Add local helper functions in the test file first; introduce shared fixtures only if duplication grows.

## Coverage

**Requirements:**
- No explicit coverage threshold is configured.
- CI requires `swift build` and `swift test` to pass.

**Configuration:**
- No coverage configuration is present.

**View Coverage:**
```bash
swift test --enable-code-coverage
```

## Test Types

**Unit Tests:**
- Scope: core mapping, session state, hook install/remove transforms, payload parsing, argument parsing, sender fallback, pet mood logic.
- Mocking: none or minimal temp file/socket setup.
- Speed: designed to be fast SwiftPM unit tests.

**Integration Tests:**
- `EventSocketServerTests` verifies real Unix socket delivery.
- `HookAndSenderTests` verifies queue fallback and CLI-ish argument behavior.
- Disk round-trip tests verify hook installer output for multiple config shapes.

**UI Tests:**
- None currently. `Sources/App` SwiftUI/AppKit behavior is mostly untested by automation.

**E2E Tests:**
- None currently. There is no automated installed-app or hook-to-UI end-to-end suite.

## Common Patterns

**Async/Callback Testing:**
```swift
let exp = expectation(description: "event delivered")
try server.start { event in
    box.value = event
    exp.fulfill()
}
wait(for: [exp], timeout: 2)
```

**Error Testing:**
```swift
XCTAssertNil(StateMapper.state(for: .claude, eventName: "Bogus"))
XCTAssertFalse(HookInstaller.isInstalledOnDisk(path: path))
```

**State Testing:**
- Assert both returned session and stored session state.
- For pruning, advance the fixed clock across thresholds and assert demotion/removal.

## Gaps to Consider

**App/UI coverage:**
- `AppDaemon`, menu bar rendering, settings toggles, pet window behavior, notifications, and Sparkle updater behavior are not directly tested.

**Release coverage:**
- Scripts are not covered by automated tests beyond GitHub Actions running build/test and release workflow invocation on tags.

**Network behavior:**
- Petdex manifest/download behavior is not tested with URLSession stubs.

---

*Testing analysis: 2026-06-04*
*Update when new test targets, UI tests, or coverage gates are introduced*
