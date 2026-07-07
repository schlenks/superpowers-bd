---
name: ad-hoc-code-review
description: Use when the user asks for /cr-style review of local changes, commits, a branch diff, or a GitHub PR outside subagent-driven development
effort: high
disallowed-tools: [Write, Edit, NotebookEdit]
---

# Ad-hoc Code Review

Run the same review workflow as `/superpowers-bd:cr`: resolve a review scope, collect requirements, choose reviewer count, dispatch independent reviewers, aggregate when needed, and present findings without automatically fixing them.

## Quick Start

Ask whether to review local changes or a GitHub PR, resolve the diff scope, collect requirements, choose reviewer count, then dispatch reviewers using the native flow for the current platform.

## Platform Routing

- **Claude Code:** `/superpowers-bd:cr` or `/superpowers-bd:cr N` loads the Claude command implementation at `../../commands/cr.md`.
- **Codex:** Follow `references/codex-review-flow.md`. Treat this skill and that reference as the native workflow; do not route Codex through the Claude slash command.

- Codex native agent `code_reviewer` should handle independent review passes when available; use the reviewer prompt at `../requesting-code-review/code-reviewer.md` as the shared fallback review standard.
- Codex native agent `review_aggregator` should synthesize N>1 independent reviews when available; use `../multi-review-aggregation/aggregator-prompt.md` as the shared fallback aggregation standard.
- Named Claude agent `superpowers-bd:code-reviewer` remains the Claude Code specialist reviewer.

## Rules

- Always ask what to review and what requirements to check against.
- Do not treat Codex cross-model review as a gate; it is advisory unless the user explicitly changes the policy.
- Do not fix issues during this workflow. Present the review and stop.

## Reference Files

- `references/codex-review-flow.md`: Codex-native ad-hoc review flow
