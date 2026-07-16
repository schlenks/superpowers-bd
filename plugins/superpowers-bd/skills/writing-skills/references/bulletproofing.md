# Match Guidance to the Observed Failure

**Load this reference when:** an evaluation shows a skill is not reliably
producing the intended action or output.

Start from transcripts and tool evidence. Add the smallest instruction that
addresses the observed failure, then rerun the same evaluation.

## Classify the Failure

### Discrete-action failures

The agent skipped a required action, called the wrong tool, or advanced without
required evidence. The result is binary and auditable.

Use a concise invariant plus the observable proof:

```markdown
Before closing the issue, run the named verification command and include its
exit code in the report.
```

Prefer deterministic validators or hooks when the condition can be checked
without interpreting prose.

### Output-shaping failures

The agent produced the right kind of result in the wrong form, tone, level of
detail, or structure. These failures live on a continuum.

Use a positive recipe and a short example:

```markdown
Report format: one sentence with the outcome, then one sentence with the
supporting command and result.

Example:
Gate passed. `pytest tests/auth -q` exited 0 with 42 passing tests.
```

Long prohibition lists tend to prime the unwanted patterns and miss unnamed
variants. In the measured upstream evaluation, an output-style prohibition list
performed worse than a no-guidance control. A concrete target gives the model
something stable to reproduce.

## Build from Evaluation Evidence

1. Run a no-guidance control.
2. Repeat enough times to observe variance.
3. Read the transcripts and tool results rather than grepping only final text.
4. Name the exact failure: missing action, wrong tool, unsupported claim,
   malformed schema, or output-shape mismatch.
5. Add one invariant, recipe, example, validator, or hook that directly targets
   it.
6. Rerun the same scenarios and compare failure rates.

If the baseline does not show a stable problem, do not add preventive prose.

## Progressive Disclosure

Keep hot-path SKILL.md content short:

- Put the trigger and immediate action in SKILL.md.
- Put detailed examples and rare recovery paths in references.
- Add a "Load this reference when" line so the agent knows when the reference is
  useful.
- Prefer one canonical reference over duplicated platform blocks when both
  platforms can load it reliably.

## Common Mistakes

- Treating an output-style issue as a list of forbidden phrases.
- Claiming a progress task technically prevents unrelated actions.
- Adding counters for hypothetical failures that were never observed.
- Using model-specific tool names in shared guidance without a capability-based
  fallback.
- Keeping stale examples after the native platform API changes.
