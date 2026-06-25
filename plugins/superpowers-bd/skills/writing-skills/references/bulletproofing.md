# Bulletproofing Skills Against Rationalization

Skills that enforce discipline (like TDD) need to resist rationalization. Agents are smart and will find loopholes when under pressure.

**Psychology note:** Understanding WHY persuasion techniques work helps you apply them systematically. See `persuasion-principles.md` (in this directory) for research foundation (Cialdini, 2021; Meincke et al., 2025) on authority, commitment, scarcity, social proof, and unity principles.

## Close Every Loophole Explicitly

Don't just state the rule — forbid specific workarounds:

**Bad:**
```markdown
Write code before test? Delete it.
```

**Good:**
```markdown
Write code before test? Delete it. Start over.

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete
```

## Address "Spirit vs Letter" Arguments

Add foundational principle early:

```markdown
**Violating the letter of the rules is violating the spirit of the rules.**
```

This cuts off the entire class of "I'm following the spirit" rationalizations.

## Build Rationalization Table

Capture rationalizations from baseline testing. Every excuse agents make goes in the table:

```markdown
| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Tests after achieve same goals" | Tests-after = "what does this do?" Tests-first = "what should this do?" |
```

## Common Rationalizations for Skipping Testing

| Excuse | Reality |
|--------|---------|
| "Skill is obviously clear" | Clear to you ≠ clear to other agents. Test it. |
| "It's just a reference" | References can have gaps, unclear sections. Test retrieval. |
| "Testing is overkill" | Untested skills have issues. Always. 15 min testing saves hours. |
| "I'll test if problems emerge" | Problems = agents can't use skill. Test BEFORE deploying. |
| "Too tedious to test" | Testing is less tedious than debugging bad skill in production. |
| "I'm confident it's good" | Overconfidence guarantees issues. Test anyway. |
| "Academic review is enough" | Reading ≠ using. Test application scenarios. |
| "No time to test" | Deploying untested skill wastes more time fixing it later. |

**All of these mean: Test before deploying. No exceptions.**

## Create Red Flags List

Make it easy for agents to self-check when rationalizing:

```markdown
## Red Flags - STOP and Start Over

- Code before test
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "It's about spirit not ritual"
- "This is different because..."

**All of these mean: Delete code. Start over with TDD.**
```

## Update CSO for Violation Symptoms

Add to description: symptoms of when you're ABOUT to violate the rule:

```yaml
description: use when implementing any feature or bugfix, before writing implementation code
```

## Match the Form to the Failure

Not all failures respond to the same fix. Using the wrong form makes skills actively worse.

### Two Failure Classes

**Discrete-action failures** — the agent skips a step, calls the wrong tool, or commits without running tests. The action is binary: it either happened or it didn't. Prohibition lists work here because there is a clear wrong move to forbid.

```markdown
# Works for discrete-action failures
- Do NOT commit before running the test suite.
- Do NOT skip the RED phase and write implementation first.
```

**Output-shaping failures** — the agent produces the right kind of output but in the wrong register: too verbose, too terse, wrong tone, ignores format conventions. The failure is on a continuous scale with no single wrong move. Prohibition lists backfire here. Measured upstream: a "do not" list for output style performed *worse than a no-guidance control* — agents spent tokens avoiding named anti-patterns while introducing unnamed variants. The prohibition primes the failure pattern.

### For Output-Shaping Failures: Use a Positive Recipe

Instead of naming what to avoid, show the target form directly. Give the agent a worked example it can match against.

**Bad (prohibition list for tone):**
```markdown
- Do not be verbose.
- Do not use filler phrases.
- Do not repeat the question before answering.
```

**Good (positive recipe with worked example):**
```markdown
**Report format:** one sentence of outcome, one sentence of evidence, stop.

Example:
> Gate passed. `grep -n "Match the Form to the Failure" bulletproofing.md` returned line 111.
```

The recipe gives the agent a concrete target. The example anchors the register without naming the failure modes.

### Telling Which Class You Have

Run the micro-test described in `tdd-for-skills.md` → "Micro-Test Wording" (A3). If the failure scenario asks "did the agent perform action X?" it is discrete. If it asks "did the agent's output have quality Y?" it is output-shaping. Write the skill guidance to match.

## Anti-Patterns

### Narrative Example
"In session 2025-10-03, we found empty projectDir caused..."
**Why bad:** Too specific, not reusable

### Multi-Language Dilution
example-js.js, example-py.py, example-go.go
**Why bad:** Mediocre quality, maintenance burden

### Code in Flowcharts
```dot
step1 [label="import fs"];
step2 [label="read file"];
```
**Why bad:** Can't copy-paste, hard to read

### Generic Labels
helper1, helper2, step3, pattern4
**Why bad:** Labels should have semantic meaning
