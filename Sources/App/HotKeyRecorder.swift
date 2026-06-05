import AppKit
import SwiftUI
import AgentBuddyCore

/// A click-to-record shortcut field. Click it, press a modified key combo, and
/// the new `HotKeyCombo` is written back through the binding. Escape cancels;
/// a combo with no modifiers is rejected (it would hijack a bare key globally).
struct HotKeyRecorder: NSViewRepresentable {
    @Binding var combo: HotKeyCombo

    func makeNSView(context: Context) -> RecorderControl {
        let view = RecorderControl()
        view.onChange = { combo = $0 }
        view.combo = combo
        return view
    }

    func updateNSView(_ nsView: RecorderControl, context: Context) {
        nsView.combo = combo
    }
}

final class RecorderControl: NSView {
    var combo: HotKeyCombo = .defaultPetToggle { didSet { needsDisplay = true } }
    var onChange: ((HotKeyCombo) -> Void)?

    private var isRecording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 130, height: 24) }

    override func mouseDown(with event: NSEvent) {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        window?.makeFirstResponder(self)
    }

    private func stopRecording() {
        isRecording = false
        if window?.firstResponder === self { window?.makeFirstResponder(nil) }
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }

    // Command-bearing combos arrive via performKeyEquivalent rather than keyDown.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        return handle(event)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording, handle(event) else { super.keyDown(with: event); return }
    }

    private func handle(_ event: NSEvent) -> Bool {
        // Escape (no modifiers) cancels recording.
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 53, flags.isEmpty {
            stopRecording()
            return true
        }
        let mods = Self.modifiers(from: flags)
        guard !mods.isEmpty else {
            NSSound.beep() // require at least one modifier
            return true
        }
        let recorded = HotKeyCombo(keyCode: UInt32(event.keyCode), modifiers: mods)
        combo = recorded
        onChange?(recorded)
        stopRecording()
        return true
    }

    static func modifiers(from flags: NSEvent.ModifierFlags) -> HotKeyModifiers {
        var m: HotKeyModifiers = []
        if flags.contains(.command) { m.insert(.command) }
        if flags.contains(.option) { m.insert(.option) }
        if flags.contains(.control) { m.insert(.control) }
        if flags.contains(.shift) { m.insert(.shift) }
        return m
    }

    override func draw(_ dirtyRect: NSRect) {
        let frame = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: frame, xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.25)
                     : NSColor.white.withAlphaComponent(0.08)).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(isRecording ? 0.4 : 0.15).setStroke()
        path.stroke()

        let text = isRecording ? "Press shortcut…" : combo.displayString
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(isRecording ? 0.6 : 0.9),
            .paragraphStyle: style,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let rect = NSRect(x: 0, y: (bounds.height - size.height) / 2,
                          width: bounds.width, height: size.height)
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }
}
