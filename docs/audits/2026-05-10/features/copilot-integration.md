# Feature: Copilot Integration

> `examples/aeon-voice.instructions.md` (~80 lines)

## Purpose

A VS Code Copilot instruction file that teaches AI agents when and how to use AEON Voice for spoken output. Installed globally at `~/.copilot/instructions/aeon-voice.instructions.md`.

## What It Teaches Agents

1. **Voice Command**: `~/.local/bin/aeon-voice --session "<AgentMode> · <workspace>" --prompt "<truncated prompt>" "<message>"`
2. **When to Voice**: Done working, waiting for input
3. **How to Voice**: Check toggle file, echo in chat (`> 🔊`), run command via `run_in_terminal` async
4. **Rules**: No trailing `&`, auto-mute during meetings, max chars configured in app, first person conversational style

## Customization Points

- `applyTo` pattern in frontmatter (default: `**` = all files)
- When agents speak (triggers)
- Voice verbosity
- Workspace scope

## Integration Points

- Flag file: `~/.aeon-voice-enabled` (runtime toggle)
- Config file: `~/.aeon-voice-config.json` (voice, max chars, settings)
- Voice command: `~/.local/bin/aeon-voice` (the main CLI entry point)

## Known Limitations

- Instruction file is static — not auto-updated when the user changes settings
- No version tracking — old instruction files from prior installs may contain stale guidance
- The `--session` and `--prompt` flags are documented here but not supported by legacy `aeon-prime-voice`/`aeon-dev-voice` scripts
