# AEON Voice — Review Findings

> Generated: 2026-05-10 | Audit Phase 2

## Summary

| Severity | Count |
|----------|-------|
| 🔴 Critical | 1 |
| 🟠 High | 5 |
| 🟡 Medium | 8 |
| 🟢 Low | 6 |
| **Total** | **20** |

---

## 🔴 Critical

### C1: Remote Code Execution via Update Mechanism

**File**: `VoiceManager.swift` L741-760
**Finding**: `runUpdate()` executes `curl -fsSL <URL> | bash -s -- --non-interactive` — downloading and executing arbitrary shell code from the internet without any integrity verification.

**Risk**: If the GitHub repo is compromised (account takeover, CI injection), all users auto-updating would execute malicious code with the user's full permissions.

**Recommendation**: Add SHA256 checksum verification. Store a `checksums.json` in the repo that the app verifies before executing the install script. Alternatively, use signed releases with GPG verification.

---

## 🟠 High

### H1: Uninstall Leaves Orphaned Files

**File**: `scripts/uninstall.sh`
**Finding**: Uninstall does not remove:
- `~/.aeon-voice-python`
- `~/.aeon-voice-notifications.jsonl`
- `~/.aeon-voice-queue.lock`

These files accumulate on disk and the notifications file can grow unbounded.

### H2: Notification Log Grows Without Bound

**File**: `scripts/voice/aeon-voice-common` L100-115, `VoiceManager.swift` L547-570
**Finding**: Every voice invocation appends to `~/.aeon-voice-notifications.jsonl`. The app loads the last 50 entries, but the file is never rotated or truncated. Heavy agent usage could grow this to hundreds of MB.

**Recommendation**: Rotate or truncate the JSONL file when it exceeds a size threshold (e.g. 1MB or 10,000 entries). The "Clear" button truncates it, but that requires manual user action.

### H3: JSON Config Parsing in Shell Uses Grep/Sed

**File**: `scripts/voice/aeon-voice-common` L68-79
**Finding**: `read_config_value()` parses JSON by grepping for the key and stripping quotes with sed. This breaks for:
- Values containing colons or commas
- Nested objects
- Keys that appear as substrings of other keys (e.g., `maxCharacters` matching `maxCharactersOverride`)
- Escaped quotes in values

**Recommendation**: Use `python3 -c "import json; ..."` for reliable JSON parsing. Python is already a hard dependency.

### H4: Duplicated GitHub API Logic

**File**: `VoiceManager.swift` L659-700 and L766-820
**Finding**: `checkForUpdate()` and `autoCheckForUpdate()` contain nearly identical GitHub API request and response parsing code. Any bug fix or improvement must be applied in two places.

### H5: Legacy Voice Scripts Missing Session/Prompt Support

**File**: `scripts/voice/aeon-prime-voice`, `scripts/voice/aeon-dev-voice`
**Finding**: These scripts pass the message as `$1` but don't support `--session`/`--prompt` flags. When agents use the legacy instruction format `aeon-prime-voice "message"`, notifications lack session context. The instruction file (`aeon-voice.instructions.md`) now directs agents to use `aeon-voice` instead, but old agent sessions and custom instructions may still reference the legacy scripts.

---

## 🟡 Medium

### M1: No Test Coverage

**Finding**: Zero tests across the entire project. No test target in `Package.swift`, no `Tests/` directory. The only verification is manual testing.

### M2: VoiceManager is a 903-Line God Object

**File**: `VoiceManager.swift`
**Finding**: Single class handles: state management, config I/O, file monitoring, dependency checking, process spawning, networking (GitHub API), notification delivery, update management, Teams call detection, and activity logging. Violates single responsibility.

### M3: Deprecated API Usage

**File**: `AEONVoiceApp.swift` L111
**Finding**: `NSApp.activate(ignoringOtherApps: true)` is deprecated in macOS 14+ (Sonoma). Should migrate to `NSApp.activate()` or the new activation API.

### M4: Info.plist Version Never Updated

**File**: `resources/Info.plist`
**Finding**: `CFBundleVersion` and `CFBundleShortVersionString` are both hardcoded to `1.0.0`. The update mechanism compares git SHAs instead. macOS uses these values for Notification Center grouping and other system behaviors.

### M5: edge-tts Availability Check Runs on Every Invocation

**File**: `scripts/voice/aeon-voice-common` L60-63
**Finding**: `edge_tts_available()` runs `python3 -c "import edge_tts"` every time a voice command is called. This adds ~200ms latency to every voice invocation. Could cache the result in a file with a TTL.

### M6: Config File Not Watched

**File**: `VoiceManager.swift`
**Finding**: The config file (`~/.aeon-voice-config.json`) is only loaded at app startup and on explicit refresh. If a script or external tool modifies the config, the app won't see the change until the user clicks Refresh or restarts.

### M7: Fixed Panel Height

**File**: `ContentView.swift` L75
**Finding**: The popover is fixed at 360x680 regardless of content. If notifications are expanded with many entries, content may be clipped. On displays with smaller available menu bar space, the panel may extend below the screen.

### M8: No Startup Temp File Cleanup

**File**: `VoiceManager.swift`
**Finding**: Stale temp files from crashed voice processes are only cleaned when:
- A new voice is played (in `speak_edge_tts`)
- User clicks "Clean Temp" manually

On app startup, no cleanup runs. If the app was force-quit during playback, temp files persist until the next voice call.

---

## 🟢 Low

### L1: Build Directory Staging Artifact

**File**: `Makefile` L21
**Finding**: `make app` creates `build/AEON Voice.app` which is cleaned by `install.sh` but not by `.gitignore`. Running `make app` without `make install` leaves the staging directory.

### L2: Sound File Paths Hardcoded

**File**: `scripts/voice/aeon-voice-common` L7-8
**Finding**: System sound paths (`/System/Library/Sounds/Glass.aiff`, `Funk.aiff`) are hardcoded. These exist on all macOS versions targeted but could theoretically change.

### L3: aeon-voice-status Is Just a Redirect

**File**: `scripts/voice/aeon-voice-status` (4 lines)
**Finding**: `exec "$HOME/.local/bin/aeon-voice-init" status` — the script exists solely to redirect. Could be a symlink or alias instead.

### L4: No `--help` Flag Support on Voice Scripts

**Finding**: None of the voice scripts support `--help` or `--version` flags. Running `aeon-voice --help` attempts to speak the word "help".

### L5: Makefile Uses macOS-Specific sed

**File**: `Makefile` L26-28
**Finding**: `sed -i '' ...` is macOS-specific syntax. GNU sed requires `sed -i ...` (no empty string argument). This is fine since the app is macOS-only, but could surprise contributors.

### L6: No License Header in Source Files

**Finding**: The repo has an MIT `LICENSE` file but individual source files have no license headers. Standard practice for small MIT projects, but noted.

---

## Cross-Cutting Patterns

1. **No testing at all** — the biggest gap. Every fix risks regression without automated verification
2. **Shell JSON parsing** — the common library uses grep/sed for JSON, while the Swift app uses proper Codable. The shell scripts should use python3 (already required)
3. **File cleanup gaps** — multiple files written to disk but not cleaned up by uninstall or on startup
4. **Duplication** — GitHub API logic, and notification writing logic appears in both shell and Swift
5. **Security posture** — `curl | bash` update pattern, no integrity verification, pip `--break-system-packages` fallback

## Test Suite Status

No tests exist. Cannot report pass/fail.
