# AEON Voice — Fix Report

> Generated: 2026-05-10 | Audit Phase 3

## Fixes Applied

### 🔴 C1: Remote Code Execution via Update — FIXED

**Change**: Replaced `curl | bash` in `runUpdate()` with `git clone --depth 1` + local `install.sh` execution. The app now clones the repo to a unique temp directory, runs the install script from the cloned code, and cleans up. Git's transport layer provides integrity verification.

**Files**: `Sources/AEONVoice/VoiceManager.swift`

### 🟠 H1: Uninstall Leaves Orphaned Files — FIXED

**Change**: Added cleanup of `~/.aeon-voice-python`, `~/.aeon-voice-notifications.jsonl`, and `~/.aeon-voice-queue.lock` to the uninstall script.

**Files**: `scripts/uninstall.sh`

### 🟠 H2: Notification Log Grows Without Bound — FIXED

**Change**: Added rotation logic in `loadNotifications()`. When the JSONL file exceeds 10,000 lines, it's truncated to the last 1,000 lines. This runs on the 5-second polling cycle.

**Files**: `Sources/AEONVoice/VoiceManager.swift`

### 🟠 H3: JSON Config Parsing in Shell Uses Grep/Sed — FIXED

**Change**: Replaced `read_config_value()` grep/sed implementation with python3 JSON parsing. Uses `json.load()` for correct handling of all JSON value types including booleans, nested objects, and escaped strings.

**Files**: `scripts/voice/aeon-voice-common`

### 🟠 H4: Duplicated GitHub API Logic — FIXED

**Change**: Extracted `fetchLatestCommitSHA()` and `applyUpdateState()` as shared methods. Both `checkForUpdate()` and `autoCheckForUpdate()` now delegate to these shared methods, eliminating ~40 lines of duplication.

**Files**: `Sources/AEONVoice/VoiceManager.swift`

### 🟠 H5: Legacy Voice Scripts Missing Session/Prompt — FIXED

**Change**: Added `--session`/`-s` and `--prompt`/`-p` flag parsing to `aeon-prime-voice` and `aeon-dev-voice`. Both now pass session and prompt context through to `speak_edge_tts()`.

**Files**: `scripts/voice/aeon-prime-voice`, `scripts/voice/aeon-dev-voice`

### 🟡 M3: Deprecated API Usage — FIXED

**Change**: Added `if #available(macOS 14.0, *)` guard around `NSApp.activate()` with fallback to `NSApp.activate(ignoringOtherApps: true)` for macOS 13.

**Files**: `Sources/AEONVoice/AEONVoiceApp.swift`

### 🟡 M8: No Startup Temp File Cleanup — FIXED

**Change**: Added `cleanStaleTempFiles()` method that removes temp files older than 2 minutes. Called during app initialization after dependency checks.

**Files**: `Sources/AEONVoice/VoiceManager.swift`

## Deferred Items

| Finding | Severity | Reason |
|---------|----------|--------|
| M1: No Test Coverage | 🟡 | Requires test architecture decision (XCTest vs UI testing). Not a quick fix. |
| M2: God Object | 🟡 | Refactoring VoiceManager into smaller classes is a design task, not a bug fix |
| M4: Info.plist version hardcoded | 🟡 | Requires versioning strategy decision (semver tags?) |
| M5: edge-tts check latency | 🟡 | Would need a caching mechanism with TTL — low impact |
| M6: Config file not watched | 🟡 | Adding a second GCD file watcher is straightforward but changes behavior |
| M7: Fixed panel height | 🟡 | SwiftUI layout redesign needed |
| L1-L6 | 🟢 | All low severity, deferred |

## Build Verification

```
swift build -c release
Build complete! (3.98s)
```

All changes compile cleanly. No test suite exists to run.
