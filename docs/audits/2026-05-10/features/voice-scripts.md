# Feature: Voice Scripts (CLI)

> `scripts/voice/` — 7 scripts, ~282 lines total

## Purpose

Shell-based CLI tools for voice output, toggling, initialization, and status. These are the interface used by AI agents and human users. The shared library (`aeon-voice-common`) handles all TTS logic.

## Script Map

### `aeon-voice-common` (189 lines) — Shared Library

Not executable directly. Sourced by all other scripts.

**Functions:**
- `ensure_voice_flag()` — creates `~/.aeon-voice-enabled` if missing/corrupt, defaults to "on"
- `voice_flag_value()` — reads flag file, returns "on" or "off"
- `voice_enabled()` — boolean check
- `set_voice_flag()` — writes "on" or "off" to flag file
- `play_voice_state_sound()` — plays Glass.aiff (on) or Funk.aiff (off) via afplay
- `teams_call_active()` — checks pmset for Teams power assertion
- `edge_tts_available()` — verifies python3 + edge_tts import
- `read_config_value()` — grep-based JSON value reader
- `apply_max_chars()` — truncates message to configured limit
- `maybe_notify()` — appends to JSONL notification log via python3
- `speak_edge_tts()` — main TTS function with two-phase pipeline:
  1. Phase 1 (unlocked): Generate audio via edge-tts to temp file
  2. Phase 2 (locked): Play via `lockf -k -t 120` for serialized queuing
  - Fully detached via `&!` (zsh disown)
  - Stale temp cleanup (>2 min) on each invocation
  - Optional `ffplay` support (falls back to `afplay`)

### `aeon-voice` (22 lines) — Default Voice Command

Reads voice/rate from config, parses `--session` and `--prompt` flags, calls `speak_edge_tts`. This is what agents use.

### `aeon-prime-voice` (6 lines) — Prime Voice

Hardcoded: Andrew (en-US), no rate modifier. Does NOT pass session/prompt flags.

### `aeon-dev-voice` (6 lines) — Dev Voice

Hardcoded: Ava (en-US), +10% rate. Does NOT pass session/prompt flags.

### `aeon-voice-toggle` (27 lines) — Toggle

Flips the flag file and plays a state sound. Supports `status` subcommand.

### `aeon-voice-init` (28 lines) — Initialize/Repair

Subcommands: `on`, `off`, `status`, or bare (ensure flag exists).

### `aeon-voice-status` (4 lines) — Status

Delegates to `aeon-voice-init status`.

## Data Flow

```
Agent/User → aeon-voice "message" --session "X" --prompt "Y"
  → source aeon-voice-common
  → speak_edge_tts(voice, rate, message, session, prompt)
    → check flag file, Teams mute, max chars
    → (detached subprocess)
      → edge-tts generates .mp3
      → lockf queue → afplay plays .mp3
      → notification log appended
      → temp files cleaned
```

## Known Limitations

- `read_config_value()` uses grep/sed for JSON parsing — fragile for nested or escaped values
- `aeon-prime-voice` and `aeon-dev-voice` don't support `--session`/`--prompt` flags (legacy scripts)
- `mktemp` + appended `.mp3` extension creates two files (base + renamed) — handled but fragile
- No error reporting to caller — all errors are silently swallowed in the detached subprocess
- `edge_tts_available()` runs `python3 -c "import edge_tts"` on every invocation — adds ~200ms latency
