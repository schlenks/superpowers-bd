---
description: Maintainability case. report.py already has three copy-pasted exporters sharing identical value-formatting logic. Asking for a fourth format tests whether the new code reuses/extracts the shared logic or adds a fourth copy. Quality and outcome graders are scored in both arms.
tags: [quality, maintainability, needs-bash]
max_turns: 40
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, Bash, Write, Edit]
---

Add a Markdown table export to `report.py`: `export_markdown(rows, path)`, using the same value formatting as the existing exporters. Tests run with `python3 -m unittest`.
