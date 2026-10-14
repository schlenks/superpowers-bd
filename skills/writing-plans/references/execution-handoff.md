# Execution Handoff

## Full Workflow

**Context-aware:** Use the 1M flow when the model ID contains `[1m]` or belongs
to a 1M-native family (`sonnet-5` or `fable-5`). Use the 200k flow only when
neither condition applies.

### Extended context (1M) — streamlined flow
```
writing-plans -> Plan Verification -> rule-of-five-plans -> Human Review -> plan2beads -> Choose mode -> SDD | Native
                       |                     |                  |              |              |              |
                  Scope check          Quality polish      Approve/Edit   Convert + verify  [EXECUTION-MODE]  Execution
```

### Standard context (200k) — with compaction pauses
```
writing-plans -> Plan Verification -> rule-of-five-plans -> Human Review -> /clear -> plan2beads -> Choose mode -> /clear -> SDD | Native
                       |                     |                  |            |            |              |            |          |
                  Scope check          Quality polish      Approve/Edit   Reclaim   Convert + verify  [EXECUTION-MODE] Reclaim  Execution
                                                                          context                                    context
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

## Step 3: Choose the Execution Mode

Offer both modes, each with its cost line, and a recommendation:

- **SDD** (`superpowers-bd:subagent-driven-development`): fresh implementer and reviewers per issue, parallel waves. Costs the most (upstream measured about 2.5x Native on a small fixture), and holds up on long epics.
- **Native** (`superpowers-bd:executing-plans`): this session implements every issue and one verifier on the most capable model reviews the whole epic. Cheapest; later issues run on a compacting context.

**Recommendation:** Native when the epic has ≤5 implementation issues (not counting the verification task) or every implementation issue is labeled `complexity:simple`; otherwise SDD. An explicit choice from the user or the plan overrides the recommendation.

- **Interactive:** ask with the platform question mechanism (Claude Code: `AskUserQuestion`; Codex: `request_user_input` when available, else a direct question), listing the recommended mode first.
- **Unattended** (as defined in `superpowers-bd:finishing-a-development-branch`: explicit signals only): do not ask. Take the recommendation.

Either way, record the choice on the epic before starting:

```bash
bd comments add <epic-id> "[EXECUTION-MODE] <SDD|Native> — <why: issue count, complexity labels, or the user's choice>"
```

## Step 4: Begin Execution

**Extended context (1M):** Proceed directly — announce the epic and mode, then begin:
```
Epic <epic-id> ready with N tasks. Execution: <SDD|Native>. Starting execution.
```

**Standard context (200k):** Planning consumes context. Before execution, reclaim it:
```
Epic <epic-id> ready with N tasks. Execution: <SDD|Native>.

To maximize context for execution, run:
  /clear

Then say one of:
  execute epic <epic-id>                          (SDD)
  use executing-plans on epic <epic-id>           (Native)
```

## Step 5: Execute

**REQUIRED SUB-SKILL**, per the recorded mode:
- **SDD:** `superpowers-bd:subagent-driven-development`: parallel dispatch of non-conflicting tasks, dependency-aware waves, spec and code review after each task.
- **Native:** `superpowers-bd:executing-plans`: issues in `bd ready` order in this session, TDD per issue, one epic-verifier review and one fix pass at the end.
