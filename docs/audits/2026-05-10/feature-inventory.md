# AEON Voice — Feature Inventory

> Generated: 2026-05-10 | Audit Phase 1

## Repo Overview

- **Language**: Swift 5.9 + Zsh shell scripts
- **Framework**: SwiftUI (macOS 13+), no external dependencies
- **Build**: Swift Package Manager + Makefile
- **Tests**: None (no test target, no test framework)
- **Lines of code**: ~2,400 (1,652 Swift, 480 shell, 301 install script)
- **Binary size**: ~350KB compiled

## Feature Inventory

### Layer: SwiftUI App

| # | Feature | Files | Lines | Tests | Docs |
|---|---------|-------|-------|-------|------|
| 1 | Menu Bar App Shell | `AEONVoiceApp.swift` | 123 | None | README |
| 2 | UI Panel (ContentView) | `ContentView.swift` | 619 | None | README |
| 3 | Voice Manager (Core) | `VoiceManager.swift` | 903 | None | README |
| 4 | Build Info | `BuildInfo.swift` | 7 | None | None |

### Layer: CLI Scripts

| # | Feature | Files | Lines | Tests | Docs |
|---|---------|-------|-------|-------|------|
| 5 | Voice Common (Shared Library) | `scripts/voice/aeon-voice-common` | 189 | None | None |
| 6 | Default Voice Command | `scripts/voice/aeon-voice` | 22 | None | README |
| 7 | Prime Voice | `scripts/voice/aeon-prime-voice` | 6 | None | README |
| 8 | Dev Voice | `scripts/voice/aeon-dev-voice` | 6 | None | README |
| 9 | Voice Toggle | `scripts/voice/aeon-voice-toggle` | 27 | None | README |
| 10 | Voice Init | `scripts/voice/aeon-voice-init` | 28 | None | README |
| 11 | Voice Status | `scripts/voice/aeon-voice-status` | 4 | None | README |

### Layer: Installation

| # | Feature | Files | Lines | Tests | Docs |
|---|---------|-------|-------|-------|------|
| 12 | Install Script | `scripts/install.sh` | 301 | None | README |
| 13 | Remote Install | `scripts/remote-install.sh` | 79 | None | README |
| 14 | Uninstall Script | `scripts/uninstall.sh` | 99 | None | README |

### Layer: Build System

| # | Feature | Files | Lines | Tests | Docs |
|---|---------|-------|-------|-------|------|
| 15 | Makefile | `Makefile` | 52 | None | None |
| 16 | Package Manifest | `Package.swift` | 14 | None | None |
| 17 | Info.plist | `resources/Info.plist` | 28 | None | None |

### Layer: Integration

| # | Feature | Files | Lines | Tests | Docs |
|---|---------|-------|-------|-------|------|
| 18 | Copilot Instructions | `examples/aeon-voice.instructions.md` | ~80 | None | README |

### Layer: Documentation

| # | Feature | Files | Lines | Tests | Docs |
|---|---------|-------|-------|-------|------|
| 19 | README | `README.md` | 250+ | N/A | Self |
| 20 | Product Plan | `docs/PRODUCT-PLAN.md` | ? | N/A | Self |
| 21 | Scheduler Architecture | `docs/SCHEDULER-ARCHITECTURE.md` | ? | N/A | Self |
| 22 | Worker Briefs | `docs/worker-briefs/*` | ? | N/A | Self |

## Cross-Cutting Observations

1. **Zero test coverage** across the entire project. No test target in Package.swift, no test directory
2. **Single-file architecture** for the Swift app: VoiceManager.swift (903 lines) handles state, config, file I/O, process management, networking, and notifications
3. **No error logging to disk**: errors are shown in the in-memory activity log only, lost on app restart
4. **Security surface**: The update mechanism downloads and executes a remote shell script (`curl | bash`)
5. **Config file**: JSON at `~/.aeon-voice-config.json` with forward-compatible decoder
6. **Flag file**: Simple text file at `~/.aeon-voice-enabled` with file system monitoring via GCD
7. **Process management**: caffeinate, pkill, pgrep, afplay spawned via Foundation Process API
8. **Notification model**: JSONL append log at `~/.aeon-voice-notifications.jsonl`, watched by the app on 5-second timer
