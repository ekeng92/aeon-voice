# AEON Voice

Native macOS menu bar app for controlling neural text-to-speech voice output.

A ~350KB SwiftUI binary that lives in your menu bar. Click the waveform icon → popover panel with full voice control, settings, and testing. No Electron, no Python GUI, no runtime dependencies.

## Features

- **Menu bar native** — lives alongside Wi-Fi, Bluetooth, and battery. No dock icon, no window to manage
- **One-click toggle** — mute/unmute voice output instantly
- **Configurable voice** — choose from 9 neural voices (Andrew, Ava, Aria, Christopher, Eric, Guy, Jenny, Michelle, Steffan) via the Settings panel
- **Max character limit** — cap agent voice output length (200, 300, 500, 1000, or unlimited)
- **Auto-mute in meetings** — detects Microsoft Teams calls and suppresses audio automatically. Visible toggle in Settings, with live call indicator
- **Keep Awake** — prevent system sleep with one click (uses `caffeinate -s`, no sudo). Hover for tooltip explaining what it does
- **Voice testing** — preview any available voice from the panel before setting it as default
- **Real-time status** — see current voice, dependency health, active audio, and temp files at a glance
- **File-watch sync** — external changes to the voice flag are reflected immediately
- **Terminal-immune audio** — voice playback survives terminal closure (detached with `&!`)
- **LaunchAgent support** — optional auto-start on login
- **Accessible** — proper contrast ratios, VoiceOver labels, and native macOS tooltips

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
aeon-voice "Hello"             # Speak with configured default voice
aeon-voice-toggle              # Toggle voice on/off
aeon-voice-status              # Show current state
aeon-voice-init                # Initialize or repair
aeon-voice-init on             # Force voice on
aeon-voice-init off            # Force voice off
aeon-prime-voice "Hello"       # Speak with Prime voice (Andrew)
aeon-dev-voice "Hello"         # Speak with Dev voice (Ava)
```

### Agent Integration (VS Code Copilot)

The install script optionally sets up a **global Copilot instruction file** that teaches AI agents when and how to speak. This works with GitHub Copilot, Claude, and any IDE that supports VS Code instruction files.

**What it does**: Installs `~/.copilot/instructions/aeon-voice.instructions.md` — a user-level instruction file that applies to ALL your VS Code workspaces. When present, agents will:
- Speak aloud when they finish a task
- Speak when they're waiting for your input
- Use the voice configured in the AEON Voice menu bar app
- Check `~/.aeon-voice-enabled` before every voice call (so muting from the menu bar silences agents immediately)
- Respect the max character limit set in Settings
- Echo a `> 🔊` breadcrumb in chat so you can see which thread spoke

**Customize it**: The instruction file is yours. Open it in VS Code and edit:
- When agents voice (add/remove triggers)
- How verbose they are (short status vs. full sentences)
- Which workspaces it applies to (change the `applyTo` pattern)

**Add it later**: If you skipped during install, run:
```bash
mkdir -p ~/.copilot/instructions
cp examples/aeon-voice.instructions.md ~/.copilot/instructions/
```

**Remove it**: Delete `~/.copilot/instructions/aeon-voice.instructions.md` and agents stop speaking.

The flag file (`~/.aeon-voice-enabled`) is the runtime toggle. The instruction file is the behavioral contract. Together they give you full control — mute instantly from the menu bar, or reshape how agents speak by editing the instruction file.

## Settings

All settings are managed from the AEON Voice menu bar app and stored in `~/.aeon-voice-config.json`.

### Default Voice

Choose the neural voice agents use when speaking. Change it from the Settings panel or by editing the config file. The voice takes effect immediately — no restart needed.

### Available Voices

| Voice | Style | Speed |
|-------|-------|-------|
| **Andrew** (default) | Calm, measured | Normal |
| **Ava** | Confident, expressive | +10% |
| **Aria** | Professional, versatile | Normal |
| **Christopher** | Reliable, clear | Normal |
| **Eric** | Conversational, natural | Normal |
| **Guy** | Casual, friendly | Normal |
| **Jenny** | Friendly, warm | Normal |
| **Michelle** | Warm, engaging | Normal |
| **Steffan** | Authoritative, steady | Normal |

All voices use Microsoft's neural TTS engine via [edge-tts](https://github.com/rany2/edge-tts). See the edge-tts docs for the full list of available voices in other languages.

### Max Characters

Limits how many characters an agent can voice in a single message. Messages exceeding the limit are truncated before TTS generation. Options: 200, 300, **500** (default), 1000, or No Limit.

### Mute During Teams Calls

When enabled (default: on), voice output is automatically suppressed during Microsoft Teams calls. The app checks `pmset -g assertions` for Teams call indicators every 5 seconds. A phone icon appears in the status card and next to the toggle when a call is detected.

This is built to be extensible — future versions can add detection for Zoom, Google Meet, Slack Huddles, and other meeting services.

### Notifications

When enabled, a macOS notification appears whenever voice output fires. This is useful when you step away from your desk — you'll see the notification even if you don't hear the audio. Powered by `osascript`; no additional dependencies or app registration required.

Default: **off**. Enabling it from the Settings panel may prompt macOS to request notification permission for Script Editor on first use.

### Keep Awake (Caffeinate)

The coffee cup button prevents your Mac from sleeping — useful when you need background processes (like autonomous agents) to keep running with the lid closed. It uses macOS's built-in `caffeinate -s` command, which:

- Prevents system sleep while the app is running
- Requires no sudo or admin privileges
- Automatically stops when you quit the app or toggle it off
- Does NOT prevent the display from dimming

Hover over the button for a tooltip explaining what it does. The coffee cup icon appears in the status card when active.

## Voice Profiles (Legacy)

The `aeon-prime-voice` and `aeon-dev-voice` scripts are still installed for backward compatibility and direct CLI use. The `aeon-voice` command (used by agents) reads the configured default voice from the app settings.

| Script | Voice | Style |
|--------|-------|-------|
| `aeon-voice` | Configured default | Set in app |
| `aeon-prime-voice` | Andrew (en-US) | Calm, measured |
| `aeon-dev-voice` | Ava (en-US) | Confident, +10% |

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
│  │ Voice: Andrew             │  │
│  │ python3 ✓  edge-tts ✓    │  │
│  └───────────────────────────┘  │
│  [██ Voice On ██][☕ Keep Awake] │
│  ┌ SETTINGS ─────────────────┐  │
│  │ Default Voice: [Andrew ▾] │  │
│  │ Max Chars: [500 ▾]        │  │
│  │ ☑ Mute during Teams calls │  │
│  └───────────────────────────┘  │
│  ┌ VOICE TEST ───────────────┐  │
│  │ [___________________]     │  │
│  │ [Ava — Confident ▾] [▶]  │  │
│  └───────────────────────────┘  │
│  [■ Stop] [🧹 Clean]           │
│  [🔧 Init] [↻ Refresh]         │
│  Activity log...                │
│  Quit AEON Voice                │
└─────────────────────────────────┘
          │
          │ reads config + runs scripts
          ▼
┌─────────────────────────────────┐
│  ~/.aeon-voice-config.json      │  ← voice, max chars, auto-mute, notifications
│  ~/.aeon-voice-enabled          │  ← on/off flag
│  ~/.local/bin/                  │
│  aeon-voice (default, from cfg) │
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

**Config file** — Settings are stored in `~/.aeon-voice-config.json` (default voice, max characters, auto-mute preferences). The app writes this file when you change settings. Voice scripts read it on each invocation.

**Detached audio** — Voice scripts use zsh's `&!` (background + disown) to fully detach the TTS-to-playback pipeline. The audio plays to completion even if the terminal that triggered it is closed.

**Teams auto-mute** — The app polls `pmset -g assertions` every 5 seconds for Teams call indicators. When a call is detected and the toggle is enabled, voice scripts check the config and suppress audio. A phone icon appears in the UI.

**Voice testing** — The test panel calls `edge-tts` directly, bypassing the mute flag. This lets you preview voices even when voice output is muted.

**Zero-dependency binary** — The menu bar app is pure SwiftUI compiled to a native ARM64 binary. No Python, no Tk, no Electron. The voice *scripts* need Python + edge-tts, but the *app* itself has zero runtime dependencies.

## License

MIT — see [LICENSE](LICENSE).
