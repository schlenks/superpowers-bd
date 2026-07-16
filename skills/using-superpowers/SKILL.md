---
name: using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions
effort: medium
---

# Using Superpowers-BD

Before the first response in a conversation, load this routing skill. Then load
relevant or explicitly requested skills before taking task actions. Skills
provide workflow-specific context and quality gates; if a loaded skill is not
relevant after inspection, do not apply it.

## Access Skills

- **Claude Code:** Use the `Skill` tool. Follow the loaded skill through Claude
  Code's native tools.
- **Codex:** Use native `$skill-name` invocation when installed as a plugin. For
  the manual fallback, run
  `~/.codex/superpowers-bd/.codex/superpowers-bd-codex use-skill <skill-name>`.
- **Other platforms:** Use that platform's skill loader and native adapter.

## Platform Boundary

Shared skills define workflow intent. Each platform implements that intent with
its own tools and comparable outcomes.

| Shared intent | Claude Code | Codex |
|---------------|-------------|-------|
| Track progress | `TaskCreate`, then `TaskUpdate` for status/dependencies | `update_plan` |
| Delegate work | `Agent`, background when appropriate | `spawn_agent`, then `wait_agent` when blocked |
| Ask questions | `AskUserQuestion` | `request_user_input` when available, otherwise a direct question |
| Verify completion | `Skill` plus commands and captured evidence | `$skill` plus commands and captured evidence |

Command-backed workflows must expose native entry points for every supported
platform. Shared scripts are fine; orchestration remains platform-native.

## Skill Selection

1. Load process skills first when they determine the approach, such as
   brainstorming, debugging, review reception, or planning.
2. Load implementation/domain skills next.
3. Use the smallest set that covers the task and state the order when several
   apply.
4. Read the current skill rather than relying on remembered wording.

Rigid skills define an invariant that must be preserved. Flexible skills define
patterns that may be adapted to context. The skill should make that distinction
clear.

## Conflict Hierarchy

When instructions conflict:

1. The user's direct instruction and the platform's project instructions
   (`CLAUDE.md` or `AGENTS.md`) take precedence.
2. Rigid safety and correctness invariants apply unless directly overridden.
3. Flexible skill guidance adapts to the task.

Skills normally own workflow mechanics, but an explicit user instruction to
skip or change a specific step is an override, not something to reinterpret.

## Native Progress

For Claude Code, create the task first, capture its ID, then add dependencies
with `TaskUpdate`:

```text
TaskCreate: "Phase 1: Investigate"
  description: "Gather evidence and identify the cause."
  activeForm: "Investigating"

TaskCreate: "Phase 2: Implement"
  description: "Apply the verified fix."
  activeForm: "Implementing"

TaskUpdate: phase-2-id
  addBlockedBy: [phase-1-id]
```

For Codex, use `update_plan` and preserve the same evidence-based ordering.
Progress state makes skipped or out-of-order phases visible; it does not replace
verification or independently prevent unrelated actions.

When Codex delegates parallel work, give each worker explicit file ownership,
state that other agents may also be editing the repository, and keep write
scopes disjoint.

In beads-aware repositories, beads tracks durable project work while native
progress tools track the current workflow phases.
