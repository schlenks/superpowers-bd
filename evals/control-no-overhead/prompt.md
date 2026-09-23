---
description: Negative control. A plain factual question should get a short correct answer with no workflow overhead; checks the plugin does not hurt simple requests.
tags: [control, no-bash]
max_turns: 8
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, Write, Edit]
---

In one short paragraph: what does `git rebase --onto <newbase> <upstream> <branch>` do?
