---
description: Negative control for brainstorming. A one-line, fully specified edit should simply be made, with no design document or interview. Checks the plugin does not add ceremony to quick clear tasks.
tags: [control, brainstorming, no-bash]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, Write, Edit]
---

In greet.py, change the default greeting from "Hello" to "Howdy".
