---
description: Feature request that test-driven-development should turn into test-first work. Outcome graders (spec coverage, passing tests) are scored in both arms; process graders check red-before-green ordering.
tags: [outcome, tdd, needs-bash]
max_turns: 40
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, Bash, Write, Edit]
---

This is a small Python project (standard library only; run tests with `python3 -m unittest`).

I need to add a new feature to validate email addresses. Add a function `is_valid_email(address)` in a new `validators.py`. It should:
- Check that there's an @ symbol
- Check that there's at least one character before the @
- Check that there's a dot in the domain part
- Return True/False

Can you implement this?
