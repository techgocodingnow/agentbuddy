import XCTest
@testable import AgentBuddyCore

final class HotKeyComboTests: XCTestCase {
    func testDefaultIsControlOptionCommandP() {
        let combo = HotKeyCombo.defaultPetToggle
        XCTAssertEqual(combo.keyCode, 35)
        XCTAssertEqual(combo.modifiers, [.control, .option, .command])
        XCTAssertEqual(combo.displayString, "⌃⌥⌘P")
        XCTAssertTrue(combo.hasModifiers)
    }

    func testCarbonModifierMask() {
        // cmdKey 0x100 | optionKey 0x800 | controlKey 0x1000 = 0x1900
        XCTAssertEqual(HotKeyCombo.defaultPetToggle.carbonModifiers, 0x1900)
        XCTAssertEqual(HotKeyCombo(keyCode: 0, modifiers: .command).carbonModifiers, 0x0100)
        XCTAssertEqual(HotKeyCombo(keyCode: 0, modifiers: .shift).carbonModifiers, 0x0200)
        XCTAssertEqual(HotKeyCombo(keyCode: 0, modifiers: [.shift, .command]).carbonModifiers, 0x0300)
    }

    func testDisplayGlyphOrderIsControlOptionShiftCommand() {
        let combo = HotKeyCombo(keyCode: 1 /* S */, modifiers: [.command, .shift, .option, .control])
        XCTAssertEqual(combo.displayString, "⌃⌥⇧⌘S")
    }

    func testKeyNameFallbackForUnknownCode() {
        XCTAssertEqual(HotKeyCombo.keyName(999), "#999")
    }

    func testHasModifiersFalseWhenEmpty() {
        XCTAssertFalse(HotKeyCombo(keyCode: 35, modifiers: []).hasModifiers)
    }

    func testCodableRoundTrip() throws {
        let original = HotKeyCombo(keyCode: 11, modifiers: [.control, .option, .command])
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(HotKeyCombo.self, from: data)
        XCTAssertEqual(original, restored)
    }
}
