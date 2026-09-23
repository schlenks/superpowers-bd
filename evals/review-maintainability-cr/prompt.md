---
description: Same fixture as review-maintainability, but the request names the superpowers-bd cr review workflow so the with-arm runs the plugin's own reviewer (code-reviewer.md rules, which demote readability findings when a bug exists). Measures whether the plugin reviewer loses maintainability findings that a bare review reports. Scored in both arms.
tags: [quality, code-review, maintainability, needs-bash]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, Bash, Write, Edit]
---

Use the superpowers-bd cr code review workflow to review the latest commit (HEAD~1..HEAD), which adds `publish.py`. Answers to its setup questions: review the local commit range HEAD~1..HEAD; the requirement is the behavior promised in `publish.py`'s docstring; use a single reviewer. Don't change any code, just give me the review findings.
