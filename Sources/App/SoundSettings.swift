import AppKit
import AgentBuddyCore

/// Plays a sound when an agent finishes or needs input. Each event has its own
/// on/off and sound choice (a built-in macOS system sound, or a custom file the
/// user uploads). Custom files are copied into `~/.agentbuddy/sounds/`.
@MainActor
final class SoundSettings: ObservableObject {
    static let shared = SoundSettings()

    enum Event: String { case waiting, done, hatch }

    @Published var waitingEnabled: Bool { didSet { save() } }
    @Published var doneEnabled: Bool { didSet { save() } }
    @Published var hatchEnabled: Bool { didSet { save() } }
    @Published var hatchHapticsEnabled: Bool { didSet { save() } }
    /// "" means use the built-in default; otherwise a custom file path.
    @Published var waitingCustomPath: String { didSet { save() } }
    @Published var doneCustomPath: String { didSet { save() } }
    @Published var hatchCustomPath: String { didSet { save() } }

    /// Built-in macOS system sounds used as defaults.
    static let defaultWaiting = "Submarine"
    static let defaultDone = "Glass"

    private var soundsDir: URL {
        URL(fileURLWithPath: AgentBuddyPaths.baseDir).appendingPathComponent("sounds")
    }

    init() {
        let d = UserDefaults.standard
        waitingEnabled = (d.object(forKey: "agentbuddy.sound.waiting.on") as? Bool) ?? true
        doneEnabled = (d.object(forKey: "agentbuddy.sound.done.on") as? Bool) ?? true
        hatchEnabled = (d.object(forKey: "agentbuddy.sound.hatch.on") as? Bool) ?? true
        hatchHapticsEnabled = (d.object(forKey: "agentbuddy.haptics.hatch.on") as? Bool) ?? true
        waitingCustomPath = d.string(forKey: "agentbuddy.sound.waiting.path") ?? ""
        doneCustomPath = d.string(forKey: "agentbuddy.sound.done.path") ?? ""
        hatchCustomPath = d.string(forKey: "agentbuddy.sound.hatch.path") ?? ""
    }

    func isEnabled(_ event: Event) -> Bool {
        switch event {
        case .waiting: return waitingEnabled
        case .done: return doneEnabled
        case .hatch: return hatchEnabled
        }
    }

    func customPath(_ event: Event) -> String {
        switch event {
        case .waiting: return waitingCustomPath
        case .done: return doneCustomPath
        case .hatch: return hatchCustomPath
        }
    }

    /// Plays the configured sound for an event, if enabled.
    func play(_ event: Event) {
        guard isEnabled(event) else { return }
        let sound: NSSound?
        let path = customPath(event)
        if !path.isEmpty, FileManager.default.fileExists(atPath: path) {
            sound = NSSound(contentsOfFile: path, byReference: true)
        } else if event == .hatch,
                  let url = Bundle.module.url(forResource: "hatch-chime", withExtension: "wav") {
            sound = NSSound(contentsOf: url, byReference: true)
        } else {
            sound = NSSound(named: event == .waiting ? Self.defaultWaiting : Self.defaultDone)
        }
        sound?.stop()
        sound?.play()
    }

    func playHatchFeedback() {
        play(.hatch)
        guard hatchHapticsEnabled else { return }
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.generic, performanceTime: .now)
        Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { _ in
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        Timer.scheduledTimer(withTimeInterval: 1.05, repeats: false) { _ in
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }

    /// Prompts for an audio file and sets it as the custom sound for an event.
    func upload(for event: Event) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose a sound file"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let fm = FileManager.default
        try? fm.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        let dest = soundsDir.appendingPathComponent("\(event.rawValue).\(url.pathExtension)")
        try? fm.removeItem(at: dest)
        do {
            try fm.copyItem(at: url, to: dest)
        } catch {
            return
        }
        setCustomPath(dest.path, for: event)
        play(event)   // preview
    }

    func resetToDefault(_ event: Event) {
        setCustomPath("", for: event)
    }

    private func setCustomPath(_ path: String, for event: Event) {
        switch event {
        case .waiting: waitingCustomPath = path
        case .done: doneCustomPath = path
        case .hatch: hatchCustomPath = path
        }
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(waitingEnabled, forKey: "agentbuddy.sound.waiting.on")
        d.set(doneEnabled, forKey: "agentbuddy.sound.done.on")
        d.set(hatchEnabled, forKey: "agentbuddy.sound.hatch.on")
        d.set(hatchHapticsEnabled, forKey: "agentbuddy.haptics.hatch.on")
        d.set(waitingCustomPath, forKey: "agentbuddy.sound.waiting.path")
        d.set(doneCustomPath, forKey: "agentbuddy.sound.done.path")
        d.set(hatchCustomPath, forKey: "agentbuddy.sound.hatch.path")
    }
}
