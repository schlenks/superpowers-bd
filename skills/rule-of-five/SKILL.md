---
name: rule-of-five
description: Use when writing 50+ lines of code/docs, creating plans, implementing features, or before claiming work complete - apply 5 focused passes (Draft, Correctness, Clarity, Edge Cases, Excellence) to catch issues single-shot generation misses
---

# Rule of Five

Jeffrey Emanuel's discovery: LLMs produce better output through focused passes--Draft, Correctness, Clarity, Edge Cases, Excellence--than single-shot generation. See `references/pass-order-rationale.md` for why this order and convergence details.

**Core principle:** Each pass has ONE job. Re-read the entire artifact through that lens.

## Quick Start

**Create native tasks for 5 passes with sequential dependencies:**

```
TaskCreate: "Pass 1: Draft"
  description: "Shape and structure. Get the outline right. Breadth over depth."
  activeForm: "Drafting"

TaskCreate: "Pass 2: Correctness"
  description: "Logic, bugs, regressions. Does it work? Did it break anything?"
  activeForm: "Checking correctness"
  addBlockedBy: [draft-task-id]

TaskCreate: "Pass 3: Clarity"
  description: "Comprehension. Can someone unfamiliar understand this? Simplify."
  activeForm: "Improving clarity"
  addBlockedBy: [correctness-task-id]

TaskCreate: "Pass 4: Edge Cases"
  description: "Failure modes. What's missing? What breaks under stress?"
  activeForm: "Handling edge cases"
  addBlockedBy: [clarity-task-id]

TaskCreate: "Pass 5: Excellence"
  description: "Pride. Would you show this to a senior colleague? Polish rough spots."
  activeForm: "Polishing"
  addBlockedBy: [edge-cases-task-id]
```

**ENFORCEMENT:**
- Each pass is blocked until the previous completes
- Cannot commit until all 5 tasks show `status: completed`
- TaskList shows your progress through the passes
- Skipping passes is visible - blocked tasks can't be marked in_progress

For each pass: re-read the full artifact, evaluate through that lens only, make changes, then mark task complete.

## Detection Triggers

**Invoke this skill when ANY of these are true:**
- [ ] Writing or modifying >50 lines of code in a single artifact
- [ ] Creating a new public API, interface, or component
- [ ] Writing an implementation plan or design document
- [ ] Complex refactoring affecting multiple files
- [ ] Security-sensitive code changes
- [ ] About to claim work is "complete" or "done"

**Skip for:** Single-line fixes, typo corrections, trivial changes under 20 lines.

**Announce at start:** "Applying rule-of-five to [artifact]. Starting 5-pass review."

## The 5 Passes

| Pass | Focus | Exit when... |
|------|-------|--------------|
| **Draft** | Shape and structure. Don't perfect - get the outline right. Breadth over depth. | All major components exist |
| **Correctness** | Logic, bugs, regressions. Does it work? Did it break anything? | No known errors; no regressions |
| **Clarity** | Comprehension. Can someone unfamiliar understand this? Simplify. Cut jargon. | A newcomer could follow it |
| **Edge Cases** | Failure modes. What's missing? What breaks under stress? | Unusual inputs handled |
| **Excellence** | Pride. Would you show this to a senior colleague? Polish the rough spots. | You'd sign your name to it |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Multiple lenses in one pass | ONE lens per pass. Correctness pass ignores style. |
| Skipping passes on "simple" artifacts | All 5 or none. Choose a different approach for trivial work. |
| Rushing through passes | Each pass: genuinely re-read the full artifact |
| Pass finds nothing to change | That's fine. Move on. Not every pass surfaces issues. |
| Applying to entire codebase | Artifact = the unit you're changing. A function, component, or document--not the whole system. |
| Ignoring consumers when modifying | Grep for usages. Check if callers depend on specific behavior you're changing. |

## Modifying Existing Code

Shift the Correctness pass: **"Did I break anything?"** matters more than "Does my addition work?"

**Correctness checklist for modifications:**
1. Does my change work correctly?
2. Did I break the code I modified?
3. Did I break tests that depend on old behavior?
4. **Did I break consumers?** (Other code that calls/uses what I changed)

For interface changes and consumer breakage warning signs, see `references/modification-checklist.md`.

## Integration with Other Skills

- **superpowers:writing-plans** -- Apply 5 passes to plans before ExitPlanMode
- **superpowers:subagent-driven-development** -- Implementer applies to significant artifacts
- **superpowers:executing-plans** -- Apply to each batch's output
- **superpowers:verification-before-completion** -- Final quality check before claiming done
- **superpowers:test-driven-development** -- Applies to tests AND implementation separately
- **superpowers:requesting-code-review** -- Reviewer can use these lenses; author should have already

These skills invoke rule-of-five automatically for plans >50 lines, significant implementations, and work being marked complete.

## Reference Files

| File | When to read |
|------|-------------|
| `references/example-before-after.md` | Full before/after code example with findings table |
| `references/pass-order-rationale.md` | Why this order, convergence theory, handling cross-pass issues |
| `references/modification-checklist.md` | Interface change checklist and consumer breakage warning signs |
