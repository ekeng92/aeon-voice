import SwiftUI

struct ContentView: View {
    @ObservedObject var manager: VoiceManager
    @State private var testMessage = "Hello, this is AEON voice."

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusCard
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            toggleButton
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider().padding(.horizontal, 16)

            quickActions
                .padding(16)

            Divider().padding(.horizontal, 16)

            voiceTest
                .padding(16)

            Divider().padding(.horizontal, 16)

            activitySection
                .padding(16)

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
        .frame(width: 320)
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
                    Text(statusTitle)
                        .font(.system(size: 16, weight: .semibold))
                    Text(statusSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
    }

    // MARK: - Toggle

    private var toggleButton: some View {
        Button(action: { manager.toggle() }) {
            HStack {
                Image(systemName: manager.isEnabled ? "speaker.slash.fill" : "speaker.wave.2.fill")
                Text(manager.isEnabled ? "Mute Voice" : "Enable Voice")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(manager.isEnabled ? .green : .orange)
        .controlSize(.large)
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
                actionButton("Clean Temp", icon: "trash", tint: .secondary) {
                    manager.cleanTemp()
                }
            }

            HStack(spacing: 8) {
                actionButton("Initialize", icon: "wrench.fill", tint: .secondary) {
                    manager.initialize()
                }
                actionButton("Refresh", icon: "arrow.clockwise", tint: .secondary) {
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
                Button(action: {
                    manager.testVoice("aeon-prime-voice", label: "Prime", message: testMessage)
                }) {
                    Label("Prime", systemImage: "play.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .controlSize(.small)

                Button(action: {
                    manager.testVoice("aeon-dev-voice", label: "Dev", message: testMessage)
                }) {
                    Label("Dev", systemImage: "play.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(manager.activityLog.prefix(10)) { entry in
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
                .frame(maxHeight: 80)
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch manager.voiceState {
        case .on:      return .green
        case .off:     return .red
        case .unknown: return .orange
        }
    }

    private var statusTitle: String {
        switch manager.voiceState {
        case .on:      return "Voice On"
        case .off:     return "Voice Off"
        case .unknown: return "Not Configured"
        }
    }

    private var statusSubtitle: String {
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
