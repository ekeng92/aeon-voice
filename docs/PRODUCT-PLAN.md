# Product Plan — AEON Voice / Agent Control for macOS

## Working Thesis

AEON Voice began as a way to hear when Copilot/agent work finishes, but it is becoming something broader:

> A native macOS control surface for local AI agent behavior.

Voice is the first wedge. The deeper value is giving humans simple, local controls for agent interruption, focus, environment readiness, and eventually scheduled/background work.

## Product Naming Exploration

### Current Name

**AEON Voice**

Pros:
- Strong internal identity
- Clear enough for the current feature
- Fits Eric's AEON ecosystem

Cons:
- Sounds personal/ecosystem-specific
- Too narrow if the app grows into scheduling, keep-awake, agent profiles, or local orchestration
- Less obvious to Copilot/Claude/Codex users outside the AEON framing

### Candidate Direction: Pilot Controls

**Pilot Controls** points subtly toward Copilot without using the trademark directly.

Pros:
- Broad enough for more than Copilot
- Natural aviation/control metaphor
- Communicates human-in-command
- Can contain voice, keep-awake, schedules, focus mode, and agent controls

Cons:
- Slightly bland/generic
- “Pilot” could imply the human is the pilot rather than the agent/copilot pairing
- May need a strong subtitle to clarify AI-agent purpose

Possible positioning:

> Pilot Controls — native macOS controls for AI agents.

### Other Candidate Names

- **Flight Deck** — strongest metaphor; broad, memorable, agent-control friendly
- **Agent Deck** — clear and practical, less poetic
- **Pilot Controls** — direct, accessible, trademark-safe-ish, but bland
- **Agent Intercom** — excellent for voice, too narrow for scheduling/control
- **Ground Control** — strong for orchestration/scheduling, less obvious for voice
- **Callsign** — stylish for voice identity, too narrow for control panel
- **Control Surface** — accurate, but technical/bland

## Naming Recommendation

If the product remains mostly voice:

> Agent Intercom

If the product expands into broader macOS controls:

> Flight Deck or Pilot Controls

Recommended current public framing:

> **Pilot Controls** — native macOS controls for AI agents.

Keep **AEON Voice** as either:
- the original/internal name, or
- the name of the voice module inside Pilot Controls.

## Core User Problem

Long-running agent tasks finish silently or with easy-to-miss text output. Users start work, switch context, and forget to check back.

The first solution is voice output:

- Agent completes task
- Agent speaks a short completion note
- Human knows to return immediately

But voice creates interruption risk:

- Audio during Teams/Zoom meetings is embarrassing
- Agents can be too verbose
- Users need fast mute/control

So the real problem space becomes:

> How do we let local AI agents communicate and operate without surprising, embarrassing, or distracting the human?

## Current Feature Set

### Voice Control

- Global voice flag: `~/.aeon-voice-enabled`
- CLI voice scripts installed to `~/.local/bin`
- Menu bar toggle for voice on/off
- Voice output survives terminal closure
- Max character limit for spoken output

### Voice Quality

- Realistic neural voices through `edge-tts`
- Selectable default voice
- Per-voice preview
- Test all voices sequentially

### Meeting Awareness

- Detects Microsoft Teams call state
- Automatically mutes voice during Teams calls
- Shows call/mute status in the app

### Agent Integration

- Installs global VS Code Copilot instruction file
- Teaches agents when/how to speak
- Agents check the voice flag before speaking
- Intended to work for Copilot and other agents that honor instruction files/local commands

### Local Machine Readiness

- Keep Awake control using macOS `caffeinate`
- Helps long-running local agent tasks continue when the Mac might sleep

## Product Boundary Question

Some features are clearly agent-voice related:

- Speak on task completion
- Voice toggle
- Voice picker
- Meeting mute
- Max spoken length

Some features are agent-environment related:

- Keep Awake
- Scheduled tasks
- Run history
- Agent health checks
- Workspace/task profiles

This is the key product decision:

### Option A — Stay Narrow

Build a polished voice utility for coding agents.

Pros:
- Easier to explain
- Faster to ship
- Lower complexity
- Clear adoption path

Cons:
- Leaves broader agent-control opportunities unexplored
- Keep Awake already stretches the product boundary

### Option B — Expand Carefully

Position as a macOS control panel for AI agents, with voice as the first module.

Pros:
- Better fit for Keep Awake, schedules, profiles, meeting awareness
- More defensible product shape
- Can support Copilot, Claude, Codex, OpenCode, etc.

Cons:
- More complexity
- Risk of becoming vague
- Requires disciplined roadmap/module boundaries

## Recommended Strategy

Use a staged product ladder:

1. **Voice utility** — solve completion awareness and meeting-safe voice.
2. **Agent control panel** — add environment and behavior controls.
3. **Local agent scheduler** — add scheduled/background CLI agent runs only after the core controls are polished.

Do not jump straight to full orchestration. Keep the current install-simple magic.

## Roadmap

### Milestone 0 — Stabilize Current App

Goal: Current one-command install works reliably on any teammate Mac.

Tasks:
- [x] Fix squished popover sizing
- [x] Fix GUI Python/edge-tts detection
- [x] Add voice preview logging
- [x] Add Test All voices
- [ ] Validate clean install on fresh Mac/user account
- [ ] Validate Apple Silicon + Intel if available
- [ ] Validate Teams meeting mute behavior
- [ ] Add README troubleshooting for PATH vs app behavior
- [ ] Add uninstall/reinstall smoke test

