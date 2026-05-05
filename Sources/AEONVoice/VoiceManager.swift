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

    struct VoiceOption: Identifiable, Hashable {
        let id: String
        let name: String
        let style: String
        let defaultRate: String
    }

    struct VoiceConfig: Codable {
        var defaultVoice: String
        var defaultRate: String
        var maxCharacters: Int
        var muteOnTeams: Bool
        var showNotifications: Bool

        static let `default` = VoiceConfig(
            defaultVoice: "en-US-AndrewNeural",
            defaultRate: "",
            maxCharacters: 500,
            muteOnTeams: true,
            showNotifications: false
        )

        // Custom decoder so existing config files that lack newer keys
        // (e.g. showNotifications) still load cleanly instead of failing.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            defaultVoice      = try c.decodeIfPresent(String.self, forKey: .defaultVoice)      ?? "en-US-AndrewNeural"
            defaultRate       = try c.decodeIfPresent(String.self, forKey: .defaultRate)       ?? ""
            maxCharacters     = try c.decodeIfPresent(Int.self,    forKey: .maxCharacters)     ?? 500
            muteOnTeams       = try c.decodeIfPresent(Bool.self,   forKey: .muteOnTeams)       ?? true
            showNotifications = try c.decodeIfPresent(Bool.self,   forKey: .showNotifications) ?? false
        }

        init(defaultVoice: String, defaultRate: String, maxCharacters: Int,
             muteOnTeams: Bool, showNotifications: Bool) {
            self.defaultVoice      = defaultVoice
            self.defaultRate       = defaultRate
            self.maxCharacters     = maxCharacters
            self.muteOnTeams       = muteOnTeams
            self.showNotifications = showNotifications
        }
    }

    // MARK: - Available Voices

    static let availableVoices: [VoiceOption] = [
        VoiceOption(id: "en-US-AndrewNeural", name: "Andrew", style: "Calm, measured", defaultRate: ""),
        VoiceOption(id: "en-US-AvaNeural", name: "Ava", style: "Confident, expressive", defaultRate: "+10%"),
        VoiceOption(id: "en-US-AriaNeural", name: "Aria", style: "Professional, versatile", defaultRate: ""),
        VoiceOption(id: "en-US-ChristopherNeural", name: "Christopher", style: "Reliable, clear", defaultRate: ""),
        VoiceOption(id: "en-US-EricNeural", name: "Eric", style: "Conversational, natural", defaultRate: ""),
        VoiceOption(id: "en-US-GuyNeural", name: "Guy", style: "Casual, friendly", defaultRate: ""),
        VoiceOption(id: "en-US-JennyNeural", name: "Jenny", style: "Friendly, warm", defaultRate: ""),
        VoiceOption(id: "en-US-MichelleNeural", name: "Michelle", style: "Warm, engaging", defaultRate: ""),
        VoiceOption(id: "en-US-SteffanNeural", name: "Steffan", style: "Authoritative, steady", defaultRate: ""),
    ]

    // MARK: - Published State

    @Published private(set) var voiceState: VoiceState = .unknown
    @Published private(set) var pythonAvailable = false
    @Published private(set) var edgeTTSAvailable = false
    @Published private(set) var playingCount = 0
    @Published private(set) var tempFileCount = 0
    @Published private(set) var activityLog: [LogEntry] = []
    @Published private(set) var keepAwake = false
    @Published private(set) var teamsCallActive = false
    @Published var config: VoiceConfig = .default

    var isEnabled: Bool { voiceState == .on }

    var currentVoice: VoiceOption? {
        Self.availableVoices.first { $0.id == config.defaultVoice }
    }

    // MARK: - Private

    private let flagPath: String
    private let binPath: String
    private let configPath: String
    private let pythonPathFile: String
    private var pythonExecutable: String?
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var refreshTimer: Timer?
    private var caffeinateProcess: Process?

    // MARK: - Init / Deinit

    init() {
        let home = NSHomeDirectory()
        flagPath = "\(home)/.aeon-voice-enabled"
        binPath = "\(home)/.local/bin"
        configPath = "\(home)/.aeon-voice-config.json"
        pythonPathFile = "\(home)/.aeon-voice-python"

        loadConfig()
        readFlagFile()
        checkDependencies()
        refreshCounts()
        checkTeamsCall()
        addLog("AEON Voice started")

        startFileMonitor()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshCounts()
            self?.checkTeamsCall()
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
        loadConfig()
        readFlagFile()
        checkDependencies()
        refreshCounts()
        checkTeamsCall()
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

    /// Test a voice by edge-tts voice ID. Bypasses mute state so users can preview.
    func testVoiceById(_ voiceId: String, message: String) {
        let voice = Self.availableVoices.first { $0.id == voiceId }
        let name = voice?.name ?? voiceId
        let rate = voice?.defaultRate ?? ""

        guard let python = pythonExecutable, pythonAvailable && edgeTTSAvailable else {
            addLog("Cannot test: edge-tts not available")
            return
        }

        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addLog("Cannot test: message is empty")
            return
        }

        let short = trimmed.count > 50 ? String(trimmed.prefix(50)) + "…" : trimmed
        addLog("Testing \(name): \"\(short)\"")

        runVoicePreview(python: python, voiceId: voiceId, rate: rate, message: trimmed, label: name)
    }

    /// Preview every bundled voice sequentially. Bypasses mute state for testing.
    func testAllVoices(message: String) {
        guard let python = pythonExecutable, pythonAvailable && edgeTTSAvailable else {
            addLog("Cannot test all: edge-tts not available")
            return
        }

        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addLog("Cannot test all: message is empty")
            return
        }

        addLog("Testing all \(Self.availableVoices.count) voices")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for voice in Self.availableVoices {
                self?.runVoicePreviewSync(
                    python: python,
                    voiceId: voice.id,
                    rate: voice.defaultRate,
                    message: "\(voice.name). \(trimmed)",
                    label: voice.name
                )
            }
            DispatchQueue.main.async { self?.refreshCounts() }
        }
    }

    private func runVoicePreview(python: String, voiceId: String, rate: String, message: String, label: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runVoicePreviewSync(python: python, voiceId: voiceId, rate: rate, message: message, label: label)
            DispatchQueue.main.async { self?.refreshCounts() }
        }
    }

    private func runVoicePreviewSync(python: String, voiceId: String, rate: String, message: String, label: String) {
        let tmpfile = "/tmp/aeon-voice-test-\(UUID().uuidString).mp3"

        let gen = Process()
        let errorPipe = Pipe()
        gen.executableURL = URL(fileURLWithPath: python)
        var args = ["-m", "edge_tts", "--voice", voiceId]
        if !rate.isEmpty {
            args += ["--rate", rate]
        }
        args += ["--text", message, "--write-media", tmpfile]
        gen.arguments = args
        gen.standardOutput = FileHandle.nullDevice
        gen.standardError = errorPipe

        do {
            try gen.run()
            gen.waitUntilExit()

            guard gen.terminationStatus == 0, FileManager.default.fileExists(atPath: tmpfile) else {
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown error"
                DispatchQueue.main.async { [weak self] in
                    self?.addLog("\(label) test failed: \(errorText.prefix(90))")
                }
                return
            }

            let play = Process()
            play.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
            play.arguments = [tmpfile]
            play.standardOutput = FileHandle.nullDevice
            play.standardError = FileHandle.nullDevice
            try play.run()
            play.waitUntilExit()
            try? FileManager.default.removeItem(atPath: tmpfile)
            DispatchQueue.main.async { [weak self] in
                self?.addLog("Played \(label)")
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.addLog("\(label) playback error: \(error.localizedDescription)")
            }
            try? FileManager.default.removeItem(atPath: tmpfile)
        }
    }

    // MARK: - Config Management

    func loadConfig() {
        guard let data = FileManager.default.contents(atPath: configPath),
              let loaded = try? JSONDecoder().decode(VoiceConfig.self, from: data) else {
            return
        }
        config = loaded
    }

    func saveConfig() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        FileManager.default.createFile(atPath: configPath, contents: data)
        addLog("Settings saved")
    }

    func setDefaultVoice(_ voiceId: String) {
        config.defaultVoice = voiceId
        if let voice = Self.availableVoices.first(where: { $0.id == voiceId }) {
            config.defaultRate = voice.defaultRate
        }
        saveConfig()
        addLog("Default voice: \(currentVoice?.name ?? voiceId)")
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
        let savedPython = readSavedPythonPath()
        let candidates = ([savedPython] + [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/usr/bin/python3"
        ]).compactMap { $0 }

        var seen = Set<String>()
        let available = candidates.filter { path in
            guard seen.insert(path).inserted else { return false }
            return FileManager.default.isExecutableFile(atPath: path)
        }

        pythonAvailable = !available.isEmpty
        pythonExecutable = available.first { python in
            commandSucceeds(python, arguments: ["-m", "edge_tts", "--help"])
        }
        edgeTTSAvailable = pythonExecutable != nil
    }

    private func readSavedPythonPath() -> String? {
        guard let data = FileManager.default.contents(atPath: pythonPathFile),
              let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        return path
    }

    private func commandSucceeds(_ executable: String, arguments: [String]) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
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

    private func checkTeamsCall() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let task = Process()
            let pipe = Pipe()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            task.arguments = ["-g", "assertions"]
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let active = output.contains("Microsoft Teams Call in progress")
                DispatchQueue.main.async {
                    self?.teamsCallActive = active
                }
            } catch {
                // Silently handle
            }
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
