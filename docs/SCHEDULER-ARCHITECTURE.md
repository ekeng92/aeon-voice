# Scheduler Architecture — Agent Project Manager for Local CLI Agents

## Status

Draft architecture produced from the first successful Copilot ACP worker task and reviewed by AEON Watch.

Validated smoke test:

```bash
acpx --cwd ~/.openclaw/workspace --format quiet --timeout 60 copilot exec "Smoke test only. Reply with exactly: COPILOT_ACP_OK"
```

Result: `COPILOT_ACP_OK`

## Core Thesis

The scheduler is not just cron for prompts.

It is a local agent operations layer where Watch acts as project manager:

1. scope the work,
2. launch Copilot/agent workers,
3. capture output,
4. review results,
5. request follow-up when needed,
6. escalate only meaningful decisions to Eric.

## Three-Layer Model

```text
Layer 3 — UI / Control Surface
Swift menu bar app: task editor, run history, enable/disable, pause all, escalations

Layer 2 — Project Manager
AEON Watch / scheduler logic: scopes tasks, launches agents, reviews output, follows up, escalates

Layer 1 — Agent Execution
Copilot CLI / ACPX: performs actual research, coding, review, docs, or diagnostics work
```

MVP recommendation: prove Layers 1 and 2 before building a full Swift scheduler UI.

## MVP Components

- **Task store** — persists task definitions and run history
- **Runner** — invokes ACPX/Copilot with explicit workspace, prompt, timeout, and permission mode
- **Log store** — captures raw output per run
- **Reviewer** — evaluates output and decides accepted / follow-up / escalate
- **Notifier** — uses voice/macOS notification only for completion, failure, or decision points
- **Pause-all control** — stops future scheduled runs immediately

## Proposed Data Model

### Task

```json
{
  "id": "uuid",
  "name": "Daily repo summary",
  "workspace": "/Users/erickeng/Projects/example",
  "prompt": "Summarize recent git changes and open risks.",
  "schedule": "0 8 * * *",
  "mode": "read-only",
  "timeoutSeconds": 300,
  "enabled": true,
  "createdAt": "iso timestamp",
  "updatedAt": "iso timestamp"
}
```

### Run

```json
{
  "id": "uuid",
  "taskId": "uuid",
  "triggeredBy": "manual|schedule",
  "status": "pending|running|review|done|failed|escalated|cancelled",
  "startedAt": "iso timestamp",
  "finishedAt": "iso timestamp",
  "exitCode": 0,
  "outputPath": "~/.aeon-scheduler/runs/<run-id>/raw-output.md",
  "reviewerVerdict": "accepted|follow-up|escalated",
  "reviewerNotes": "short summary",
  "followUpCount": 0
}
```

### Escalation

```json
{
  "id": "uuid",
  "runId": "uuid",
  "question": "What decision does Eric need to make?",
  "raisedAt": "iso timestamp",
  "resolvedAt": null,
  "resolution": null
}
```

## Run Lifecycle

```text
scheduled/manual trigger
  ↓
pending
  ↓
pre-flight checks
  - Copilot auth valid
  - workspace exists
  - pause-all not active
  - no overlapping run for same task
  - timeout configured
  ↓
running
  - invoke acpx/copilot
  - capture stdout/stderr
  - enforce timeout
  ↓
review
  - Watch/reviewer reads output
  - classify result
  ↓
one of:
  - accepted → done + concise update
  - follow-up → run one follow-up prompt, then review again
  - escalated → ask Eric for decision
  - failed → log + notify if meaningful
```

## Reviewer Workflow

The reviewer receives:

- task name
- workspace
- original prompt
- raw agent output
- constraints / expected result

Reviewer returns structured JSON:

```json
{
  "verdict": "accepted|follow-up|escalate",
  "summary": "1-2 sentence human-readable summary",
  "followUpPrompt": "next prompt if needed",
  "escalationQuestion": "question for Eric if needed"
}
```

Rules:

- Use `accepted` when output satisfies the task.
- Use `follow-up` when the agent can fix/complete the task without Eric.
- Use `escalate` only when a real human decision is required.
- Cap follow-ups at 2 to prevent loops.

## Guardrails

### Permission Modes

#### Read-only

Default. Agent may inspect, summarize, plan, and propose. It should not modify files.

#### Write-approved

Future mode. Agent may edit files only when the run is explicitly approved.

### Prohibited by Default

- `git push`
- force reset
- deletes/destructive commands
- package publish
- production deploys
- credential exposure
- irreversible external writes

### Pause All

A single global pause state should stop future scheduled runs. Existing runs may finish unless explicitly cancelled.

### Output Limits

Cap raw output size per run to avoid runaway logs.

### Auth Failures

If Copilot auth fails repeatedly, auto-disable affected tasks and surface a single useful alert.

## First Manual MVP

Before Swift scheduler UI, run this as a Watch-managed workflow:

1. Eric gives objective.
2. Watch creates a scoped brief.
3. Watch launches Copilot through ACPX.
4. Watch reviews output.
5. Watch follows up or escalates.
6. Watch writes durable artifact / update.

This proves the executive/project-manager pattern before adding product complexity.

## Candidate Pilot Tasks

Good first tasks are bounded, useful, and low-risk:

- README polish for team-ready AEON Voice release
- installer smoke-test script proposal
- Copilot CLI capability matrix
- scheduler data model refinement
- architecture review of Pilot Controls vs separate scheduler app

Avoid initially:

- broad refactors
- production code edits
- anything requiring credentials or external writes
- anything that needs repeated human approvals

## Roadmap

### Phase 0 — Manual Supervised Runs

Goal: prove Watch can manage Copilot workers effectively.

- Run 3–5 bounded tasks
- Capture raw outputs
- Review quality
- Request at least one follow-up
- Exercise one escalation path manually
- Identify failure modes

Exit criteria: Watch can reliably scope, launch, review, and follow up on agent work.

### Phase 1 — Runner Wrapper

Goal: make launches repeatable.

- wrapper script or small CLI for ACPX invocation
- explicit workspace/prompt/timeout
- run folder creation
- output capture
- status file
- failure handling

Exit criteria: one command creates a durable run record.

### Phase 2 — Scheduler Core

Goal: scheduled autonomous runs without polished UI.

- task definitions
- run history
- schedule evaluation
- pause-all
- notifications/voice
- auth checks

Exit criteria: at least two scheduled tasks run successfully over a day without manual intervention.

### Phase 3 — Swift Control Surface

Goal: human-friendly management.

- task list
- add/edit task
- run now
- enable/disable
- pause all
- run history
- escalation badge
- escalation resolution

Exit criteria: Eric can manage scheduled agent work without touching CLI.

### Phase 4 — Write-Capable Workflows

Goal: safe expansion from read-only/research to implementation work.

- explicit write-approved mode
- per-run confirmation
- diff review
- tests/build gates
- no push/deploy by default

Exit criteria: agent can implement bounded changes and Watch can verify before Eric reviews milestones.

## Current Recommendation

Make scheduler / agent project management the primary exploration track.

Keep AEON Voice / Pilot Controls on a parallel release track, but do not let voice polish block the scheduler proof-of-concept.

The next concrete step is to run 3–5 real Copilot worker tasks under Watch supervision and evaluate whether the PM loop feels useful enough to productize.
