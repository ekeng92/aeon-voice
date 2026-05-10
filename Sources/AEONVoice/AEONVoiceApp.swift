import SwiftUI

@main
struct AEONVoiceApp: App {
    @StateObject private var manager = VoiceManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView(manager: manager)
        } label: {
            Image(systemName: manager.isEnabled ? "waveform" : "speaker.slash")
        }
        .menuBarExtraStyle(.window)
    }
}
