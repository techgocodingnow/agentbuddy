import XCTest
@testable import AgentBuddyCore

final class HookInstallerTests: XCTestCase {
    private let cmd = "\"/Applications/AgentBuddy.app/Contents/MacOS/agentbuddy\" hook"

    private func groups(_ settings: [String: Any], _ event: String) -> [[String: Any]] {
        (settings["hooks"] as? [String: Any])?[event] as? [[String: Any]] ?? []
    }

    func testInstallIntoEmptyAddsAllEvents() {
        let result = HookInstaller.install(into: [:], command: cmd)
        XCTAssertTrue(HookInstaller.isInstalled(in: result))
        for event in HookInstaller.events {
            XCTAssertEqual(groups(result, event).count, 1, "event \(event)")
        }
    }

    func testInstallIsIdempotent() {
        let once = HookInstaller.install(into: [:], command: cmd)
        let twice = HookInstaller.install(into: once, command: cmd)
        for event in HookInstaller.events {
            XCTAssertEqual(groups(twice, event).count, 1, "no duplicate on \(event)")
        }
    }

    func testInstallPreservesForeignHooks() {
        let existing: [String: Any] = [
            "hooks": ["Stop": [["hooks": [["type": "command", "command": "echo done"]]]]],
        ]
        let result = HookInstaller.install(into: existing, command: cmd)
        XCTAssertEqual(groups(result, "Stop").count, 2, "foreign + ours")
    }

    func testUninstallRemovesOursKeepsForeign() {
        let existing: [String: Any] = [
            "hooks": ["Stop": [["hooks": [["type": "command", "command": "echo done"]]]]],
        ]
        let installed = HookInstaller.install(into: existing, command: cmd)
        let removed = HookInstaller.uninstall(from: installed)
        XCTAssertFalse(HookInstaller.isInstalled(in: removed))
        XCTAssertEqual(groups(removed, "Stop").count, 1, "foreign hook survives")
        // Events that were only ours are dropped entirely.
        XCTAssertTrue(groups(removed, "SessionStart").isEmpty)
    }

    func testUninstallFromCleanIsNoop() {
        let removed = HookInstaller.uninstall(from: [:])
        XCTAssertNil(removed["hooks"])
    }

    func testDiskRoundTrip() throws {
        let path = NSTemporaryDirectory() + "settings-\(UUID().uuidString).json"
        defer { try? FileManager.default.removeItem(atPath: path) }
        try HookInstaller.installToDisk(command: cmd, path: path)
        XCTAssertTrue(HookInstaller.isInstalledOnDisk(path: path))
        try HookInstaller.uninstallFromDisk(path: path)
        XCTAssertFalse(HookInstaller.isInstalledOnDisk(path: path))
    }

    func testCodexTomlInstallAddsInlineHooksAndEnablesFeature() {
        let existing = """
        model = "gpt-5.5"

        [features]
        hooks = false
        """

        let result = HookInstaller.installCodexToml(into: existing, command: cmd + " --agent codex", events: ["SessionStart", "PreToolUse"])

        XCTAssertTrue(HookInstaller.isInstalledCodexToml(result))
        XCTAssertTrue(result.contains("[[hooks.SessionStart]]"))
        XCTAssertTrue(result.contains("[[hooks.PreToolUse.hooks]]"))
        XCTAssertTrue(result.contains("hooks = true"))
        XCTAssertFalse(result.contains("hooks = false"))
    }

    func testCodexTomlInstallIsIdempotentAndUninstallKeepsForeignConfig() {
        let existing = """
        model = "gpt-5.5"

        [[hooks.Stop]]
        [[hooks.Stop.hooks]]
        type = "command"
        command = "echo foreign"
        """

        let once = HookInstaller.installCodexToml(into: existing, command: cmd + " --agent codex", events: ["Stop"])
        let twice = HookInstaller.installCodexToml(into: once, command: cmd + " --agent codex", events: ["Stop"])

        XCTAssertEqual(twice.components(separatedBy: "[[hooks.Stop]]").count - 1, 2)

        let removed = HookInstaller.uninstallCodexToml(from: twice)
        XCTAssertFalse(HookInstaller.isInstalledCodexToml(removed))
        XCTAssertTrue(removed.contains("echo foreign"))
    }
}
