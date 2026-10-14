# Plan Step Content

Read this before drafting tasks. A plan records the decisions the implementer cannot make alone. It is not a transcript of the code.

## What a Step Contains

A step is done when the implementer can write exactly one reasonable thing from it: unambiguous, not complete.

- **Test step:** the test's name and its assertions, as code, with the spec's exact values in them. Setup the assertions do not depend on is the implementer's job.
- **Code step:** the exact signature (name, parameters, return type), the file, and the specific values the spec pins (messages, constants, ordering rules). The implementer writes the body. Include a body only for an algorithm the signature and tests do not determine, or for exact copy the spec fixes.
- **Verification step:** the command and the output that means it passed.
- **Reference to another task:** that task's `**Interfaces:**` block says what to use; do not repeat its code.

Two failures, caught by the Step scan and Proportion checks:

- **Transcript.** A plan longer than the code it describes has written the code instead. Several times the spec's length, or mostly code blocks, means bodies crept in. Replace them with signatures, test names and assertions.
- **Placeholder.** Lines that decide nothing: "TBD", "handle edge cases", "add validation", "write tests for the above", a type no task defines.

Planning is not building. Do not create the product's files or run its code while planning; hand-trace a step when you need to check it.

## Task Template

```markdown
### Task N: [Component Name]
**Depends on:** Task M, Task P | None
**Complexity:** simple | standard | complex
**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:** (optional)
- Consumes: [sibling output or signature this task needs, e.g. `UserSchema` type from Task 2]
- Produces: [what this task exposes for siblings, e.g. `AuthToken` type, `POST /api/auth` endpoint]

**Purpose:** [One sentence]

**Step 1: Write the failing test**
[test name and assertions, with the spec's exact values]
**Step 2: Run test to verify it fails**
Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL
**Step 3: Implement `function(input: InputType) -> ResultType` in `exact/path/to/file.py`**
[one line on the approach only where signature + tests leave a choice; code block only for an undetermined algorithm]
**Step 4: Run test to verify it passes**
Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS
**Step 5: Commit**
`git add ...` then `git commit -m "feat: add specific feature"`
```

## Optional Metadata (Preserved Through Import)

These sections are optional. When a plan includes them, `plan2beads` carries them into beads instead of dropping them; when a plan omits them, import is unchanged.

- `**Spec:**` (header line, between the After-approval note and `**Goal:**`): the path or URL of the approved spec, so implementers can consult the source when a step leaves a choice.
- `## Global Constraints` (epic-level): rules that apply to every task. plan2beads threads this text into **every** child task body.
- `**Interfaces:**` (per-task, `Consumes:` / `Produces:`): the contract a task consumes and produces. plan2beads preserves the line verbatim in that task's body. With leaner steps, Interfaces blocks are the contract between parallel tasks.

Both surfaces (`commands/plan2beads.md` and `skills/plan2beads/references/codex-plan2beads-flow.md`) parse these identically.

## Global Constraints Template

Anything here multiplies by N tasks; trim ruthlessly. Rules that apply to only one or two tasks belong in those tasks' bodies.

```markdown
## Global Constraints
- [Rule, concise and actionable, one line each]
- [Rule 2]
```

Example:

```markdown
## Global Constraints
- All plan2beads edits touch BOTH parsers; mirror skills, `diff -rq` empty before commit.
- Commit local only: no push/tag/bd dolt push. No version bump.
```
