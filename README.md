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

One command:

```bash
curl -fsSL https://raw.githubusercontent.com/ekeng92/aeon-voice/main/scripts/remote-install.sh | bash
```

Or clone and install manually:

```bash
git clone https://github.com/ekeng92/aeon-voice.git
cd aeon-voice
make install
```

The installer will:
1. Verify all prerequisites
2. Compile the SwiftUI app (~60KB binary)
3. Install the `.app` bundle to `~/Applications/`
4. Install voice scripts to `~/.local/bin/`
5. Initialize the voice flag file
6. Optionally set up a LaunchAgent for auto-start
7. Optionally install VS Code Copilot integration (teaches agents to speak)

### Troubleshooting

**"AEON Voice.app is damaged"** — macOS Gatekeeper may flag unsigned apps. Fix:
```bash
xattr -cr ~/Applications/AEON\ Voice.app
```

**edge-tts install fails** — On newer macOS with system Python, you may need:
```bash
python3 -m pip install --user edge-tts
```

**Voices don't play** — Ensure `~/.local/bin` is in your PATH:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

## Dry Run (Safe Testing)

Test the full install without touching your real home directory:

```bash
git clone https://github.com/ekeng92/aeon-voice.git /tmp/aeon-voice-test
cd /tmp/aeon-voice-test
AEON_PREFIX=/tmp/aeon-test-home bash scripts/install.sh
```

This installs everything under `/tmp/aeon-test-home/` instead of `~/`. The app builds normally but scripts, flag file, and Copilot instructions go to the sandbox. Clean up with `rm -rf /tmp/aeon-test-home /tmp/aeon-voice-test`.

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

### Agent Integration (VS Code Copilot)

The install script optionally sets up a **global Copilot instruction file** that teaches AI agents when and how to speak. This works with GitHub Copilot, Claude, and any IDE that supports VS Code instruction files.

**What it does**: Installs `~/.copilot/instructions/aeon-voice.instructions.md` — a user-level instruction file that applies to ALL your VS Code workspaces. When present, agents will:
- Speak aloud when they finish a task
- Speak when they're waiting for your input
- Check `~/.aeon-voice-enabled` before every voice call (so muting from the menu bar silences agents immediately)
- Echo a `> 🔊` breadcrumb in chat so you can see which thread spoke

**Customize it**: The instruction file is yours. Open it in VS Code and edit:
- When agents voice (add/remove triggers)
- Which voice they use (swap voice profiles)
- How verbose they are (short status vs. full sentences)
- Which workspaces it applies to (change the `applyTo` pattern)

**Add it later**: If you skipped during install, run:
```bash
mkdir -p ~/.copilot/instructions
cp examples/aeon-voice.instructions.md ~/.copilot/instructions/
```

**Remove it**: Delete `~/.copilot/instructions/aeon-voice.instructions.md` and agents stop speaking.

The flag file (`~/.aeon-voice-enabled`) is the runtime toggle. The instruction file is the behavioral contract. Together they give you full control — mute instantly from the menu bar, or reshape how agents speak by editing the instruction file.

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
