# Copilot Execution Plan — Model Routing, Context, and ChatKey Integration

## Purpose

This document defines how AEON Watch should launch and supervise Copilot CLI worker tasks so that they use the right model, receive the right context, and benefit from ChatKey skills/customizations where appropriate.

This is the operational plan for Watch acting as project manager over Copilot workers.

## Verified Capabilities

### Copilot CLI

Installed:

```text
/opt/homebrew/bin/copilot
GitHub Copilot CLI 1.0.34
```

### ACPX Bridge

Installed plugin-locally:

```text
/opt/homebrew/lib/node_modules/openclaw/dist/extensions/acpx/node_modules/.bin/acpx
version 0.6.1
```

### Smoke Tests

Default Copilot ACP execution succeeded:

```text
COPILOT_ACP_OK
```

Explicit model routing succeeded:

```bash
acpx --cwd ~/.openclaw/workspace --format quiet --timeout 90 --model claude-sonnet-4.6 copilot exec "..."
```

Result:

```text
SONNET_46_OK
```

This confirms Watch can specify Copilot model selection through ACPX.

## Available Copilot CLI Models

From local `copilot help config`, current supported model IDs include:

- `claude-sonnet-4.6`
- `claude-sonnet-4.5`
- `claude-haiku-4.5`
- `claude-opus-4.7`
- `claude-opus-4.6`
- `claude-opus-4.6-fast`
- `claude-opus-4.5`
- `claude-sonnet-4`
- `gpt-5.5`
- `gpt-5.4`
- `gpt-5.3-codex`
- `gpt-5.2-codex`
- `gpt-5.2`
- `gpt-5.1`
- `gpt-5.4-mini`
- `gpt-5-mini`
- `gpt-4.1`

GitHub docs for Anthropic Claude coding agent also list:

- Auto
- Claude Opus 4.5
- Claude Opus 4.6
- Claude Opus 4.7
- Claude Sonnet 4.5
- Claude Sonnet 4.6

## Model Routing Policy

Watch should select models intentionally per task type, not rely blindly on default.

### Default Worker Model

**Use `claude-sonnet-4.6` for most Copilot worker tasks.**

Best fit:

- coding implementation
- repo exploration
- docs improvement
- moderate architecture work
- task planning
- follow-up fixes

Reasoning:

- Strong coding/reasoning balance
- Less costly/heavy than Opus
- Verified available through ACPX smoke test
- Good default for high-throughput worker execution

### Deep Architecture / High-Stakes Review

**Use `claude-opus-4.6` or `claude-opus-4.7`.**

Best fit:

- product architecture
- strategic technical design
- adversarial review
- complex tradeoff analysis
- refactor planning across many files
- final review before major milestones

Policy:

- Prefer `claude-opus-4.6` for deep strategic/review work.
- Consider `claude-opus-4.7` for the highest-stakes or most ambiguous work if available and quota allows.
- Do not use Opus for routine tasks.

### Fast / Low-Stakes Tasks

**Use `claude-haiku-4.5` or `gpt-5.4-mini`.**

Best fit:

- quick summaries
- formatting cleanup
- simple inventory tasks
- low-risk extraction
- first-pass classification

### OpenAI/Codex-Oriented Implementation

**Use `gpt-5.3-codex` or `gpt-5.2-codex` when the task is heavily code-edit/agent-loop oriented and Sonnet underperforms.**

Best fit:

- implementation-heavy coding
- test-fix loops
- codebase mechanical edits
- tasks where Codex-family behavior is known to be strong

Policy:

- Sonnet 4.6 remains default.
- Escalate to Codex model if a Sonnet run produces weak implementation output or gets stuck in planning.

### Auto Mode

Use Copilot Auto only when rate limits or availability become a problem.

Do not use Auto as the default for supervised project-manager runs because Watch should know and record which model was used.

## Reasoning Effort Policy

Copilot CLI supports:

```text
--effort low|medium|high|xhigh
```

Recommended defaults:

- `low` — trivial summaries, extraction, formatting
- `medium` — normal implementation/docs tasks
- `high` — architecture, debugging, multi-file reasoning
- `xhigh` — only for difficult strategic/review tasks where extra latency/cost is justified

Default supervised worker run:

```text
--model claude-sonnet-4.6 --effort medium
```

Deep review run:

```text
--model claude-opus-4.6 --effort high
```

## Context Strategy

The biggest risk is launching a capable model with weak context. Watch owns context packaging.

### Context Must Include

Every worker task brief should include:

1. **Objective** — what result is needed
2. **Workspace** — exact repo/path
3. **Mode** — read-only, plan-only, write-approved, etc.
4. **Relevant files** — explicit files to read first
5. **Project conventions** — where instructions live
6. **Acceptance criteria** — what done means
7. **Guardrails** — what not to do
8. **Output format** — markdown, JSON, patch summary, etc.
9. **Escalation conditions** — when to stop and ask

### Workspace Context

Use `--cwd <repo>` to set the primary workspace.

Use Copilot's `--add-dir <directory>` when a task needs additional context from ChatKey or another repo.

Example:

```bash
copilot \
  --model claude-sonnet-4.6 \
  --effort medium \
  --add-dir /Users/erickeng/Projects/chatkey \
  --prompt "..."
```

Through ACPX:

```bash
acpx \
  --cwd /Users/erickeng/Projects/aeon-voice \
  --model claude-sonnet-4.6 \
  --timeout 180 \
  --format quiet \
  copilot exec "..."
```

Note: ACPX currently handles the core execution path. If a run needs extra `copilot` flags that ACPX does not expose, Watch may use direct `copilot -p` as a fallback.

