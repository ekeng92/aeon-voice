import Foundation
import AppKit
import UserNotifications

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

    struct NotificationEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let session: String?
        let prompt: String?

        var timeString: String {
            if Calendar.current.isDateInToday(timestamp) {
                return Self.timeFormatter.string(from: timestamp)
            } else {
                return Self.dateTimeFormatter.string(from: timestamp)
            }
        }

        private static let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f
        }()

        private static let dateTimeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM d HH:mm"
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
        var notificationMode: String  // "off", "whenAway", "always"
        var showUpdateNotifications: Bool
        var keepAwake: Bool

        /// Legacy key kept for backward compat decoding
        private enum CodingKeys: String, CodingKey {
            case defaultVoice, defaultRate, maxCharacters, muteOnTeams
            case notificationMode, showNotifications  // decode either key
            case showUpdateNotifications, keepAwake
        }

        static let `default` = VoiceConfig(
            defaultVoice: "en-US-AndrewNeural",
            defaultRate: "",
            maxCharacters: 500,
            muteOnTeams: true,
            notificationMode: "off",
            showUpdateNotifications: true,
            keepAwake: false
        )

        // Custom decoder so existing config files that lack newer keys
        // still load cleanly. Migrates old showNotifications bool to notificationMode.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            defaultVoice              = try c.decodeIfPresent(String.self, forKey: .defaultVoice)              ?? "en-US-AndrewNeural"
            defaultRate               = try c.decodeIfPresent(String.self, forKey: .defaultRate)               ?? ""
            maxCharacters             = try c.decodeIfPresent(Int.self,    forKey: .maxCharacters)             ?? 500
            muteOnTeams               = try c.decodeIfPresent(Bool.self,   forKey: .muteOnTeams)               ?? true
            // Migrate: if notificationMode exists use it, else convert old showNotifications bool
            if let mode = try c.decodeIfPresent(String.self, forKey: .notificationMode) {
                notificationMode = mode
            } else if let legacy = try c.decodeIfPresent(Bool.self, forKey: .showNotifications), legacy {
                notificationMode = "whenAway"
            } else {
                notificationMode = "off"
            }
            showUpdateNotifications   = try c.decodeIfPresent(Bool.self,   forKey: .showUpdateNotifications)   ?? true
            keepAwake                 = try c.decodeIfPresent(Bool.self,   forKey: .keepAwake)                 ?? false
        }

        init(defaultVoice: String, defaultRate: String, maxCharacters: Int,
             muteOnTeams: Bool, notificationMode: String = "off", showUpdateNotifications: Bool = true,
             keepAwake: Bool = false) {
            self.defaultVoice              = defaultVoice
            self.defaultRate               = defaultRate
            self.maxCharacters             = maxCharacters
            self.muteOnTeams               = muteOnTeams
            self.notificationMode          = notificationMode
            self.showUpdateNotifications   = showUpdateNotifications
            self.keepAwake                 = keepAwake
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(defaultVoice, forKey: .defaultVoice)
            try c.encode(defaultRate, forKey: .defaultRate)
            try c.encode(maxCharacters, forKey: .maxCharacters)
            try c.encode(muteOnTeams, forKey: .muteOnTeams)
            try c.encode(notificationMode, forKey: .notificationMode)
            // Don't encode legacy showNotifications
            try c.encode(showUpdateNotifications, forKey: .showUpdateNotifications)
            try c.encode(keepAwake, forKey: .keepAwake)
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
    @Published private(set) var recentNotifications: [NotificationEntry] = []
    @Published private(set) var updateState: UpdateState = .idle
    @Published private(set) var latestRemoteSHA: String?
    @Published private(set) var unreadCount: Int = 0
    @Published private(set) var actionFeedback: String?

    enum UpdateState: Equatable {
        case idle
        case checking
        case updateAvailable(String)
        case upToDate
        case updating
        case failed(String)
    }

    var isEnabled: Bool { voiceState == .on }

    var currentVoice: VoiceOption? {
        Self.availableVoices.first { $0.id == config.defaultVoice }
    }

    var buildCommit: String { BuildInfo.commitSHA }

    // MARK: - Private

    private let flagPath: String
    private let binPath: String
    private let configPath: String
    private let pythonPathFile: String
    private let notificationsPath: String
    private var pythonExecutable: String?
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var refreshTimer: Timer?
    private var caffeinateProcess: Process?
    private var notificationsLastModified: Date?
    private var notificationsTotalLines: Int = 0
    private let notificationDelegate = NotificationDelegate()
    private var lastUpdateCheckTime: Date?
    private var lastNotifiedUpdateSHA: String?
    private var feedbackTimer: Timer?

    // MARK: - Init / Deinit

    init() {
        let home = NSHomeDirectory()
        flagPath = "\(home)/.aeon-voice-enabled"
        binPath = "\(home)/.local/bin"
        configPath = "\(home)/.aeon-voice-config.json"
        pythonPathFile = "\(home)/.aeon-voice-python"
        notificationsPath = "\(home)/.aeon-voice-notifications.jsonl"

        // Set up native notifications — must be in a class so the weak delegate ref persists
        let center = UNUserNotificationCenter.current()
        center.delegate = notificationDelegate
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        loadConfig()
        readFlagFile()
        checkDependencies()
        refreshCounts()
        checkTeamsCall()
        loadNotifications()
        cleanStaleTempFiles()

        // Restore Keep Awake from persisted config
        if config.keepAwake {
            startCaffeinate()
            keepAwake = true
        }

        addLog("AEON Voice started")

        startFileMonitor()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshCounts()
            self?.checkTeamsCall()
            self?.loadNotifications()
            self?.autoCheckForUpdate()
        }

        // Run initial update check shortly after launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.autoCheckForUpdate()
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
        showFeedback("✓ Status refreshed")
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
                let msg = output.isEmpty ? "Voice initialized" : output
                self?.showFeedback("✓ \(msg)")
                self?.addLog(msg)
            }
        }
    }

    func toggleKeepAwake() {
        if keepAwake {
            stopCaffeinate()
            keepAwake = false
            config.keepAwake = false
            addLog("Keep Awake off — sleep restored")
        } else {
            startCaffeinate()
            keepAwake = true
            config.keepAwake = true
            addLog("Keep Awake on — preventing sleep")
        }
        saveConfig()
    }

    func stopAudio() {
        var killed = false
        // Kill both afplay and ffplay — voice scripts use whichever is available
        for pattern in ["afplay /tmp/aeon-voice-", "ffplay.*aeon-voice-"] {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            task.arguments = ["-f", pattern]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try? task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 { killed = true }
        }
        // Also kill any lockf holding the voice queue
        let lockTask = Process()
        lockTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        lockTask.arguments = ["-f", "lockf.*aeon-voice"]
        lockTask.standardOutput = FileHandle.nullDevice
        lockTask.standardError = FileHandle.nullDevice
        try? lockTask.run()
        lockTask.waitUntilExit()
        refreshCounts()
        let msg = killed ? "Audio stopped" : "No audio playing"
        showFeedback(killed ? "✓ \(msg)" : msg)
        addLog(msg)
    }

    func clearNotifications() {
        try? FileManager.default.removeItem(atPath: notificationsPath)
        recentNotifications = []
        notificationsLastModified = nil
        notificationsTotalLines = 0
        unreadCount = 0
        addLog("Notifications cleared")
    }

    func markAsRead() {
        if unreadCount > 0 { unreadCount = 0 }
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
        let msg = count > 0 ? "Cleaned \(count) temp file\(count == 1 ? "" : "s")" : "No temp files"
        showFeedback(count > 0 ? "✓ \(msg)" : msg)
        addLog(msg)
    }

    /// Remove stale temp files (>2 min old) on startup to clean up after crashed processes.
    private func cleanStaleTempFiles() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: "/tmp") else { return }
        let cutoff = Date().addingTimeInterval(-120)
        var count = 0
        for item in items where item.hasPrefix("aeon-voice-") {
            let path = "/tmp/\(item)"
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let modified = attrs[.modificationDate] as? Date,
               modified < cutoff {
                try? fm.removeItem(atPath: path)
                count += 1
            }
        }
        if count > 0 { addLog("Cleaned \(count) stale temp file\(count == 1 ? "" : "s")") }
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

    private func loadNotifications() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: notificationsPath) else {
            if !recentNotifications.isEmpty { recentNotifications = [] }
            return
        }

        // Only reload when file has changed
        guard let attrs = try? fm.attributesOfItem(atPath: notificationsPath),
              let modDate = attrs[.modificationDate] as? Date,
              modDate != notificationsLastModified else { return }

        let previousTotalLines = notificationsTotalLines
        let isFirstLoad = notificationsLastModified == nil
        notificationsLastModified = modDate

        guard let data = fm.contents(atPath: notificationsPath),
              let content = String(data: data, encoding: .utf8) else { return }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)

        // Rotate: if the log exceeds 10,000 lines, keep only the last 1,000
        if lines.count > 10_000 {
            let trimmed = lines.suffix(1_000).joined(separator: "\n") + "\n"
            try? trimmed.write(toFile: notificationsPath, atomically: true, encoding: .utf8)
        }

        notificationsTotalLines = lines.count
        let isoFormatter = ISO8601DateFormatter()

        var entries: [NotificationEntry] = []
        for line in lines.suffix(50) {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let ts = json["ts"] as? String,
                  let msg = json["msg"] as? String else { continue }
            let date = isoFormatter.date(from: ts) ?? Date()
            let session = json["session"] as? String
            let prompt = json["prompt"] as? String
            entries.append(NotificationEntry(timestamp: date, message: msg, session: session, prompt: prompt))
        }
        let reversed = entries.reversed() as ReversedCollection
        let newEntries = Array(reversed)
        recentNotifications = newEntries

        // Track unread and post native notifications for genuinely new entries (not on first load)
        if !isFirstLoad && lines.count > previousTotalLines {
            let newCount = lines.count - previousTotalLines
            unreadCount += newCount

            // Only post system notifications if enabled AND user appears idle (> 30s).
            // If the user is active they heard the voice; notifications are for the absent user.
            let shouldNotify: Bool
            switch config.notificationMode {
            case "always":
                shouldNotify = true
            case "whenAway":
                shouldNotify = isUserIdle(seconds: 30)
            default:
                shouldNotify = false
            }
            if shouldNotify {
                for entry in newEntries.prefix(newCount) {
                    postNativeNotification(entry)
                }
            }
        }
    }

    private func isUserIdle(seconds threshold: Double) -> Bool {
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let keyIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        return min(idle, keyIdle) > threshold
    }

    private func postNativeNotification(_ entry: NotificationEntry) {
        let content = UNMutableNotificationContent()
        content.title = entry.session ?? "AEON Voice"
        if let prompt = entry.prompt {
            content.subtitle = "Re: \(prompt)"
        }
        content.body = entry.message
        content.sound = nil  // Voice is already playing, no need for notification sound

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DispatchQueue.main.async { [weak self] in
                    self?.addLog("Notification error: \(error.localizedDescription)")
                }
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

    // MARK: - Update

    private static let githubAPIURL = "https://api.github.com/repos/ekeng92/aeon-voice/commits/main"
    private static let remoteInstallURL = "https://raw.githubusercontent.com/ekeng92/aeon-voice/main/scripts/remote-install.sh"

    func checkForUpdate() {
        updateState = .checking
        addLog("Checking for updates...")

        fetchLatestCommitSHA { [weak self] sha, errorMessage in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let remoteSHA = sha {
                    self.latestRemoteSHA = remoteSHA
                    self.applyUpdateState(remoteSHA: remoteSHA, notify: false)
                } else {
                    let msg = errorMessage ?? "Unknown error"
                    self.updateState = .failed(msg)
                    self.addLog("Update check failed: \(msg)")
                }
            }
        }
    }

    func runUpdate() {
        updateState = .updating
        addLog("Downloading and installing update...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Clone the repo to a temp directory and run install.sh locally
            // instead of piping curl to bash. This ensures we execute only
            // the code we cloned, verified by git's transport integrity.
            let cloneDir = NSTemporaryDirectory() + "aeon-voice-update-\(UUID().uuidString)"
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [
                "-c",
                """
                set -euo pipefail
                git clone --depth 1 https://github.com/ekeng92/aeon-voice.git "\(cloneDir)" 2>/dev/null && \
                bash "\(cloneDir)/scripts/install.sh" --non-interactive && \
                rm -rf "\(cloneDir)"
                """
            ]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()
                let status = task.terminationStatus
                // Clean up clone dir on failure too
                try? FileManager.default.removeItem(atPath: cloneDir)

                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if status == 0 {
                        self.addLog("Update installed. Restart the app to use the new version.")
                        self.updateState = .upToDate
                    } else {
                        self.updateState = .failed("Install exited with code \(status)")
                        self.addLog("Update failed (exit \(status))")
                    }
                }
            } catch {
                try? FileManager.default.removeItem(atPath: cloneDir)
                DispatchQueue.main.async {
                    self?.updateState = .failed(error.localizedDescription)
                    self?.addLog("Update failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Auto Update Check

    private static let updateCheckInterval: TimeInterval = 30 * 60 // 30 minutes

    private func autoCheckForUpdate() {
        // Skip if already checking or updating
        if case .checking = updateState { return }
        if case .updating = updateState { return }

        // Throttle: only check every 30 minutes
        if let last = lastUpdateCheckTime, Date().timeIntervalSince(last) < Self.updateCheckInterval {
            return
        }

        lastUpdateCheckTime = Date()

        fetchLatestCommitSHA { [weak self] sha, _ in
            DispatchQueue.main.async {
                guard let self = self, let remoteSHA = sha else { return }
                self.latestRemoteSHA = remoteSHA
                self.applyUpdateState(remoteSHA: remoteSHA, notify: true)
            }
        }
    }

    /// Shared GitHub API call to fetch the latest commit SHA for main.
    /// Calls completion with the 7-char SHA on success, or nil on failure.
    private func fetchLatestCommitSHA(completion: @escaping (String?, String?) -> Void) {
        guard let url = URL(string: Self.githubAPIURL) else {
            completion(nil, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(nil, error.localizedDescription)
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sha = json["sha"] as? String else {
                completion(nil, "Could not parse response")
                return
            }
            completion(String(sha.prefix(7)), nil)
        }.resume()
    }

    /// Apply update state from a remote SHA, optionally posting a native notification.
    private func applyUpdateState(remoteSHA: String, notify: Bool) {
        if buildCommit == "dev" {
            updateState = .updateAvailable(remoteSHA)
            addLog("Dev build, latest: \(remoteSHA)")
        } else if remoteSHA == buildCommit {
            updateState = .upToDate
            addLog("Up to date (\(remoteSHA))")
        } else {
            updateState = .updateAvailable(remoteSHA)
            addLog("Update available: \(remoteSHA)")
            if notify && config.showUpdateNotifications && lastNotifiedUpdateSHA != remoteSHA {
                lastNotifiedUpdateSHA = remoteSHA
                postUpdateNotification(sha: remoteSHA)
            }
        }
    }

    private func postUpdateNotification(sha: String) {
        let content = UNMutableNotificationContent()
        content.title = "AEON Voice Update Available"
        content.body = "A new version (\(sha)) is available. Open the app to install."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "update-available-\(sha)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DispatchQueue.main.async { [weak self] in
                    self?.addLog("Update notification error: \(error.localizedDescription)")
                }
            }
        }
        addLog("Update notification sent for \(sha)")
    }

    // MARK: - Private — Activity Log

    private func addLog(_ message: String) {
        activityLog.insert(LogEntry(timestamp: Date(), message: message), at: 0)
        if activityLog.count > 50 {
            activityLog = Array(activityLog.prefix(50))
        }
    }

    private func showFeedback(_ message: String) {
        feedbackTimer?.invalidate()
        actionFeedback = message
        feedbackTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.actionFeedback = nil
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
        // Kill any orphaned caffeinate processes from prior app instances
        // (pkill won't error if none are found)
        let cleanup = Process()
        cleanup.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        cleanup.arguments = ["-f", "caffeinate -s"]
        cleanup.standardOutput = FileHandle.nullDevice
        cleanup.standardError = FileHandle.nullDevice
        try? cleanup.run()
        cleanup.waitUntilExit()

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

/// Ensures notifications display as banners even while the menu bar app is running.
/// Must be a class instance held by VoiceManager (also a class) so the weak delegate
/// reference from UNUserNotificationCenter survives.
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}
