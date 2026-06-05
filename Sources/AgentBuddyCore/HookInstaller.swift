import Foundation

/// Installs/removes AgentBuddy's hook entries in an agent's config. Claude Code
/// and Gemini use nested JSON, Codex uses inline TOML, Cursor and Windsurf use
/// flatter JSON shapes, and opencode uses a JS plugin file. The shape is
/// selected by `HookStyle`.
///
/// The dictionary transforms are pure (and tested); the `*OnDisk` helpers wrap
/// them with file IO. Our entries are identified by their command string, so
/// install is idempotent and foreign hooks are never touched.
public enum HookInstaller {
    public static let events = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "Notification", "Stop", "SubagentStop",
    ]
    private static let defaultHookTimeout = 10
    private static let responseHookTimeout = 600
    private static let responseWaitingEvents: Set<String> = ["PermissionRequest", "Elicitation"]

    public static func defaultSettingsPath() -> String {
        NSHomeDirectory() + "/.claude/settings.json"
    }

    static func isOurs(_ command: String) -> Bool {
        let lowercased = command.lowercased()
        return lowercased.contains("hook")
            && lowercased.contains("agentbuddy")
    }

    // MARK: - Claude-nested shape (Claude / Codex / Gemini)

    public static func isInstalled(in settings: [String: Any], events: [String] = events) -> Bool {
        guard let hooks = settings["hooks"] as? [String: Any] else { return false }
        for event in events {
            guard let groups = hooks[event] as? [[String: Any]] else { continue }
            if groups.contains(where: groupIsOurs) { return true }
        }
        return false
    }

    public static func install(into settings: [String: Any], command: String, events: [String] = events) -> [String: Any] {
        var settings = settings
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var groups = (hooks[event] as? [[String: Any]] ?? []).filter { !groupIsOurs($0) }
            groups.append(["hooks": [commandHook(command: command, event: event)]])
            hooks[event] = groups
        }
        settings["hooks"] = hooks
        return settings
    }

    private static func commandHook(command: String, event: String) -> [String: Any] {
        var hook: [String: Any] = ["type": "command", "command": command]
        if responseWaitingEvents.contains(event) {
            hook["timeout"] = responseHookTimeout
        }
        return hook
    }

    public static func uninstall(from settings: [String: Any], events: [String] = events) -> [String: Any] {
        var settings = settings
        guard var hooks = settings["hooks"] as? [String: Any] else { return settings }
        for event in events {
            guard let groups = hooks[event] as? [[String: Any]] else { continue }
            let kept = groups.filter { !groupIsOurs($0) }
            if kept.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = kept }
        }
        if hooks.isEmpty { settings.removeValue(forKey: "hooks") } else { settings["hooks"] = hooks }
        return settings
    }

    private static func groupIsOurs(_ group: [String: Any]) -> Bool {
        guard let inner = group["hooks"] as? [[String: Any]] else { return false }
        return inner.contains { ($0["command"] as? String).map(isOurs) ?? false }
    }

    // MARK: - Flat shape (Cursor / Windsurf): {"hooks": {event: [{"command": ...}]}}

    private static func flatItemIsOurs(_ item: [String: Any]) -> Bool {
        (item["command"] as? String).map(isOurs) ?? false
    }

    static func installFlat(into settings: [String: Any], command: String, events: [String], style: HookStyle) -> [String: Any] {
        var settings = settings
        if style == .cursorFlat { settings["version"] = settings["version"] ?? 1 }
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var items = (hooks[event] as? [[String: Any]] ?? []).filter { !flatItemIsOurs($0) }
            var entry: [String: Any] = ["command": command]
            if style == .cursorFlat { entry["type"] = "command" }
            if style == .windsurfFlat { entry["show_output"] = false }
            items.append(entry)
            hooks[event] = items
        }
        settings["hooks"] = hooks
        return settings
    }

    static func uninstallFlat(from settings: [String: Any], events: [String]) -> [String: Any] {
        var settings = settings
        guard var hooks = settings["hooks"] as? [String: Any] else { return settings }
        for event in events {
            guard let items = hooks[event] as? [[String: Any]] else { continue }
            let kept = items.filter { !flatItemIsOurs($0) }
            if kept.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = kept }
        }
        if hooks.isEmpty { settings.removeValue(forKey: "hooks") } else { settings["hooks"] = hooks }
        return settings
    }

    static func isInstalledFlat(in settings: [String: Any], events: [String]) -> Bool {
        guard let hooks = settings["hooks"] as? [String: Any] else { return false }
        for event in events {
            guard let items = hooks[event] as? [[String: Any]] else { continue }
            if items.contains(where: flatItemIsOurs) { return true }
        }
        return false
    }

    // MARK: - opencode JS plugin

    /// Extracts the agentbuddy binary path from a hook command like
    /// `"/path/to/agentbuddy" hook --agent opencode` (the first quoted token).
    static func binaryPath(fromCommand command: String) -> String {
        if let first = command.firstIndex(of: "\"") {
            let rest = command[command.index(after: first)...]
            if let second = rest.firstIndex(of: "\"") {
                return String(rest[..<second])
            }
        }
        return command.components(separatedBy: " ").first ?? command
    }

    static func opencodePlugin(binary: String) -> String {
        """
        // AgentBuddy integration (auto-generated, safe to delete to uninstall).
        // Reports opencode session lifecycle to AgentBuddy's menu bar app.
        const AGENTBUDDY_BIN = \(jsString(binary))
        export const AgentBuddy = async ({ directory }) => {
          const sid = "opencode:" + (directory || "default")
          const send = (state) => {
            try {
              Bun.spawn([AGENTBUDDY_BIN, "hook", "--agent", "opencode",
                         "--event", state, "--session", sid, "--project", directory || ""])
            } catch (e) {}
          }
          return {
            "session.created": async () => { send("working") },
            "session.idle": async () => { send("done") },
          }
        }
        """
    }

    /// JSON-encodes a string for safe embedding in JS source.
    private static func jsString(_ s: String) -> String {
        if let data = try? JSONEncoder().encode(s), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "\"\(s)\""
    }

    // MARK: - Codex inline TOML

    private static let codexStartMarker = "# AgentBuddy Codex hooks (auto-generated; safe to delete)"
    private static let codexEndMarker = "# End AgentBuddy Codex hooks"

    static func installCodexToml(into content: String, command: String, events: [String]) -> String {
        var updated = enableCodexHooksFeature(in: uninstallCodexToml(from: content))
        if !updated.isEmpty && !updated.hasSuffix("\n") { updated += "\n" }
        if !updated.isEmpty { updated += "\n" }
        updated += codexTomlBlock(command: command, events: events)
        return updated
    }

    static func uninstallCodexToml(from content: String) -> String {
        var remaining = content
        while let start = remaining.range(of: codexStartMarker) {
            guard let end = remaining.range(of: codexEndMarker, range: start.upperBound..<remaining.endIndex) else {
                break
            }
            var removal = start.lowerBound..<end.upperBound
            if removal.upperBound < remaining.endIndex,
               remaining[removal.upperBound] == "\n" {
                removal = removal.lowerBound..<remaining.index(after: removal.upperBound)
            }
            if removal.lowerBound > remaining.startIndex,
               remaining[remaining.index(before: removal.lowerBound)] == "\n" {
                removal = remaining.index(before: removal.lowerBound)..<removal.upperBound
            }
            remaining.removeSubrange(removal)
        }
        return remaining
    }

    static func isInstalledCodexToml(_ content: String) -> Bool {
        content.contains(codexStartMarker) && content.contains(codexEndMarker)
    }

    private static func codexTomlBlock(command: String, events: [String]) -> String {
        var lines = [codexStartMarker]
        let escaped = tomlString(command)
        for event in events {
            lines.append("")
            lines.append("[[hooks.\(event)]]")
            lines.append("")
            lines.append("[[hooks.\(event).hooks]]")
            lines.append("type = \"command\"")
            lines.append("command = \"\(escaped)\"")
            lines.append("timeout = \(timeout(for: event))")
        }
        lines.append(codexEndMarker)
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func timeout(for event: String) -> Int {
        responseWaitingEvents.contains(event) ? responseHookTimeout : defaultHookTimeout
    }

    private static func enableCodexHooksFeature(in content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        guard let sectionIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "[features]" }) else {
            let prefix = content.isEmpty ? "" : content + (content.hasSuffix("\n") ? "\n" : "\n\n")
            return prefix + "[features]\nhooks = true\n"
        }

        var updated = lines
        let sectionEnd = updated[(sectionIndex + 1)...].firstIndex { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("[") && trimmed.hasSuffix("]")
        } ?? updated.endIndex

        if let hookIndex = updated[(sectionIndex + 1)..<sectionEnd].firstIndex(where: { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("hooks ")
                || line.trimmingCharacters(in: .whitespaces).hasPrefix("hooks=")
        }) {
            updated[hookIndex] = "hooks = true"
        } else {
            updated.insert("hooks = true", at: sectionIndex + 1)
        }
        return updated.joined(separator: "\n")
    }

    private static func tomlString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - Disk IO

    public static func readSettings(path: String) -> [String: Any] {
        guard let data = FileManager.default.contents(atPath: path),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return obj
    }

    public static func writeSettings(_ settings: [String: Any], path: String) throws {
        let dir = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: path))
    }

    public static func installToDisk(command: String, path: String = defaultSettingsPath(),
                                     events: [String] = events, style: HookStyle = .claudeNested) throws {
        switch style {
        case .claudeNested:
            try writeSettings(install(into: readSettings(path: path), command: command, events: events), path: path)
        case .cursorFlat, .windsurfFlat:
            try writeSettings(installFlat(into: readSettings(path: path), command: command, events: events, style: style), path: path)
        case .codexToml:
            let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            let updated = installCodexToml(into: existing, command: command, events: events)
            let dir = (path as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try Data(updated.utf8).write(to: URL(fileURLWithPath: path))
        case .opencodePlugin:
            let dir = (path as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let js = opencodePlugin(binary: binaryPath(fromCommand: command))
            try Data(js.utf8).write(to: URL(fileURLWithPath: path))
        }
    }

    public static func uninstallFromDisk(path: String = defaultSettingsPath(),
                                         events: [String] = events, style: HookStyle = .claudeNested) throws {
        switch style {
        case .claudeNested:
            try writeSettings(uninstall(from: readSettings(path: path), events: events), path: path)
        case .cursorFlat, .windsurfFlat:
            try writeSettings(uninstallFlat(from: readSettings(path: path), events: events), path: path)
        case .codexToml:
            let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            let updated = uninstallCodexToml(from: existing)
            let dir = (path as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try Data(updated.utf8).write(to: URL(fileURLWithPath: path))
        case .opencodePlugin:
            if isInstalledOnDisk(path: path, events: events, style: style) {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }

    public static func isInstalledOnDisk(path: String = defaultSettingsPath(),
                                         events: [String] = events, style: HookStyle = .claudeNested) -> Bool {
        switch style {
        case .claudeNested:
            return isInstalled(in: readSettings(path: path), events: events)
        case .cursorFlat, .windsurfFlat:
            return isInstalledFlat(in: readSettings(path: path), events: events)
        case .codexToml:
            guard let s = try? String(contentsOfFile: path, encoding: .utf8) else { return false }
            return isInstalledCodexToml(s)
        case .opencodePlugin:
            guard let s = try? String(contentsOfFile: path, encoding: .utf8) else { return false }
            return isOurs(s)
        }
    }
}
