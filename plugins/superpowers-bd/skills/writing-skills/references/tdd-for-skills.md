# TDD for Skills

## TDD Mapping

| TDD Concept | Skill Creation |
|-------------|----------------|
| **Test case** | Pressure scenario with subagent |
| **Production code** | Skill document (SKILL.md) |
| **Test fails (RED)** | Agent violates rule without skill (baseline) |
| **Test passes (GREEN)** | Agent complies with skill present |
| **Refactor** | Close loopholes while maintaining compliance |
| **Write test first** | Run baseline scenario BEFORE writing skill |
| **Watch it fail** | Document exact rationalizations agent uses |
| **Minimal code** | Write skill addressing those specific violations |
| **Watch it pass** | Verify agent now complies |
| **Refactor cycle** | Find new rationalizations → plug → re-verify |

## Phase Task Enforcement

When creating or editing a skill, create native tasks for each TDD phase:

```
TaskCreate: "RED: Write failing test (baseline)"
  description: "Run pressure scenarios WITHOUT skill. Document: baseline behavior, rationalizations verbatim, which pressures triggered violations."
  activeForm: "Running baseline tests"

TaskCreate: "GREEN: Write minimal skill"
  description: "Write skill addressing specific baseline failures. Run scenarios WITH skill and verify compliance. Apply rule-of-five-plans."
  activeForm: "Writing skill"
TaskUpdate: green-task-id
  addBlockedBy: [red-task-id]

TaskCreate: "REFACTOR: Close loopholes"
  description: "Identify observed gaps, add the smallest evidence-backed correction, and rerun the same scenarios."
  activeForm: "Closing loopholes"
TaskUpdate: refactor-task-id
  addBlockedBy: [green-task-id]
```

**Progress contract:**
- Do not write skill content until the RED task is `status: completed`
- GREEN task requires baseline documentation in RED task
- Complete all 3 phases before presenting the skill as verified
- TaskList shows skipped or out-of-order phases

## Micro-Test Wording (Pre-Step)

Before running full eval scenarios, spend 10–15 minutes sanity-checking that your scenario wording actually produces the failure you expect. This is cheap insurance against spending an hour on a baseline that never fails for the wrong reason.

**Protocol:**
1. **No-guidance control run.** Strip the skill from the context entirely. Run the raw scenario prompt against a fresh subagent — no preamble, no hints. You want to see what the model does with zero scaffolding.
2. **Minimum 5 reps.** A single run proves nothing. Run the identical prompt at least 5 times and record each outcome independently. LLM variance is real; one "pass" in 5 is a different signal than 5/5.
3. **Read every transcript by hand.** Do not grep-and-trust (`grep "complied" transcript.jsonl`). Open each transcript and read it. The rationalization pattern you need to counter often appears mid-response, not at the end, and grep misses it. Variance in *how* the model fails is as important as whether it fails.
4. **Record variance as a signal.** Tally not just pass/fail but the shape of each response: Did it comply on wording but violate the spirit? Did it skip the critical clause or invert it? High output variance means the boundary is fuzzy — your scenario wording may need tightening before you can trust a RED baseline.
5. **Classifier handoff.** If you observe **high variance + output-shaping failures** (model is trying to comply but phrasing trips it up), pair this with the "Match Guidance to the Observed Failure" classifier in `bulletproofing.md`: a positive recipe ("always do X") is the right fix, not a prohibition. Low variance + clean refusal = a prohibition counter is correct.

**Exit condition:** You have a scenario that produces a consistent failure pattern across ≥5 reps. If you can't get a consistent failure, your scenario wording is the problem — rewrite before entering RED.

## RED: Write Failing Test (Baseline)

Run pressure scenario with subagent WITHOUT the skill. Document exact behavior:
- What choices did they make?
- What rationalizations did they use (verbatim)?
- Which pressures triggered violations?

This is "watch the test fail" — you must see what agents naturally do before writing the skill.

## GREEN: Write Minimal Skill

Write skill that addresses those specific rationalizations. Don't add extra content for hypothetical cases.

Run same scenarios WITH skill. Agent should now comply.

## REFACTOR: Close Loopholes

When a repeated scenario reveals a new failure pattern, add the smallest
instruction that addresses it and rerun the same scenario set.

**Testing methodology:** See `testing-skills-with-subagents.md` (in this directory) for the complete testing methodology:
- How to write pressure scenarios
- Pressure types (time, sunk cost, authority, exhaustion)
- Plugging holes systematically
- Meta-testing techniques

## Testing by Skill Type

### Discipline-Enforcing Skills (rules/requirements)

**Examples:** TDD, verification-before-completion, designing-before-coding

**Test with:**
- Academic questions: Do they understand the rules?
- Pressure scenarios: Do they comply under stress?
- Multiple pressures combined: time + sunk cost + exhaustion
- Identify rationalizations and add explicit counters

**Success criteria:** Agent follows rule under maximum pressure

### Technique Skills (how-to guides)

**Examples:** condition-based-waiting, root-cause-tracing, defensive-programming

**Test with:**
- Application scenarios: Can they apply the technique correctly?
- Variation scenarios: Do they handle edge cases?
- Missing information tests: Do instructions have gaps?

**Success criteria:** Agent successfully applies technique to new scenario

### Pattern Skills (mental models)

**Examples:** reducing-complexity, information-hiding concepts

**Test with:**
- Recognition scenarios: Do they recognize when pattern applies?
- Application scenarios: Can they use the mental model?
- Counter-examples: Do they know when NOT to apply?

**Success criteria:** Agent correctly identifies when/how to apply pattern

### Reference Skills (documentation/APIs)

**Examples:** API documentation, command references, library guides

**Test with:**
- Retrieval scenarios: Can they find the right information?
- Application scenarios: Can they use what they found correctly?
- Gap testing: Are common use cases covered?

**Success criteria:** Agent finds and correctly applies reference information

## When to Create a Skill

**Create when:**
- Technique wasn't intuitively obvious to you
- You'd reference this again across projects
- Pattern applies broadly (not project-specific)
- Others would benefit

**Don't create for:**
- One-off solutions
- Standard practices well-documented elsewhere
- Project-specific conventions (put in CLAUDE.md)
- Mechanical constraints (if it's enforceable with regex/validation, automate it)
