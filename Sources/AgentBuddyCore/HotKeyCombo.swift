import Foundation

/// Modifier keys for a global shortcut, independent of AppKit so this stays
/// unit-testable in the Core target. The App layer converts to/from
/// `NSEvent.ModifierFlags` at the edges.
public struct HotKeyModifiers: OptionSet, Codable, Sendable, Hashable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    public static let command = HotKeyModifiers(rawValue: 1 << 0)
    public static let option  = HotKeyModifiers(rawValue: 1 << 1)
    public static let control = HotKeyModifiers(rawValue: 1 << 2)
    public static let shift   = HotKeyModifiers(rawValue: 1 << 3)
}

/// A keyboard shortcut: a virtual key code plus modifiers. A pure value type so
/// its Carbon mapping, display formatting, and persistence are all testable
/// without a running app. The App's `PetHotKeyController` feeds `keyCode` and
/// `carbonModifiers` straight into Carbon's `RegisterEventHotKey`.
public struct HotKeyCombo: Equatable, Codable, Sendable, Hashable {
    public var keyCode: UInt32
    public var modifiers: HotKeyModifiers

    public init(keyCode: UInt32, modifiers: HotKeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// ⌃⌥⌘P — the shipped default for toggling the pet (P = ANSI key code 35).
    public static let defaultPetToggle = HotKeyCombo(
        keyCode: 35, modifiers: [.control, .option, .command]
    )

    /// True when at least one modifier is held. A global hotkey with no
    /// modifiers would swallow a bare keypress system-wide, so recorders reject
    /// these.
    public var hasModifiers: Bool { !modifiers.isEmpty }

    /// Carbon modifier mask for `RegisterEventHotKey` (cmdKey/optionKey/etc.).
    public var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if modifiers.contains(.command) { mask |= 0x0100 } // cmdKey
        if modifiers.contains(.shift)   { mask |= 0x0200 } // shiftKey
        if modifiers.contains(.option)  { mask |= 0x0800 } // optionKey
        if modifiers.contains(.control) { mask |= 0x1000 } // controlKey
        return mask
    }

    /// Human-readable like "⌃⌥⌘P", using the standard macOS glyph order
    /// (Control, Option, Shift, Command) followed by the key name.
    public var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + HotKeyCombo.keyName(keyCode)
    }

    /// Maps an ANSI virtual key code to a display label. Covers letters, digits,
    /// and common named keys; unknown codes fall back to "#<code>".
    public static func keyName(_ keyCode: UInt32) -> String {
        if let name = ansiNames[keyCode] { return name }
        return "#\(keyCode)"
    }

    private static let ansiNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C",
        9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
        43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 50: "`",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
}
