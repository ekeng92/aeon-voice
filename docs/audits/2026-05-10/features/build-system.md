# Feature: Build System

> `Makefile` (52 lines), `Package.swift` (14 lines), `BuildInfo.swift` (7 lines), `resources/Info.plist` (28 lines)

## Purpose

Compile the SwiftUI app from source, create a macOS `.app` bundle, and manage build artifacts.

## Build Targets

| Target | Command | What It Does |
|--------|---------|-------------|
| `build` | `make build` | Swift release build, no app bundle |
| `app` | `make app` | Full app bundle: build + bundle structure + codesign + commit SHA stamp |
| `install` | `make install` | Delegates to `scripts/install.sh` |
| `uninstall` | `make uninstall` | Delegates to `scripts/uninstall.sh` |
| `run` | `make run` | Build + open the app |
| `clean` | `make clean` | Remove `.build/` and `build/` directories |

## Build Info Stamping

The `make app` target:
1. Reads current git commit SHA
2. `sed` replaces the placeholder in `BuildInfo.swift`
3. Compiles with the real SHA embedded
4. Restores `BuildInfo.swift` to placeholder ("dev") so the repo stays clean

## Package.swift

Minimal SPM manifest:
- Target: `AEONVoice` (executable)
- Platform: macOS 13+
- No dependencies
- No test targets

## Info.plist

- Bundle ID: `com.aeon.voice`
- Version: `1.0.0` (static, not updated)
- `LSUIElement: true` (menu bar app, no dock icon)
- `NSHighResolutionCapable: true`

## Known Limitations

- `Info.plist` version is hardcoded at 1.0.0 — never incremented
- `sed -i ''` is macOS-specific — won't work on GNU sed (Linux)
- No CI/CD pipeline — builds are local only
- `.build/` directory (SPM cache) is in `.gitignore` but `build/` directory (app bundle staging) is not explicitly ignored — cleaned by install.sh after copy
