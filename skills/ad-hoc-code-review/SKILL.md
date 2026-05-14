---
name: ad-hoc-code-review
description: Use when the user asks for /cr-style review of local changes, commits, a branch diff, or a GitHub PR outside subagent-driven development
effort: xhigh
---

# Ad-hoc Code Review

Run the same review workflow as `/superpowers-bd:cr`: resolve a review scope, collect requirements, choose reviewer count, dispatch independent reviewers, aggregate when needed, and present findings without automatically fixing them.

## Quick Start

Ask whether to review local changes or a GitHub PR, resolve the diff scope, collect requirements, choose reviewer count, then dispatch reviewers using the canonical command procedure.

## Canonical Method

The full procedure lives at `../../commands/cr.md`. Read it and follow it exactly, with these platform mappings:

- Claude Code: `/superpowers-bd:cr` or `/superpowers-bd:cr N` loads the command directly.
- Codex: invoke this skill as `$ad-hoc-code-review`, then read `../../commands/cr.md`.
- Claude `Task(run_in_background: true)` maps to Codex `spawn_agent` plus `wait_agent`; dispatch independent reviewers in parallel when possible.
- Claude `AskUserQuestion` maps to a concise direct user question when no structured question tool is available.
- Named Claude agent `superpowers-bd:code-reviewer` maps to the reviewer prompt at `../requesting-code-review/code-reviewer.md` when no named agent exists.

## Rules

- Always ask what to review and what requirements to check against.
- Do not treat Codex cross-model review as a gate; it is advisory unless the user explicitly changes the policy.
- Do not fix issues during this workflow. Present the review and stop.
