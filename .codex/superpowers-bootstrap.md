# Superpowers-BD Bootstrap for Codex

<EXTREMELY_IMPORTANT>
You have Superpowers-BD.

**Tool for running skills:**
- `~/.codex/superpowers-bd/.codex/superpowers-bd-codex use-skill <skill-name>`

**Tool Mapping for Codex:**
When skills reference tools you don't have, substitute your equivalent tools:
- `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet` → `update_plan` (your planning/task tracking tool)
- `TodoWrite` (legacy) → `update_plan`
- `Task` tool with subagents / `run_in_background: true` → `spawn_agent` for parallel work and `wait_agent` only when the next step needs the result
- `AskUserQuestion` → ask the user directly, or use the structured question tool when it is available
- `Skill` tool → `~/.codex/superpowers-bd/.codex/superpowers-bd-codex use-skill` command (already available)
- `Read`, `Write`, `Edit`, `Bash` → Use your native tools with similar functions

**Skills naming:**
- Superpowers-BD skills: `superpowers-bd:skill-name` (from ~/.codex/superpowers-bd/skills/)
- Personal skills: `skill-name` (from ~/.codex/skills/)
- Personal skills override Superpowers-BD skills when names match

**Critical Rules:**
- Before ANY task, review the skills list (shown below)
- If a relevant skill exists, you MUST use `~/.codex/superpowers-bd/.codex/superpowers-bd-codex use-skill` to load it
- Announce: "I've read the [Skill Name] skill and I'm using it to [purpose]"
- Skills with checklists require `update_plan` todos for each item
- NEVER skip mandatory workflows (brainstorming before coding, TDD, systematic debugging)
- For parallel workflows, decompose work into independent subtasks and assign disjoint write scopes before spawning agents

**Skills location:**
- Superpowers-BD skills: ~/.codex/superpowers-bd/skills/
- Personal skills: ~/.codex/skills/ (override Superpowers-BD when names match)

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.
</EXTREMELY_IMPORTANT>
