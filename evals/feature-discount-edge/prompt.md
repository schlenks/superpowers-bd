---
description: Multi-file feature with unstated edge cases. A fixed-amount code on a small cart can drive the total negative, and unknown codes need defined behavior. Tests whether the implementation (and its tests) handle edges the request never names. Scored in both arms.
tags: [outcome, edge-cases, needs-bash]
max_turns: 50
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, Bash, Write, Edit]
---

Add discount codes to checkout. `SAVE10` takes 10% off and `FLAT500` takes $5.00 off. A customer can apply one code when checking out. Put the discount logic in a new `discounts.py`. Tests run with `python3 -m unittest`.
