# Scheduler Spike — Agent Project Manager for Local CLI Agents

## Executive Summary

We verified that AEON Watch can invoke GitHub Copilot CLI through OpenClaw's ACPX bridge from Eric's Mac.

Smoke test:

```bash
acpx --cwd ~/.openclaw/workspace --format quiet --timeout 60 copilot exec "Smoke test only. Reply with exactly: COPILOT_ACP_OK"
```

Result:

```text
COPILOT_ACP_OK
```

This validates the core premise: Watch can act as a project-manager layer that launches Copilot tasks, reviews outputs, asks follow-up questions, and reports only milestones/blockers back to Eric.

## Strategic Shift

AEON Voice / Pilot Controls remains a parallel product track. It is well-defined enough to keep polishing toward release.

The main strategic exploration now becomes:

> Can a local macOS scheduler/control app launch, supervise, and review agent work through Copilot CLI/ACP?

## Product Thesis

A human with many ideas needs more than a chatbot. He needs an executive system that can:

1. capture ideas,
2. turn them into scoped work,
3. launch agent workers,
4. review their output,
5. request follow-up,
6. track progress,
7. escalate only meaningful decisions.

The scheduler is not just cron for prompts. It is a local agent operations layer.

## Validated Capability

### Installed/Available

- `copilot` CLI exists at `/opt/homebrew/bin/copilot`
- GitHub auth is active for `ekeng92`
- OpenClaw ACPX bridge installed plugin-locally at:
  - `/opt/homebrew/lib/node_modules/openclaw/dist/extensions/acpx/node_modules/.bin/acpx`
- ACPX version: `0.6.1`
- Copilot ACP one-shot task succeeded

### Implication

We can fire off Copilot tasks from Watch without requiring Eric to manually open VS Code, as long as:

- Copilot CLI auth remains valid
- task scope is safe/clear
- permission/approval behavior is handled intentionally
- outputs are captured and reviewed

## Important Distinction

There are three layers:

### 1. Agent Execution

Copilot CLI / ACP does the actual work.

### 2. Project Management

AEON Watch scopes tasks, launches agents, reviews output, asks follow-up, and updates Eric.

### 3. Product UI / Scheduler

Future Swift app exposes this as a human-friendly control surface:

- scheduled prompts
- workspace selection
- task templates
- run history
- enable/disable
- notifications/voice
- pause all

The first spike should focus on layers 1 and 2 before building layer 3.

## Initial Use Cases

### Immediate Project Manager Use Cases

- Ask Copilot to inspect a repo and produce a plan
- Ask Copilot to implement a scoped feature
- Ask Copilot to review uncommitted changes
- Ask Copilot to summarize recent work
- Ask Copilot to diagnose a failing test
- Ask Copilot to draft docs based on code

### Scheduler Use Cases

- Daily repo status summary
- End-of-day branch/worktree review
- Morning issue triage
- Scheduled dependency/security check
- Periodic stale TODO scan
- Nightly docs refresh proposal

## Guardrails

Scheduler/PM automation must not become surprising or dangerous.

Required controls:

- Explicit workspace path
- Clear prompt/task objective
- Read-only vs write-capable mode
- Approval model for writes
- Output log per run
- Easy cancel/pause
- No destructive commands by default
- Human milestone review before major changes

## MVP Without Swift UI

Before building scheduler UI, prove the workflow using Watch + ACPX directly.

### MVP Flow

1. Eric gives high-level objective.
2. Watch converts it into a scoped task brief.
3. Watch launches Copilot via ACPX.
4. Copilot returns output/diff/plan.
5. Watch reviews the output.
6. Watch either:
   - accepts and reports milestone,
   - asks Copilot for follow-up,
   - or escalates a decision to Eric.

### First Real Pilot Task Criteria

Pick a task that is:

- useful,
- bounded,
- low risk,
- reviewable,
- preferably read-only or docs-only.

Good candidates:

- AEON Voice README polish for team release
- Scheduler architecture brief
- Smoke-test script for AEON Voice installer
- Copilot CLI capability matrix

## Recommended First Task

Launch Copilot to draft a technical architecture proposal for the scheduler/control-plane concept, using this repo as context.

Why:

- Read-only/docs-first
- Directly advances the scheduler product
- Tests Copilot as a heavy-lifting research/planning worker
- Easy for Watch to review

Prompt shape:

```text
You are helping design a macOS menu bar app that schedules and supervises local AI agent tasks through Copilot CLI/ACP. Read docs/PRODUCT-PLAN.md and docs/SCHEDULER-SPIKE.md. Produce docs/SCHEDULER-ARCHITECTURE.md with a practical MVP architecture, data model, run lifecycle, guardrails, and milestone roadmap. Do not modify code.
```

## Open Questions

- Can Copilot CLI safely run longer non-interactive tasks without supervision?
- How does it handle tool/write permissions through ACP?
- Should Watch use one persistent Copilot session per project or one-shot tasks?
- What is the best output format for review?
- Should the eventual scheduler be built into Pilot Controls or a separate product?
- Should scheduled runs use LaunchAgent, cron-like storage, or OpenClaw cron/taskflow?

## Current Recommendation

Proceed with scheduler as the main strategic exploration, but keep the first phase as a CLI/PM workflow before adding Swift UI.

AEON Voice should continue as a parallel release/stabilization track.
