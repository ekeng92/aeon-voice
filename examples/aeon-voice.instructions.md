---
applyTo: "**"
---

# AEON Voice — Agent Voice Protocol

> This file was installed by AEON Voice (https://github.com/ekeng92/aeon-voice).
> It teaches AI agents in VS Code how and when to speak using neural TTS.
> Edit this file to customize voice behavior. Delete it to disable agent voice.
>
> Location: ~/.copilot/instructions/aeon-voice.instructions.md
> Scope: Applies to ALL workspaces in VS Code (user-level instruction file)

## Voice Commands

Agents have access to these voice scripts (installed at ~/.local/bin/):

| Voice | Style | Command |
|-------|-------|---------|
| **Prime** (default) | Calm, measured, steady | `~/.local/bin/aeon-prime-voice "<message>"` |
| **Dev** | Confident, expressive, quick | `~/.local/bin/aeon-dev-voice "<message>"` |

## When to Voice

Agents MUST voice in these situations:
1. **Done working** — finished the requested task or a meaningful chunk of work
2. **Waiting for input** — stopped and need the user to respond, decide, or unblock

## How to Voice

Follow these steps every time a voice trigger occurs:

1. **Check the toggle**: Read `~/.aeon-voice-enabled`. If the contents are NOT exactly `on`, skip the terminal voice command — but still output the chat echo (step 2)
2. **Echo in chat**: Output the message text as a quoted line in the chat response:
   `> 🔊 "Done. Built the component and all tests pass."`
3. **Run the voice command** (only if toggle is `on`):
   ```bash
   [[ "$(cat ~/.aeon-voice-enabled 2>/dev/null)" == "on" ]] && ~/.local/bin/aeon-prime-voice "Done. Built the component and all tests pass."
   ```
4. **Terminal pattern**: Use `run_in_terminal` with `mode=async` and `timeout=5000`. The script detaches playback internally and returns instantly

## Rules

- **Do NOT add trailing `&`** to voice commands — the scripts handle background execution with `&!` (zsh disown)
- **Auto-mute during meetings**: Scripts detect Microsoft Teams calls via `pmset` and suppress audio automatically. No agent action needed
- **Voice length**: First person, conversational. Short status lines are fine ("Done, tests pass.") but don't artificially compress — if the context needs a couple sentences, speak them naturally
- **The menu bar app controls mute state**: Users toggle voice on/off from the AEON Voice menu bar app. The flag file (`~/.aeon-voice-enabled`) is the shared contract between the app and agents

## Customization Guide

### Change when agents speak
Edit the "When to Voice" section above. For example, you could add:
- Voice on errors or test failures
- Voice at the start of each task
- Voice only when explicitly asked

### Change the voice style
The voice scripts use Microsoft's neural TTS voices via edge-tts. To use a
different voice, create a new script in `~/.local/bin/`:

```bash
#!/bin/zsh
source "$HOME/.local/bin/aeon-voice-common"
speak_edge_tts "en-US-JennyNeural" "+5%" "$1"
```

Popular voices: AndrewNeural, AvaNeural, JennyNeural, GuyNeural, AriaNeural.
Full list: https://github.com/rany2/edge-tts#voices

Then add it to the voice table above and reference it in your agent instructions.

### Limit voice to specific workspaces
Change `applyTo: "**"` in the frontmatter to a specific glob pattern, or move
this file from `~/.copilot/instructions/` into a specific project's
`.github/instructions/` folder instead.

### Disable voice entirely
Either mute from the menu bar app (agents see the flag and stay silent) or
delete this file to remove agent voice awareness completely.
