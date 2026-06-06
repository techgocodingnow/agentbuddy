import SwiftUI
import AppKit

struct AgentBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The UI lives in a status-item popover and floating windows managed by
        // AppDelegate; this empty scene just satisfies the App protocol.
        Settings { EmptyView() }
    }
}

/// Runs the app as a menu bar accessory (no Dock icon) and boots the daemon.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        DefaultPetBootstrap.installIfNeeded()
        ImagePetStore.shared.reload()
        if let selectedPetID = PetController.shared.selectedPetID,
           ImagePetStore.shared.pack(id: selectedPetID) != nil {
            // Keep the user's existing choice.
        } else {
            PetController.shared.selectedPetID =
                ImagePetStore.shared.pack(id: DefaultPetBootstrap.defaultPetID)?.id
                ?? ImagePetStore.shared.packs.first?.id
        }
        PetController.shared.start()
        PetWindowController.shared.start()
        PetHotKeyController.shared.start()
        AppDaemon.shared.start()
        SettingsModel.shared.migrateInstalledHooksIfNeeded()
        _ = UpdaterController.shared
        StatusBarController.shared.start()
        SettingsWindowController.shared.showOnFirstLaunch()
    }
}