Exit criteria:
- One-line install succeeds
- App opens at correct size
- Play and All work
- Agents can call `aeon-voice`
- Voice mutes during Teams calls


### Feature Candidate — Persistent Notifications

Problem: voice is ephemeral. If the developer steps away, they can miss the spoken completion/follow-up message.

Feature: optionally show a macOS notification when an agent voice event indicates task completion, failure, or follow-up needed.

Recommended scope:
- User setting: notifications on/off
- Trigger only for meaningful task events, not every voice line
- Notification body uses the same short message passed to voice
- Future scheduler integration can attach run/task IDs

Rationale: this directly strengthens the original AEON Voice use case: never lose track of long-running agent work.

### Milestone 1 — Team-Ready Voice Release

Goal: Share with team as a useful Copilot/agent voice utility.

Tasks:
- [ ] Decide public name for v1
- [ ] Polish README for non-AEON users
- [ ] Add screenshots/GIF
- [ ] Add “What it installs” security section
- [ ] Add “How to remove” section
- [ ] Add Copilot instructions explanation
- [ ] Add privacy note: local scripts/config only; no telemetry
- [ ] Add known limitations
- [ ] Tag release `v0.1.0`

Exit criteria:
- A teammate can understand and install without extra explanation
- User understands what files are modified
- User knows how to mute, quit, uninstall, and troubleshoot

### Milestone 2 — Agent Control Panel

Goal: Expand from voice-only into simple behavior/environment controls without losing clarity.

Candidate modules:

#### Voice Module
- Voice on/off
- Voice selection
- Test voice/test all
- Max spoken length
- Meeting auto-mute

#### Focus / Interruption Module
- Quiet hours
- Meeting-aware suppression
- “Only speak on completion/error” mode
- “Chat breadcrumb only” mode

#### Environment Module
- Keep Awake toggle
- Show whether caffeinate is active
- Maybe workspace-aware keep-awake hints

#### Integration Module
- Install/update/remove Copilot instruction file
- Support multiple instruction templates:
  - Completion-only
  - Completion + blockers
  - Verbose voice mode
  - Silent mode

Exit criteria:
- App still feels simple
- Features are grouped into obvious modules
- No scheduler yet unless strongly validated

### Milestone 3 — Scheduled Agent Tasks Research

Goal: Determine whether scheduling CLI agent work belongs in this product.

Research questions:
- What can Copilot CLI safely run headlessly today?
- Does Copilot CLI support non-interactive prompts reliably?
- How does auth/session state work?
- Can output be captured and summarized?
- How should permissions be controlled?
- What happens if the Mac sleeps or network drops?
- Should scheduling be LaunchAgent-based, cron-like, or app-managed?

Prototype tasks:
- One-shot scheduled prompt in a selected workspace
- Daily git summary
- “Review uncommitted changes at 4pm”
- Notification/voice on completion

Exit criteria:
- Clear proof that scheduled CLI agent runs are useful and safe
- Permission model is understandable
- Failure modes are visible

### Milestone 4 — Local Agent Scheduler

Goal: Add scheduled tasks if Milestone 3 validates the idea.

Features:
- Task name
- Workspace path
- Agent command/profile
- Prompt
- Schedule
- Last run / next run
- Output location
- Voice/notification on completion
- Enable/disable task

Important constraints:
- No destructive commands by default
- Clear logs
- Easy pause-all
- No hidden automation surprises

## Key Design Principles

1. **Human remains in control**
   - Fast mute
   - Visible state
   - No surprise speech during meetings

2. **Native and lightweight**
   - Swift menu bar app
   - No Electron
   - Minimal dependencies

3. **Durable simple contracts**
   - Voice state in a file
   - Config in JSON
   - Scripts in `~/.local/bin`
   - Instruction files users can inspect/edit

4. **Works across agents where possible**
   - Copilot first because that is the motivating use case
   - Avoid hard trademark naming
   - Keep CLI/script interface generic

5. **One-command install remains sacred**
   - The magic is important
   - Expansion should not make setup complicated

## Open Questions

- Should quitting the app mute voice?
  - Recommendation: no. Add “Quit and Mute” instead.

- Is Keep Awake part of this product?
  - Recommendation: yes if product is broader than voice; no if v1 is voice-only.

- Is this Copilot-specific?
  - Recommendation: market as agent-focused, with Copilot as the primary integration.

- Is scheduling too much?
  - Recommendation: research/prototype later; do not put in the first team-facing release.

- Best name?
  - Recommendation: decide between **Pilot Controls** and **Flight Deck** based on target audience.

## Suggested Team Pitch

I built a small native macOS menu bar app for AI agent voice output.

The original problem was simple: I wanted my Copilot agent to speak when a long-running task finished, because otherwise I would forget to check back until much later.

That turned into a more complete control surface:

- voice output for agent completion/status
- realistic neural voices
- selectable voice profiles with previews
- global mute/unmute from the menu bar
- max spoken length so agents do not ramble out loud
- automatic mute during Microsoft Teams calls
- a Keep Awake toggle for long-running local agent work
- one-command install

The current implementation is intentionally lightweight: a native Swift menu bar app plus local shell scripts. It installs globally enough that Copilot/agent instructions can call the voice command from any workspace.

I’m exploring whether this should stay as a focused “agent voice” utility or grow into a broader macOS control panel for local AI agents.
