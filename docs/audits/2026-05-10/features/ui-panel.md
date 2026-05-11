# Feature: UI Panel (ContentView)

> `Sources/AEONVoice/ContentView.swift` (619 lines)

## Purpose

The full SwiftUI popover UI displayed when the user clicks the menu bar icon. Contains all visual sections: status card, toggles, settings, voice test, quick actions, update checker, activity log, and notifications.

## Sections

1. **Status Card** — colored indicator (green/red/orange), voice name, dependency health (python3, edge-tts), active audio and temp file counts, Teams call indicator, Keep Awake indicator
2. **Main Toggles** — Voice On/Off button (green/gray), Keep Awake button (brown/gray)
3. **Settings** — Default Voice picker (9 voices), Max Characters picker (200/300/500/1000/unlimited), Mute during Teams calls toggle
4. **Voice Test** — text field + voice picker + Play button + "Test All" button for sequential voice preview
5. **Quick Actions** — Stop Audio, Clean Temp, Initialize, Refresh
6. **Update Section** — Check for Updates (GitHub API), show available version, Install Update button
7. **Activity Log** — last 6 log entries with timestamps
8. **Notifications (Collapsible)** — DisclosureGroup with toggles for voice notifications and update notifications, recent entries list, clear button, Notification Settings link

## Data Flow

- All state comes from `@ObservedObject var manager: VoiceManager`
- Settings changes mutate `manager.config` directly and call `manager.saveConfig()`
- Voice test uses `manager.testVoiceById()` or `manager.testAllVoices()`
- Actions delegate to `manager.stopAudio()`, `manager.cleanTemp()`, `manager.initialize()`, `manager.refresh()`

## Known Limitations

- Fixed frame size (360x680) — not responsive to content height
- `testVoiceId` state is initialized from config `onAppear` but doesn't update if config changes externally
- No scroll-to-top when new notification arrives
- Notification section only visible when parent DisclosureGroup is expanded AND notifications toggle is on
