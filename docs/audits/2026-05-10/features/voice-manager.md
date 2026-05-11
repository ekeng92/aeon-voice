# Feature: Voice Manager (Core Engine)

> `Sources/AEONVoice/VoiceManager.swift` (903 lines)

## Purpose

Central state manager for the entire app. Handles: voice flag file monitoring, config persistence, dependency checking, process management (caffeinate, audio), Teams call detection, notification log watching, update checking via GitHub API, and all user-initiated actions.

## Architecture

Single `ObservableObject` class with ~20 `@Published` properties. All I/O operations run on background queues via `DispatchQueue.global()`. A 5-second timer drives periodic refresh of: temp file counts, Teams call status, notification log, and auto update checks.

### State Machine

```
Flag file → readFlagFile() → voiceState: .on | .off | .unknown
Config file → loadConfig() → config: VoiceConfig
JSONL log → loadNotifications() → recentNotifications: [NotificationEntry]
GitHub API → autoCheckForUpdate() → updateState: .idle | .checking | .updateAvailable | .upToDate | .updating | .failed
```

### File Watchers

- `~/.aeon-voice-enabled`: GCD `DispatchSource.makeFileSystemObjectSource` with `.write`, `.delete`, `.rename` events
- `~/.aeon-voice-notifications.jsonl`: Polled every 5 seconds via modification date comparison (no GCD watcher)
- `~/.aeon-voice-config.json`: Only loaded on init and explicit refresh (no file watcher)

### Process Management

| Process | Mechanism | Lifecycle |
|---------|-----------|-----------|
| caffeinate | `Process()` retained in `caffeinateProcess` | Terminated on toggle off or app quit |
| afplay (stop) | `pkill -f "afplay /tmp/aeon-voice-"` | One-shot kill |
| pgrep (count) | `pgrep -f "afplay /tmp/aeon-voice-"` | Polled every 5s |
| edge-tts (test) | `Process()` with explicit `waitUntilExit()` | Blocks background thread |
| pmset (Teams) | `pmset -g assertions` | Polled every 5s on utility queue |

### Config Model

`VoiceConfig` is `Codable` with a custom `init(from:)` that provides defaults for missing keys (forward compatibility). Saved with `prettyPrinted` + `sortedKeys` formatting.

### Update Mechanism

1. GitHub API: `GET /repos/ekeng92/aeon-voice/commits/main` — fetches latest commit SHA
2. Compares first 7 chars of remote SHA to `BuildInfo.commitSHA`
3. Update: downloads `remote-install.sh` via `curl | bash -- --non-interactive`
4. Auto-check: every 30 minutes, with one-time native notification per new SHA

### Notification Pipeline

1. Voice scripts append JSONL to `~/.aeon-voice-notifications.jsonl`
2. App polls file every 5s via modification date
3. New entries increment `unreadCount` and post `UNNotificationRequest` if user appears idle (>30s)
4. Idle detection: `CGEventSource.secondsSinceLastEventType` for mouse + keyboard

## Dependencies

- Foundation, AppKit, SwiftUI, Combine, CoreGraphics, UserNotifications
- No third-party dependencies

## Known Limitations / TODOs Found in Code

- 903 lines in a single file — handles too many concerns
- `testAllVoices()` runs synchronously on a background thread with no cancellation support
- `checkForUpdate()` and `autoCheckForUpdate()` contain duplicated GitHub API logic
- No retry logic for failed update checks
- `runUpdate()` pipes untrusted remote script through bash
- Config file is not validated against a schema — malformed JSON silently falls back to defaults
- No cleanup of orphaned temp files on app launch (only manual "Clean Temp" or during voice playback)
- `isUserIdle()` using CGEventSource may not work correctly if the app doesn't have Accessibility permissions
