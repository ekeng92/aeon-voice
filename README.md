# AEON Voice

Native macOS menu bar app for controlling neural text-to-speech voice output.

A 60KB SwiftUI binary that lives in your menu bar. Click the waveform icon → popover panel with full voice control. No Electron, no Python GUI, no runtime dependencies.

## Features

- **Menu bar native** — lives alongside Wi-Fi, Bluetooth, and battery. No dock icon, no window to manage
- **One-click toggle** — mute/unmute voice output instantly
- **Real-time status** — see voice state, dependency health, active audio, and temp files
- **Voice testing** — test Prime (calm) and Dev (energetic) voice profiles from the panel
- **File-watch sync** — external changes to the voice flag are reflected immediately
- **Auto-mute in meetings** — detects Microsoft Teams calls and suppresses audio automatically
- **Terminal-immune audio** — voice playback survives terminal closure (detached with `&!`)
- **LaunchAgent support** — optional auto-start on login

## Requirements

- macOS 13 (Ventura) or later
- Xcode CommandLineTools — `xcode-select --install`
- Python 3 — `brew install python3` (or use system Python)
- edge-tts — `pip3 install edge-tts` (installed automatically by the install script)

## Install

```bash
git clone https://github.com/ekeng92/aeon-voice.git
cd aeon-voice
make install
```

Or run the install script directly:

```bash
bash scripts/install.sh
```

The installer will:
1. Verify all prerequisites
2. Compile the SwiftUI app (~60KB binary)
3. Install the `.app` bundle to `~/Applications/`
4. Install voice scripts to `~/.local/bin/`
5. Initialize the voice flag file
6. Optionally set up a LaunchAgent for auto-start

## Uninstall

```bash
make uninstall
```

Removes the app, voice scripts, LaunchAgent, and temp files. Your `~/.aeon-voice-enabled` preference is preserved.

## Usage

### Menu Bar App

Launch from `~/Applications/AEON Voice.app` or Spotlight. The waveform icon appears in your menu bar. Click it for the control panel.

### CLI

```bash
aeon-voice-toggle          # Toggle voice on/off
aeon-voice-status          # Show current state
aeon-voice-init            # Initialize or repair
aeon-voice-init on         # Force voice on
aeon-voice-init off        # Force voice off
aeon-prime-voice "Hello"   # Speak with Prime voice (Andrew)
aeon-dev-voice "Hello"     # Speak with Dev voice (Ava)
```

### Agent Integration

Agents check the flag file before speaking:

```bash
[[ "$(cat ~/.aeon-voice-enabled)" == "on" ]] && aeon-prime-voice "Task complete."
```

The flag file (`~/.aeon-voice-enabled`) is the single source of truth. The app watches it in real time — toggle from CLI and the menu bar updates instantly, and vice versa.

## Voice Profiles

| Profile | Voice | Engine | Style | Speed |
|---------|-------|--------|-------|-------|
| **Prime** | Andrew (en-US) | Neural TTS (edge-tts) | Calm, measured, steady | Normal |
| **Dev** | Ava (en-US) | Neural TTS (edge-tts) | Confident, expressive | +10% |

### Adding Custom Voices

Create a new script in `~/.local/bin/`:

```bash
#!/bin/zsh
source "$HOME/.local/bin/aeon-voice-common"
speak_edge_tts "en-US-JennyNeural" "+5%" "$1"
```

See [edge-tts voices](https://github.com/rany2/edge-tts#voices) for the full list of available neural voices.

## Architecture

```
┌─────────────────────────────────┐
│   macOS Menu Bar                │
│   [🔊] ← waveform icon         │
└─────────┬───────────────────────┘
          │ click
          ▼
┌─────────────────────────────────┐
│  SwiftUI Popover Panel          │
│  ┌───────────────────────────┐  │
│  │ ● VOICE ON                │  │
│  │ python3 ✓  edge-tts ✓    │  │
│  └───────────────────────────┘  │
│  [███ Toggle Voice ███████████] │
│  [■ Stop] [🧹 Clean]           │
│  [🔧 Init] [↻ Refresh]         │
│  ┌───────────────────────────┐  │
│  │ Test: [_______________]   │  │
│  │ [▶ Prime]  [▶ Dev]        │  │
│  └───────────────────────────┘  │
│  Activity log...                │
│  ───────────────────────────── │
│  Quit AEON Voice                │
└─────────────────────────────────┘
          │
          │ Process() calls
          ▼
┌─────────────────────────────────┐
│  ~/.local/bin/                  │
│  aeon-voice-common              │
│  aeon-prime-voice               │
│  aeon-dev-voice                 │
│  aeon-voice-toggle              │
│  aeon-voice-init                │
└─────────────────────────────────┘
          │
          │ detached subprocess (&!)
          ▼
┌─────────────────────────────────┐
│  python3 -m edge_tts            │
│  → generates .mp3 temp file     │
│  → afplay (macOS native audio)  │
│  → cleanup                      │
└─────────────────────────────────┘
```

## Building from Source

```bash
make build    # Compile with Swift Package Manager
make app      # Create .app bundle in build/
make run      # Build and launch
make clean    # Remove build artifacts
```

The entire app compiles with `swift build` — no Xcode project, no xcworkspace, no storyboards. Just Swift Package Manager and SwiftUI.

## How It Works

**Voice flag** — A single file (`~/.aeon-voice-enabled`) containing `on` or `off`. Every voice script checks this before speaking. The menu bar app watches it with `DispatchSource` for real-time sync.

**Detached audio** — Voice scripts use zsh's `&!` (background + disown) to fully detach the TTS-to-playback pipeline. The audio plays to completion even if the terminal that triggered it is closed.

**Teams auto-mute** — Before speaking, scripts check `pmset -g assertions` for Teams call indicators. Audio is suppressed during calls — no manual muting needed.

**Zero-dependency binary** — The menu bar app is pure SwiftUI compiled to a native ARM64 binary. No Python, no Tk, no Electron. The voice *scripts* need Python + edge-tts, but the *app* itself has zero runtime dependencies.

## License

MIT — see [LICENSE](LICENSE).
