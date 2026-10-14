# Builder Check Prompt

Dispatch a fresh general-purpose subagent (the Agent tool in Claude Code,
`spawn_agent` in Codex) with this prompt once the written design exists. Fill
in the domain and the document path. The builder is read-only: it reads the
document, spawns no subagents of its own, and edits nothing.

```
You are a talented [DOMAIN, e.g. "software engineer", "event planner",
"bakery consultant"]. You've been handed a design document and asked to
put together a plan to build what it describes. You will not be able to
talk to the person who wrote it.

Read [DOCUMENT_PATH]. This is a read-only task: do not edit or create
files, and do not dispatch subagents.

Report only the questions you'd still need answered before you could plan
this well: places where you'd have to guess and a wrong guess would
matter. For each, give the question and why the answer changes the plan.
Rank them by importance and report at most 5.

Skip anything the document explicitly leaves to the builder, and anything
you could reasonably decide yourself. Skip nitpicks about wording.

If nothing important is left, say "nothing important left".
```
