# Feature: Uninstall System

> `scripts/uninstall.sh` (99 lines)

## Purpose

Clean removal of AEON Voice: stops the app, removes LaunchAgent, deletes app bundle, scripts, temp files, Copilot instruction file, and config. Preserves the flag file by design.

## Uninstall Flow

1. Kill running AEONVoice process
2. Bootout and remove LaunchAgent plist
3. Remove app bundle from `~/Applications/`
4. Remove 8 voice scripts from `~/.local/bin/`
5. Kill any playing `afplay` processes
6. Clean `/tmp/aeon-voice-*` temp files
7. Remove Copilot instruction file
8. Remove config file

## Preserved Files

- `~/.aeon-voice-enabled` (user preference)
- `~/.aeon-voice-python` (not mentioned in uninstall)
- `~/.aeon-voice-notifications.jsonl` (not mentioned in uninstall)

## Known Limitations

- Does NOT remove `~/.aeon-voice-python` or `~/.aeon-voice-notifications.jsonl`
- Does NOT remove `~/.aeon-voice-queue.lock`
- No `AEON_PREFIX` support (unlike install.sh) — always targets real home directory
- `pkill -f "afplay /tmp/aeon-voice-"` could match other processes with similar paths
