import AppKit
import SwiftUI
import Combine

/// A borderless, always-on-top, draggable floating window that hosts the pet.
/// Visibility is user-toggleable; size follows the pet-size setting.
@MainActor
final class PetWindowController: ObservableObject {
    static let shared = PetWindowController()

    private static let visibleKey = "agentbuddy.petVisible"

    @Published var isVisible: Bool = (UserDefaults.standard.object(forKey: PetWindowController.visibleKey) as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(isVisible, forKey: Self.visibleKey)
            applyVisibility(isVisible)
        }
    }

    private var panel: NSPanel?
    private var sizeCancellable: AnyCancellable?
    private var sessionsCancellable: AnyCancellable?
    private var rightClickMonitor: Any?
    private var screenObserver: Any?
    private var moveObserver: Any?
    private var isClampingFrame = false

    func start() {
        let size = PetController.shared.windowSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = ClickThroughHostingView(rootView: FloatingPetView())
        self.panel = panel

        placeInitially(size: size)
        applyVisibility(isVisible)

        // The panel is draggable by its transparent background. Keep it fully
        // visible after user moves too, not only after size/display changes.
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.ensureFullyOnScreen() }
        }

        // On size change, resize in place (keep the pet where the user put it).
        sizeCancellable = PetController.shared.$petPoint.sink { [weak self] point in
            let activeCount = PetController.shared.activeSessions.count
            self?.resizeInPlace(to: PetController.windowSize(forPoint: point, activeCount: activeCount))
        }

        // Active session cards also affect the floating panel size.
        sessionsCancellable = PetController.shared.$activeSessions.sink { [weak self] sessions in
            self?.resizeInPlace(to: PetController.windowSize(forPoint: PetController.shared.petPoint, activeCount: sessions.count))
        }

        // If displays change (e.g. a monitor is unplugged), keep the pet on screen.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.ensureOnScreen() }
        }

        // Right-click the pet to open the popover anchored at the pet.
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let self, let panel = self.panel, event.window === panel,
                      let content = panel.contentView else { return false }
                let petPoint = PetController.shared.petPoint
                let rect = NSRect(x: (content.bounds.width - petPoint) / 2, y: 0,
                                  width: petPoint, height: petPoint)
                StatusBarController.shared.showPopover(relativeTo: rect, of: content, edge: .maxY)
                return true
            }
            return handled ? nil : event
        }
    }

    /// First-time placement: bottom-right of the main screen.
    private func placeInitially(size: CGSize) {
        guard let panel, let visible = NSScreen.main?.visibleFrame else { return }
        let origin = NSPoint(x: visible.maxX - size.width - 16, y: visible.minY + 24)
        panel.setFrame(clampedFrame(NSRect(origin: origin, size: size), visible: visible), display: true, animate: false)
    }

    /// Resizes around the pet's bottom-center so it stays where the user
    /// dragged it, clamped to whichever screen it currently sits on.
    private func resizeInPlace(to size: CGSize) {
        guard let panel else { return }
        let old = panel.frame
        var origin = NSPoint(x: old.midX - size.width / 2, y: old.minY)
        if let visible = screen(for: old)?.visibleFrame ?? NSScreen.main?.visibleFrame {
            let frame = clampedFrame(NSRect(origin: origin, size: size), visible: visible)
            origin = frame.origin
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
    }

    private func ensureFullyOnScreen() {
        guard let panel, !isClampingFrame else { return }
        let frame = panel.frame
        let visible = screen(for: frame)?.visibleFrame ?? NSScreen.main?.visibleFrame
        guard let visible else { return }
        let clamped = clampedFrame(frame, visible: visible)
        guard clamped.origin != frame.origin else { return }
        isClampingFrame = true
        defer { isClampingFrame = false }
        panel.setFrame(clamped, display: true, animate: false)
    }

    /// Keeps the pet visible after a display configuration change: if its
    /// screen vanished (unplugged), move it onto the main screen.
    private func ensureOnScreen() {
        guard let panel else { return }
        let frame = panel.frame
        if currentScreen(for: frame) != nil {
            ensureFullyOnScreen()
            return
        }
        guard let visible = NSScreen.main?.visibleFrame else { return }
        let origin = NSPoint(x: visible.maxX - frame.width - 16, y: visible.minY + 24)
        panel.setFrame(clampedFrame(NSRect(origin: origin, size: frame.size), visible: visible), display: true, animate: false)
    }

    private func clampedFrame(_ frame: NSRect, visible: NSRect) -> NSRect {
        var origin = frame.origin
        if frame.width <= visible.width {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - frame.width)
        } else {
            origin.x = visible.minX
        }
        if frame.height <= visible.height {
            origin.y = min(max(origin.y, visible.minY), visible.maxY - frame.height)
        } else {
            origin.y = visible.minY
        }
        return NSRect(origin: origin, size: frame.size)
    }

    /// The screen whose frame contains the window's center, if any.
    private func currentScreen(for frame: NSRect) -> NSScreen? {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { NSPointInRect(center, $0.frame) }
    }

    private func screen(for frame: NSRect) -> NSScreen? {
        currentScreen(for: frame) ?? NSScreen.screens.first { $0.visibleFrame.intersects(frame) }
    }

    private func applyVisibility(_ visible: Bool) {
        if visible {
            panel?.orderFrontRegardless()
        } else {
            panel?.orderOut(nil)
        }
    }
}
