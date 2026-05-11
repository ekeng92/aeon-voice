# Feature: Install System

> `scripts/install.sh` (301 lines), `scripts/remote-install.sh` (79 lines)

## Purpose

Full installation pipeline for AEON Voice from source. Handles prerequisite checking, compilation, app bundle creation, voice script deployment, flag file initialization, LaunchAgent setup, and VS Code Copilot integration.

## Install Flow (install.sh)

1. Check macOS version (≥13)
2. Check Swift toolchain
3. Check Python 3 availability
4. Check/install edge-tts (`pip install --user` with fallback to `--break-system-packages`)
5. Save Python path to `~/.aeon-voice-python`
6. Build app via `make app`
7. Kill existing AEONVoice process, remove old app bundle, install new one
8. Ad-hoc codesign
9. Install 7 voice scripts + launcher to `~/.local/bin/`
10. Initialize flag file (`~/.aeon-voice-enabled`)
11. Optional: create LaunchAgent plist for auto-start
12. Optional: install Copilot instruction file to `~/.copilot/instructions/`

## Remote Install (remote-install.sh)

1. Preflight: macOS check, Swift check (triggers `xcode-select --install` if missing), Python 3, Git
2. `git clone --depth 1` to temp directory
3. Run `install.sh` with passthrough args
4. Clean up temp directory

## Sandboxed Install

`AEON_PREFIX=/tmp/aeon-test-home bash scripts/install.sh` redirects all paths to a sandbox directory.

## Non-Interactive Mode

`--non-interactive` flag auto-accepts LaunchAgent and Copilot integration prompts (used by the update mechanism).

## Security Considerations

- Remote install uses `curl | bash` pattern — standard but inherently risky
- `pip install --break-system-packages` fallback bypasses pip's externally-managed environment protection
- Ad-hoc codesign means Gatekeeper will flag the app on first launch
- No checksum or signature verification on the downloaded repository

## Known Limitations

- No rollback if installation fails midway
- `kill existing app` uses both `osascript` and `pkill` — race condition possible
- LaunchAgent uses `killall` before bootstrap — may kill other processes named AEONVoice
- No version tracking in installed files — can't detect if scripts are outdated
