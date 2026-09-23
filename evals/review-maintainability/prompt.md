---
description: Maintainability-aware review. The change under review has one real bug (off-by-one tag slice) plus maintainability problems - it re-implements the repo's existing slugify helper, nests four levels deep, and has a vague name and an unused parameter. Tests whether review catches both kinds. Scored in both arms.
tags: [quality, code-review, maintainability, no-bash]
max_turns: 25
timeout_seconds: 450
allowed_tools: [Read, Glob, Grep, Skill, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, Write, Edit]
---

I'm about to merge a change that adds `publish.py` to this repo. Can you review it first? Don't change any code, just give me the review.
