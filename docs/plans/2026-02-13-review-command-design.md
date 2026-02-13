# /cr Command Design

Ad-hoc code review outside the SDD workflow, reusing the existing code-reviewer agent and multi-review aggregation pipeline.

Renamed from `/review` to `/cr` to avoid collision with Claude Code's built-in `/review` command.

## Usage

```
/cr            # single reviewer (default)
/cr 3          # 3 independent reviewers, aggregated
/cr 10         # max 10 reviewers
```

N is capped at 10 (SWR-Bench shows diminishing returns beyond n=10).

## Flow

1. **Parse argument** — extract N from args (default 1, max 10)
2. **Ask scope** — what code to review:
   - Uncommitted changes (staged + unstaged vs HEAD)
   - Last commit (HEAD~1..HEAD)
   - Since last push (@{push}..HEAD, fallback: merge-base origin/main)
   - Branch diff vs main (main..HEAD)
   - Custom SHAs
3. **Ask requirements source** — what to check against:
   - Beads task/epic ID (fetch via `bd show`)
   - Commit messages (auto-extracted from range)
   - Paste/describe inline
   - Skip (general correctness + security review)
4. **Resolve SHAs** — compute BASE_SHA and HEAD_SHA from scope choice
5. **Resolve requirements** — fetch/format requirements text from source choice
6. **Dispatch reviewer(s)**:
   - N=1: single code-reviewer agent, wait for result
   - N>1: N parallel background agents, each with "You are Reviewer {i} of {N}. Review independently.", aggregate via multi-review-aggregation skill
7. **Present report** — structured findings, assessment, done

## Dispatch Details

### Single Review (N=1)

Dispatch `superpowers-bd:code-reviewer` agent via Task tool with:
- `{BASE_SHA}` and `{HEAD_SHA}` from scope resolution
- `{PLAN_OR_REQUIREMENTS}` from requirements resolution

### Multi-Review (N>1)

Dispatch N `superpowers-bd:code-reviewer` agents via Task tool with `run_in_background: true`. Each reviewer gets:
- Same SHAs and requirements
- Identity prefix: "You are Reviewer {i} of {N}. Review independently."

After all complete, feed N reports into multi-review-aggregation:
- Union of all findings
- Severity resolution (highest severity wins when reviewers disagree; lone findings keep original severity for Critical/Important)
- Agreement counts per finding
- Merged assessment

### Requirements Resolution

| Source | Resolution |
|--------|-----------|
| Beads task/epic | Run `bd show <ID>`, use description |
| Commit messages | Run `git log --format="%h %s%n%b" BASE..HEAD` |
| Inline text | Use as-is |
| Skip | "General review: check for correctness, security, and code quality." |

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `commands/cr.md` | Create | Slash command with frontmatter + dispatch logic |
| `skills/requesting-code-review/SKILL.md` | Edit | Add note pointing to `/cr` for ad-hoc use |

No changes to code-reviewer agent, methodology, or multi-review-aggregation skill.

## Scope

The command is a new entry point into existing infrastructure. It adds no new review logic — only wiring.
