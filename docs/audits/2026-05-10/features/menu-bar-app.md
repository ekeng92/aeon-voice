# Feature: Menu Bar App Shell

> `Sources/AEONVoice/AEONVoiceApp.swift` (123 lines)

## Purpose

Entry point for the macOS menu bar application. Creates an NSStatusItem with a tinted SF Symbol icon in the menu bar, and manages a floating NSPanel popover that hosts the SwiftUI ContentView.

## How It Works

1. `@main` struct `AEONVoiceApp` uses `@NSApplicationDelegateAdaptor` to delegate all UI management to `AppDelegate`
2. The `App` body contains only a `Settings { EmptyView() }` scene, since menu bar apps need no visible window
3. `AppDelegate.applicationDidFinishLaunching` creates:
   - An `NSStatusItem` with variable length in the system menu bar
   - A floating `NSPanel` (360x680) with transparent titlebar, utility animation, and hide-on-deactivate
   - An `NSHostingView` wrapping the SwiftUI `ContentView`
4. Icon rendering uses manual Core Graphics compositing to tint SF Symbols (teal when enabled, gray when muted)
5. Badge dot (orange, 6px) is drawn via NSBezierPath when `unreadCount > 0`
6. `togglePanel()` positions the panel below the status item button and activates the app

## Dependencies

- `VoiceManager` (shared instance, passed to ContentView)
- `ContentView` (SwiftUI view hierarchy)
- Combine (`AnyCancellable` for observing VoiceManager changes to update icon)

## Configuration

None directly. Icon state is driven by `VoiceManager.isEnabled` and `VoiceManager.unreadCount`.

## Known Limitations

- Panel height is fixed at 680px; may clip on very small displays
- No dark/light mode icon variant; uses manual tinting which may look off in some menu bar themes
- `NSApp.activate(ignoringOtherApps: true)` is deprecated in macOS 14+