### ChatKey Context

ChatKey is the source of Eric's agent identities, skills, prompts, and customizations.

Useful ChatKey paths:

- `/Users/erickeng/Projects/chatkey/.github/copilot-instructions.md`
- `/Users/erickeng/Projects/chatkey/.github/instructions/`
- `/Users/erickeng/Projects/chatkey/.github/agents/`
- `/Users/erickeng/Projects/chatkey/.github/prompts/`
- `/Users/erickeng/Projects/chatkey/.github/skills/`
- `/Users/erickeng/Projects/chatkey/aeons/dev/PORTABLE.md`
- `/Users/erickeng/Projects/chatkey/aeons/prime/PORTABLE.md`
- `/Users/erickeng/Projects/chatkey/learnings/aeon-dev-learnings.md`

Important distinction:

- If Copilot runs with `--cwd` inside ChatKey, repo instructions load naturally.
- If Copilot runs in another repo, ChatKey may be available via `--add-dir`, but the worker still needs explicit instruction to read the relevant ChatKey files.

Therefore Watch should not assume ChatKey customizations automatically apply to every external repo run.

## ChatKey Integration Plan

### Phase 1 — Manual Context Injection

For each supervised worker run, Watch includes a `Context Pack` section in the prompt.

Example:

```text
Context Pack:
- Primary repo: /Users/erickeng/Projects/aeon-voice
- Additional context repo: /Users/erickeng/Projects/chatkey
- Read these first if relevant:
  - /Users/erickeng/Projects/chatkey/.github/copilot-instructions.md
  - /Users/erickeng/Projects/chatkey/aeons/dev/PORTABLE.md
  - /Users/erickeng/Projects/chatkey/learnings/aeon-dev-learnings.md
```

Use this immediately. It is simple and reliable.

### Phase 2 — Reusable Worker Brief Templates

Create task templates that automatically include the right ChatKey pointers.

Candidate templates:

- `docs/worker-briefs/implementation.md`
- `docs/worker-briefs/architecture-review.md`
- `docs/worker-briefs/research.md`
- `docs/worker-briefs/readme-polish.md`
- `docs/worker-briefs/code-review.md`

Each template defines:

- model choice
- effort level
- context files
- permissions
- expected output
- review criteria

### Phase 3 — Context Pack Generator

Build a small script/CLI that produces a prompt-ready context pack.

Inputs:

- task type
- repo path
- mode
- optional files

Output:

- complete worker prompt
- model recommendation
- command to run
- run metadata

Possible command:

```bash
aeon-worker-brief --type architecture --repo ~/Projects/aeon-voice --chatkey
```

### Phase 4 — Scheduler Integration

Scheduler tasks should store:

- model
- effort
- workspace
- additional dirs
- context files
- prompt template
- permission mode

This makes model/context selection explicit and auditable per scheduled task.

## Execution Modes

### Read-Only Research / Planning

Use for most early scheduler work.

Command pattern:

```bash
acpx \
  --cwd <repo> \
  --model claude-sonnet-4.6 \
  --timeout 180 \
  --format quiet \
  --approve-reads \
  --non-interactive-permissions fail \
  copilot exec "<brief>"
```

Prompt guardrail:

```text
Do not modify files. Read and report only.
```

### Write-Capable Implementation

Only after explicit approval or when Eric delegates that mode.

Command pattern may require direct Copilot CLI or ACPX with appropriate permissions.

Guardrails:

- no push
- no force reset
- no destructive commands
- run tests/build where applicable
- summarize diff

### Reviewer Pass

Use a stronger or different model than the worker when quality matters.

Recommended:

- Worker: `claude-sonnet-4.6`
- Reviewer: `claude-opus-4.6` or `gpt-5.5`

Reviewer should receive:

- original brief
- worker output
- repo state/diff if relevant
- acceptance criteria

## Watch's Operating Procedure

For every Copilot worker task:

1. Classify task type.
2. Select model and effort using routing policy.
3. Build context pack.
4. Choose execution mode.
5. Launch worker.
6. Save raw output.
7. Review output independently.
8. Decide:
   - accept,
   - ask follow-up,
   - escalate to Eric,
   - or rerun with a better model/context.
9. Update durable artifact or task status.
10. Report only milestone-level results to Eric.

## Immediate Next Steps

1. Create `docs/worker-briefs/` with reusable prompt templates.
2. Run one task with explicit `claude-sonnet-4.6` + ChatKey context pack.
3. Run one reviewer pass with Opus for comparison if quota allows.
4. Record model/output quality observations in this document.
5. Add model/context fields to the scheduler data model.

## Open Questions

- Which Copilot models are actually available under each GitHub account/subscription at runtime?
- Does ACPX expose all Copilot flags we need, especially `--add-dir` and `--allow-tool`?
- Should Watch prefer ACPX for session orchestration and direct `copilot -p` for advanced flags?
- Can ChatKey agents be selected via `--agent` outside the ChatKey repo?
- Should worker prompts load AEON Dev, AEON Prime, or a neutral product/engineering persona depending on task?

## Current Recommendation

Use this default stack for near-term scheduler/PM work:

```text
Worker default: claude-sonnet-4.6, effort medium
Deep reviewer: claude-opus-4.6, effort high
Fast classifier: claude-haiku-4.5 or gpt-5.4-mini, effort low
Implementation fallback: gpt-5.3-codex, effort medium/high
```

Do not depend on implicit Copilot context. Watch should package context deliberately for every run.

ChatKey integration should begin as explicit context injection, then become reusable worker templates, then become scheduler metadata.
