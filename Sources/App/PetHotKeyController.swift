import AppKit
import Carbon.HIToolbox
import AgentBuddyCore

/// Registers a single system-wide hotkey (default ⌃⌥⌘P) that toggles the pet
/// window's visibility. Uses Carbon's `RegisterEventHotKey`, which works for a
/// menu-bar (accessory) app without the Accessibility permission a global
/// `NSEvent` monitor would require. The combo is user-configurable and persisted.
@MainActor
final class PetHotKeyController: ObservableObject {
    static let shared = PetHotKeyController()

    private static let defaultsKey = "agentbuddy.petToggleHotKey"
    /// FourCharCode signature ("ABpt") identifying our hotkey in the event stream.
    private static let signature: OSType = 0x4142_7074

    @Published var combo: HotKeyCombo {
        didSet {
            guard combo != oldValue else { return }
            persist()
            register()
        }
    }

    private var hotKeyRef: EventHotKeyRef?
    private var handlerInstalled = false

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(HotKeyCombo.self, from: data) {
            combo = saved
        } else {
            combo = .defaultPetToggle
        }
    }

    /// Installs the event handler and registers the current combo. Call once at
    /// launch.
    func start() {
        installHandler()
        register()
    }

    /// Resets to the shipped default (⌃⌥⌘P).
    func resetToDefault() {
        combo = .defaultPetToggle
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(combo) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        // The callback is a bare C function pointer (captures nothing); there is
        // only one hotkey, so it routes to the shared controller after checking
        // the signature.
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &id
            )
            guard status == noErr, id.signature == PetHotKeyController.signature else {
                return OSStatus(eventNotHandledErr)
            }
            Task { @MainActor in PetWindowController.shared.isVisible.toggle() }
            return noErr
        }, 1, &spec, nil, nil)
    }

    private func register() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        guard combo.hasModifiers else { return } // never grab a bare key globally
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        RegisterEventHotKey(combo.keyCode, combo.carbonModifiers, id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
