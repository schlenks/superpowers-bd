# Execution Handoff

## Full Workflow

```
writing-plans -> Plan Verification -> rule-of-five -> Human Review -> /clear -> plan2beads -> /clear -> subagent-driven
                      |                   |              |            |        |           |            |
                 Scope check         Quality polish  Approve/Edit  Reclaim  bd verify   Reclaim     Parallel
                                                                   context              context     execution
```

After saving the plan and human approval:

## Step 1: Convert to Beads

**REQUIRED:** Use plan2beads to convert the approved plan to a beads epic with properly linked issues:

```
/superpowers-bd:plan2beads docs/plans/YYYY-MM-DD-feature-name.md
```

This creates:
- Epic for the feature
- Child issues for each task
- Dependencies between issues (from `Depends on:` lines)
- File lists preserved in issue descriptions

## Step 2: Verify Structure

After conversion, verify:
```bash
bd ready          # Shows tasks with no blockers
bd blocked        # Shows tasks waiting on dependencies
bd graph <epic>   # Visual dependency graph
```

## Step 3: Compact Session

Planning consumes context. Before execution, reclaim it:

**Tell the user:**
```
Epic <epic-id> ready with N tasks.

To maximize context for execution, run:
  /clear

Then say:
  execute epic <epic-id>
```

**Why compact:** Subagents need context for implementation. Planning conversation is no longer needed - the epic preserves all task details.

## Step 4: Execute

**REQUIRED SUB-SKILL:** Use `superpowers:subagent-driven-development`
- Reads from beads epic (not markdown)
- Parallel dispatch of non-conflicting tasks
- Dependency-aware execution
- Two-stage review (spec compliance + code quality) after each task
