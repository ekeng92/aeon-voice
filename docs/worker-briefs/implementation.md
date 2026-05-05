# Implementation Worker Brief Template

Use this template when AEON Watch launches a Copilot CLI worker to implement a bounded code/docs change.

## Recommended Model

- Default: `claude-sonnet-4.6`
- Fallback for mechanical implementation/test loops: `gpt-5.3-codex`
- Reviewer pass: `claude-opus-4.6` when stakes are high

## Recommended Effort

- `medium` for normal implementation
- `high` for multi-file architecture or tricky bugs

## Permission Mode

Default for implementation worker:

- May edit files in the target repo
- May run local read/build/test commands
- Must not commit
- Must not push
- Must not delete unrelated files
- Must not modify credentials/secrets
- Must not run destructive shell commands

## Prompt Template

```text
You are an implementation worker operating under AEON Watch's project management.

Objective:
<one clear outcome>

Primary repo:
<absolute repo path>

Context pack:
- Read these files first:
  - <file path>
  - <file path>
- Additional context, if relevant:
  - /Users/erickeng/Projects/chatkey/.github/copilot-instructions.md
  - /Users/erickeng/Projects/chatkey/aeons/dev/PORTABLE.md
  - /Users/erickeng/Projects/chatkey/learnings/aeon-dev-learnings.md

Scope:
- You may edit files in the primary repo only.
- Keep the change minimal and focused.
- Do not commit.
- Do not push.
- Do not delete files.
- Do not modify secrets or credentials.

Acceptance criteria:
- <criterion 1>
- <criterion 2>
- <criterion 3>

Verification:
- Run the smallest meaningful build/test/lint command.
- If verification cannot run, explain exactly why.

Output format:
Return a concise implementation report with:
1. Files changed
2. Summary of changes
3. Verification performed and result
4. Any risks or follow-up questions
```

## Watch Review Checklist

After the worker returns, Watch must:

1. Inspect `git diff` directly.
2. Verify the worker did not commit/push/delete unexpectedly.
3. Run or confirm the relevant build/test.
4. Decide whether to:
   - accept,
   - ask the worker for follow-up,
   - fix directly,
   - or escalate to Eric.
5. Commit only after Watch review passes.
