import SwiftUI

struct ContentView: View {
    @ObservedObject var manager: VoiceManager
    @State private var testMessage = "Hello, this is AEON voice."
    @State private var testVoiceId = "en-US-AndrewNeural"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                statusCard
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Main toggles
                HStack(spacing: 8) {
                    voiceToggle
                    keepAwakeToggle
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                Divider().padding(.horizontal, 16)

                settingsSection
                    .padding(16)

                Divider().padding(.horizontal, 16)

                voiceTest
                    .padding(16)

                Divider().padding(.horizontal, 16)

                quickActions
                    .padding(16)

                Divider().padding(.horizontal, 16)

                updateSection
                    .padding(16)

                Divider().padding(.horizontal, 16)

                activitySection
                    .padding(16)

                if manager.config.showNotifications {
                    Divider().padding(.horizontal, 16)

                    notificationsSection
                        .padding(16)
                }

                Divider()

                Button(action: { NSApp.terminate(nil) }) {
                    Text("Quit AEON Voice")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 10)
            }
        }
        // MenuBarExtra popovers size themselves from intrinsic content. A ScrollView
        // has a weak vertical intrinsic size, so using only maxHeight can collapse
        // into a tiny squished window on fresh installs. Pin the popover to the
        // intended panel size and let the ScrollView handle overflow.
        .frame(width: 360, height: 680)
        .onAppear { testVoiceId = manager.config.defaultVoice }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(statusTitle)
                            .font(.system(size: 16, weight: .semibold))
                        if manager.keepAwake {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.brown)
                        }
                        if manager.teamsCallActive && manager.config.muteOnTeams {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                        }
                    }
                    Text("Voice: \(manager.currentVoice?.name ?? "Unknown")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(statusSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 16) {
                depIndicator("python3", ok: manager.pythonAvailable)
                depIndicator("edge-tts", ok: manager.edgeTTSAvailable)
            }
            .font(.caption2)

            Text(countsText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Voice Toggle

    private var voiceToggle: some View {
        Button(action: { manager.toggle() }) {
            VStack(spacing: 2) {
                Image(systemName: manager.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16))
                Text(manager.isEnabled ? "Voice On" : "Voice Off")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(manager.isEnabled ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(manager.isEnabled ? .green : Color(.systemGray))
        .controlSize(.large)
        .accessibilityLabel(manager.isEnabled ? "Voice enabled, tap to mute" : "Voice muted, tap to enable")
    }

    // MARK: - Keep Awake Toggle

    private var keepAwakeToggle: some View {
        Button(action: { manager.toggleKeepAwake() }) {
            VStack(spacing: 2) {
                Image(systemName: manager.keepAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: 16))
                Text("Keep Awake")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(manager.keepAwake ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(manager.keepAwake ? .brown : Color(.systemGray))
        .controlSize(.large)
        .help("Prevents system sleep — keeps background processes running even with the lid closed. Uses macOS caffeinate (no sudo required).")
        .accessibilityLabel(manager.keepAwake ? "Keep awake active, system will not sleep. Tap to disable" : "Keep awake inactive. Tap to prevent system sleep")
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SETTINGS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                Text("Default Voice")
                    .font(.caption)
                Spacer()
                Picker("", selection: Binding(
                    get: { manager.config.defaultVoice },
                    set: { manager.setDefaultVoice($0) }
                )) {
                    ForEach(VoiceManager.availableVoices) { voice in
                        Text(voice.name)
                            .tag(voice.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 150)
            }

            HStack {
                Text("Max Characters")
                    .font(.caption)
                Spacer()
                Picker("", selection: Binding(
                    get: { manager.config.maxCharacters },
                    set: { newValue in
                        manager.config.maxCharacters = newValue
                        manager.saveConfig()
                    }
                )) {
                    Text("200").tag(200)
                    Text("300").tag(300)
                    Text("500").tag(500)
                    Text("1000").tag(1000)
                    Text("No limit").tag(0)
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 150)
            }
            .help("Maximum characters an agent can voice in a single message. Longer messages are truncated before TTS generation.")

            HStack {
                Toggle(isOn: Binding(
                    get: { manager.config.muteOnTeams },
                    set: { newValue in
                        manager.config.muteOnTeams = newValue
                        manager.saveConfig()
                    }
                )) {
                    HStack(spacing: 4) {
                        Text("Mute during Teams calls")
                            .font(.caption)
                        if manager.teamsCallActive {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .toggleStyle(.checkbox)
            }
            .help("Automatically suppresses voice output when a Microsoft Teams call is detected via macOS power assertions.")

            HStack {
                Toggle(isOn: Binding(
                    get: { manager.config.showNotifications },
                    set: { newValue in
                        manager.config.showNotifications = newValue
                        manager.saveConfig()
                    }
                )) {
                    Text("Notify on voice output")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)
            }
            .help("Shows a macOS notification whenever voice output fires — useful when you step away and might miss a spoken completion or follow-up message.")

            HStack {
                Toggle(isOn: Binding(
                    get: { manager.config.showUpdateNotifications },
                    set: { newValue in
                        manager.config.showUpdateNotifications = newValue
                        manager.saveConfig()
                    }
                )) {
                    Text("Notify on updates available")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)
            }
            .help("Shows a one-time macOS notification when a new version of AEON Voice is available on GitHub. Checks automatically every 30 minutes.")
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ACTIONS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                actionButton("Stop Audio", icon: "stop.fill", tint: .red) {
                    manager.stopAudio()
                }
                actionButton("Clean Temp", icon: "trash", tint: Color(.systemGray)) {
                    manager.cleanTemp()
                }
            }

            HStack(spacing: 8) {
                actionButton("Initialize", icon: "wrench.fill", tint: Color(.systemGray)) {
                    manager.initialize()
                }
                actionButton("Refresh", icon: "arrow.clockwise", tint: Color(.systemGray)) {
                    manager.refresh()
                }
            }
        }
    }

    // MARK: - Voice Test

    private var voiceTest: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VOICE TEST")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Test message…", text: $testMessage)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            HStack(spacing: 8) {
                Picker("", selection: $testVoiceId) {
                    ForEach(VoiceManager.availableVoices) { voice in
                        Text("\(voice.name) — \(voice.style)")
                            .tag(voice.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Button(action: {
                    manager.testVoiceById(testVoiceId, message: testMessage)
                }) {
                    Label("Play", systemImage: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .controlSize(.small)

                Button(action: {
                    manager.testAllVoices(message: testMessage)
                }) {
                    Label("All", systemImage: "speaker.wave.3.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Activity Log

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIVITY")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            if manager.activityLog.isEmpty {
                Text("No activity yet")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(manager.activityLog.prefix(6)) { entry in
                        HStack(alignment: .top, spacing: 6) {
                            Text(entry.timeString)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Text(entry.message)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Recent Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RECENT NOTIFICATIONS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !manager.recentNotifications.isEmpty {
                    Button(action: { manager.clearNotifications() }) {
                        Text("Clear")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if manager.recentNotifications.isEmpty {
                Text("No notifications yet")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(manager.recentNotifications.prefix(10)) { entry in
                        HStack(alignment: .top, spacing: 6) {
                            Text(entry.timeString)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(minWidth: 40, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                if let session = entry.session {
                                    Text(session)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.primary.opacity(0.7))
                                }
                                if let prompt = entry.prompt {
                                    Text("Re: \(prompt)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                Text(entry.message)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Update

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("UPDATE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Build: \(manager.buildCommit)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            switch manager.updateState {
            case .idle:
                actionButton("Check for Updates", icon: "arrow.triangle.2.circlepath", tint: .blue) {
                    manager.checkForUpdate()
                }
            case .checking:
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
            case .upToDate:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Up to date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: { manager.checkForUpdate() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            case .updateAvailable(let sha):
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Update available (\(sha))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    actionButton("Install Update", icon: "arrow.down.to.line", tint: .orange) {
                        manager.runUpdate()
                    }
                }
            case .updating:
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Installing update...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
            case .failed(let msg):
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    actionButton("Retry", icon: "arrow.triangle.2.circlepath", tint: .blue) {
                        manager.checkForUpdate()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        if manager.teamsCallActive && manager.config.muteOnTeams && manager.isEnabled {
            return .orange
        }
        switch manager.voiceState {
        case .on:      return .green
        case .off:     return .red
        case .unknown: return .orange
        }
    }

    private var statusTitle: String {
        if manager.teamsCallActive && manager.config.muteOnTeams && manager.isEnabled {
            return "Muted (Teams)"
        }
        switch manager.voiceState {
        case .on:      return "Voice On"
        case .off:     return "Voice Off"
        case .unknown: return "Not Configured"
        }
    }

    private var statusSubtitle: String {
        if manager.teamsCallActive && manager.config.muteOnTeams && manager.isEnabled {
            return "Voice auto-muted — Teams call in progress"
        }
        switch manager.voiceState {
        case .on:      return "Neural TTS active — audio plays detached from terminals"
        case .off:     return "Voice muted — agents echo in chat only"
        case .unknown: return "Flag file missing or corrupt — tap Initialize"
        }
    }

    private var countsText: String {
        let playing = manager.playingCount == 0 ? "no audio" : "\(manager.playingCount) playing"
        let temps = manager.tempFileCount == 0 ? "clean" : "\(manager.tempFileCount) temp files"
        return "\(playing) · \(temps)"
    }

    private func depIndicator(_ name: String, ok: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
            Text(name)
        }
    }

    private func actionButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .controlSize(.small)
    }
}
