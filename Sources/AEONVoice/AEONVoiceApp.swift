import SwiftUI
import UserNotifications

@main
struct AEONVoiceApp: App {
    @StateObject private var manager = VoiceManager()

    init() {
        // Request notification permission on first launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(manager: manager)
        } label: {
            Image(systemName: manager.isEnabled ? "waveform" : "speaker.slash")
        }
        .menuBarExtraStyle(.window)
    }
}
