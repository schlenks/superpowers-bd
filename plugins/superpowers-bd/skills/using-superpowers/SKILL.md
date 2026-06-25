---
name: using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions
effort: medium
---

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## How to Access Skills

**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you--follow it directly. Never use the Read tool on skill files.

**In Codex:** Use native `$skill-name` invocation when installed as a Codex plugin. If using the manual fallback install, run `~/.codex/superpowers-bd/.codex/superpowers-bd-codex use-skill <skill-name>` and follow the returned instructions.

**In other environments:** Use the platform's skill loader, then apply the native execution guidance in that platform's Superpowers-BD docs.

## Platform Boundary

Superpowers-BD skills define shared workflow intent first. Each agent tool executes that intent through its native platform layer, with comparable outcomes implemented in platform-native terms.

| Shared intent | Claude Code implementation | Codex implementation |
|---------------|----------------------------|----------------------|
| Track progress | `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet` | `update_plan` |
| Delegate work | `Task` with background execution when appropriate | `spawn_agent`, then `wait_agent` when blocked on results |
| Ask questions | `AskUserQuestion` | `request_user_input` when available for structured choices, otherwise direct user question |
| Verify completion | `Skill` plus verification commands and captured evidence | `$skill` plus verification commands and captured evidence |

Command-backed workflows must provide a native path for every supported platform. A Claude Code slash command, Codex `$skill`/plugin entry point, OpenCode command, or fallback CLI may share shell scripts and skill content, but the user-facing invocation and tool orchestration must be native to that platform.

# Using Skills

## The Rule

**Invoke relevant or requested skills BEFORE any response or action.** Even a 1% chance a skill might apply means that you should invoke the skill to check. If an invoked skill turns out to be wrong for the situation, you don't need to use it.

## Red Flags

These thoughts mean STOP--you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |

## Skill Priority

When multiple skills could apply, use this order:

1. **Process skills first** (brainstorming, debugging) - these determine HOW to approach the task
2. **Implementation skills second** (frontend-design, mcp-builder) - these guide execution

"Let's build X" -> brainstorming first, then implementation skills.
"Fix this bug" -> debugging first, then domain-specific skills.

## Skill Types

**Rigid** (TDD, debugging): Follow exactly. Don't adapt away discipline.
**Flexible** (patterns): Adapt principles to context. The skill itself tells you which.

## User Instructions

Instructions say WHAT, not HOW. "Add X" or "Fix Y" doesn't mean skip workflows.

**Priority on conflict:** When a direct instruction contradicts skill guidance, resolve using this hierarchy:
1. **User's direct instruction** / `CLAUDE.md` (Claude) / `AGENTS.md` (Codex) — explicit overrides win.
2. **Rigid skills** (TDD, debugging discipline) — follow exactly; they are second only to direct user authority.
3. **Flexible skill guidance** — adapt to context when no higher-priority rule applies.

The WHAT-not-HOW rule still holds: skills own the HOW *unless the user directly names a specific step to skip or change*. The hierarchy is about resolving conflicts, not about whether to invoke a skill in the first place.

## Native Progress Integration

Many skills use native progress tools to enforce quality gates and track execution progress. Use the implementation for the platform currently running the skill.

**Claude Code pattern:** Skills with multi-phase processes create sequential, blocked tasks:

```
TaskCreate: "Phase 1: [Description]"
  description: "[Acceptance criteria]"
  activeForm: "[Present continuous action]"
  # Returns task ID (e.g., "1") - capture this for dependencies

TaskCreate: "Phase 2: [Description]"
  addBlockedBy: ["1"]  # Use actual ID returned from Phase 1
```

**Note:** TaskCreate returns a task ID in its response. Capture this ID to use in `addBlockedBy` for dependent tasks. The `[phase-1-id]` placeholders in skill documentation represent where you insert the actual returned ID.

**Codex pattern:** Use `update_plan` for the same ordered progress gate. Preserve ordering manually: do not mark a later phase complete before the earlier phase has evidence.

**When invoking skills with progress gates:** Use the platform's native progress mechanism. Follow the skill's instructions for when to mark phases complete.

## Codex Native Tools

**Codex:** use `update_plan` for progress blocks, `spawn_agent` for delegated workers, and `wait_agent` only when the next step needs the result. When spawning workers, give explicit file ownership and tell them other agents may also be editing the repo.

**Beads-aware repos:** use `bd` for durable work tracking when the repo requires it. Native task/progress tools track execution phases; beads tracks the actual project work.

<!-- compressed: 2026-02-11, original: 850 words, compressed: 599 words -->
