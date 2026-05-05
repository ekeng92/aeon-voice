import Foundation
import AppKit

final class VoiceManager: ObservableObject {

    // MARK: - Types

    enum VoiceState { case on, off, unknown }

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String

        var timeString: String {
            Self.formatter.string(from: timestamp)
        }

        private static let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            return f
        }()
    }

    // MARK: - Published State

    @Published private(set) var voiceState: VoiceState = .unknown
    @Published private(set) var pythonAvailable = false
    @Published private(set) var edgeTTSAvailable = false
    @Published private(set) var playingCount = 0
    @Published private(set) var tempFileCount = 0
    @Published private(set) var activityLog: [LogEntry] = []
    @Published private(set) var keepAwake = false

    var isEnabled: Bool { voiceState == .on }

    // MARK: - Private

    private let flagPath: String
    private let binPath: String
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var refreshTimer: Timer?
    private var caffeinateProcess: Process?

    // MARK: - Init / Deinit

    init() {
        let home = NSHomeDirectory()
        flagPath = "\(home)/.aeon-voice-enabled"
        binPath = "\(home)/.local/bin"

        readFlagFile()
        checkDependencies()
        refreshCounts()
        addLog("AEON Voice started")

        startFileMonitor()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshCounts()
        }
    }

    deinit {
        if let source = dispatchSource {
            source.cancel() // cancel handler closes the fd
        } else if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
        refreshTimer?.invalidate()
        stopCaffeinate()
    }

    // MARK: - Public Actions

    func refresh() {
        readFlagFile()
        checkDependencies()
        refreshCounts()
        addLog("Status refreshed")
    }

    func toggle() {
        runVoiceScript("aeon-voice-toggle") { [weak self] output in
            DispatchQueue.main.async {
                self?.readFlagFile()
                self?.addLog(output.isEmpty ? "Voice toggled" : output)
            }
        }
    }

    func initialize() {
        runVoiceScript("aeon-voice-init") { [weak self] output in
            DispatchQueue.main.async {
                self?.readFlagFile()
                self?.restartFileMonitorIfNeeded()
                self?.addLog(output.isEmpty ? "Voice initialized" : output)
            }
        }
    }

    func toggleKeepAwake() {
        if keepAwake {
            stopCaffeinate()
            keepAwake = false
            addLog("Keep Awake off — sleep restored")
        } else {
            startCaffeinate()
            keepAwake = true
            addLog("Keep Awake on — preventing sleep")
        }
    }

    func stopAudio() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-f", "afplay /tmp/aeon-voice-"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        refreshCounts()
        addLog(task.terminationStatus == 0 ? "Audio stopped" : "No audio playing")
    }

    func cleanTemp() {
        var count = 0
        let fm = FileManager.default
        if let items = try? fm.contentsOfDirectory(atPath: "/tmp") {
            for item in items where item.hasPrefix("aeon-voice-") {
                try? fm.removeItem(atPath: "/tmp/\(item)")
                count += 1
            }
        }
        refreshCounts()
        addLog(count > 0 ? "Cleaned \(count) temp file\(count == 1 ? "" : "s")" : "No temp files")
    }

    func testVoice(_ command: String, label: String, message: String) {
        let path = "\(binPath)/\(command)"
        guard FileManager.default.isExecutableFile(atPath: path) else {
            addLog("\(label) script not found at \(path)")
            return
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = [message]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            let short = message.count > 50 ? String(message.prefix(50)) + "…" : message
            addLog("Playing \(label): \"\(short)\"")
        } catch {
            addLog("Test failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private — State Readers

    private func readFlagFile() {
        guard let data = FileManager.default.contents(atPath: flagPath),
              let content = String(data: data, encoding: .utf8) else {
            voiceState = .unknown
            return
        }
        switch content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "on":  voiceState = .on
        case "off": voiceState = .off
        default:    voiceState = .unknown
        }
    }

    private func checkDependencies() {
        pythonAvailable = ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"]
            .contains { FileManager.default.isExecutableFile(atPath: $0) }

        if pythonAvailable {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["python3", "-m", "edge_tts", "--help"]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try? task.run()
            task.waitUntilExit()
            edgeTTSAvailable = task.terminationStatus == 0
        } else {
            edgeTTSAvailable = false
        }
    }

    private func refreshCounts() {
        // Count afplay processes for aeon voice
        let pgrep = Process()
        let pipe = Pipe()
        pgrep.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        pgrep.arguments = ["-f", "afplay /tmp/aeon-voice-"]
        pgrep.standardOutput = pipe
        pgrep.standardError = FileHandle.nullDevice
        try? pgrep.run()
        pgrep.waitUntilExit()

        if pgrep.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            playingCount = output.split(separator: "\n").count
        } else {
            playingCount = 0
        }

        // Count temp files
        if let items = try? FileManager.default.contentsOfDirectory(atPath: "/tmp") {
            tempFileCount = items.filter { $0.hasPrefix("aeon-voice-") }.count
        } else {
            tempFileCount = 0
        }
    }

    // MARK: - Private — Script Runner

    private func runVoiceScript(_ name: String, completion: @escaping (String) -> Void) {
        let path = "\(binPath)/\(name)"
        guard FileManager.default.isExecutableFile(atPath: path) else {
            addLog("Script not found: \(name)")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            let pipe = Pipe()
            task.executableURL = URL(fileURLWithPath: path)
            task.standardOutput = pipe
            task.standardError = pipe
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                completion(output)
            } catch {
                completion("Error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private — Activity Log

    private func addLog(_ message: String) {
        activityLog.insert(LogEntry(timestamp: Date(), message: message), at: 0)
        if activityLog.count > 50 {
            activityLog = Array(activityLog.prefix(50))
        }
    }

    // MARK: - Private — File Monitor

    private func startFileMonitor() {
        stopFileMonitor()

        guard FileManager.default.fileExists(atPath: flagPath) else { return }

        fileDescriptor = open(flagPath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.readFlagFile()
            }
        }
        source.setCancelHandler { [fd = self.fileDescriptor] in
            close(fd)
        }
        source.resume()
        dispatchSource = source
    }

    private func stopFileMonitor() {
        dispatchSource?.cancel()
        dispatchSource = nil
        fileDescriptor = -1
    }

    private func restartFileMonitorIfNeeded() {
        if dispatchSource == nil && FileManager.default.fileExists(atPath: flagPath) {
            startFileMonitor()
        }
    }

    // MARK: - Private — Caffeinate

    private func startCaffeinate() {
        stopCaffeinate()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        task.arguments = ["-s"]  // prevent system sleep on AC
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            caffeinateProcess = task
        } catch {
            addLog("caffeinate failed: \(error.localizedDescription)")
        }
    }

    private func stopCaffeinate() {
        if let proc = caffeinateProcess, proc.isRunning {
            proc.terminate()
            proc.waitUntilExit()
        }
        caffeinateProcess = nil
    }
}
