import SwiftUI
import AppKit
import CoreGraphics
import Combine

@main
struct AEONVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No visible scenes. The menu bar icon and popover are managed
        // entirely by AppDelegate via NSStatusItem (same pattern as
        // AEON Dispatch) to support colored SF Symbol icons.
        Settings { EmptyView() }
    }
}

/// NSPanel with `.nonactivatingPanel` blocks SwiftUI button events.
/// This subclass restores key-window capability.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let manager = VoiceManager()
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance guard: quit if another copy is already running
        let dominated = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        if dominated.count > 1 {
            NSApp.terminate(nil)
            return
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePanel)
            button.target = self
            updateIcon()
        }

        let panelSize = NSSize(width: 360, height: 680)
        panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow

        let hostingView = NSHostingView(rootView: ContentView(manager: manager))
        panel.contentView = hostingView

        cancellable = manager.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateIcon() }
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let isEnabled = manager.isEnabled
        let name = isEnabled ? "waveform" : "speaker.slash"
        let color: NSColor = isEnabled ? .systemTeal : .systemGray
        let icon = tintedMenuBarIcon(name, color: color)

        if manager.unreadCount > 0 {
            button.image = addBadgeDot(to: icon)
        } else {
            button.image = icon
        }
    }

    private func addBadgeDot(to image: NSImage) -> NSImage {
        let size = image.size
        let result = NSImage(size: size)
        result.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        let dotSize: CGFloat = 6
        let dotRect = NSRect(x: size.width - dotSize - 1, y: size.height - dotSize - 1,
                             width: dotSize, height: dotSize)
        NSColor.systemOrange.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        result.unlockFocus()
        result.isTemplate = false
        return result
    }

    private func tintedMenuBarIcon(_ name: String, color: NSColor) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return NSImage() }
        let size = symbol.size
        let result = NSImage(size: size)
        result.lockFocus()
        symbol.draw(in: NSRect(origin: .zero, size: size),
                    from: .zero, operation: .sourceOver, fraction: 1.0)
        color.set()
        NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
        result.unlockFocus()
        result.isTemplate = false
        return result
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
            return
        }

        manager.markAsRead()

        guard let button = statusItem.button else { return }
        let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
        let panelSize = panel.frame.size

        let x = buttonFrame.midX - panelSize.width / 2
        let y = buttonFrame.minY - panelSize.height - 4

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
