---
name: rule-of-five
description: Use when writing >50 lines of code/docs, creating plans, implementing features, or before claiming work complete - apply 5 focused passes (Draft, Correctness, Clarity, Edge Cases, Excellence) to catch issues single-shot generation misses
---

# Rule of Five

Jeffrey Emanuel's discovery: LLMs produce better output through focused passes—Draft, Correctness, Clarity, Edge Cases, Excellence—than single-shot generation. At 4-5 iterations, the output "converges" - the point where further passes yield diminishing returns.

**Core principle:** Each pass has ONE job. Re-read the entire artifact through that lens.

## Why It Works

LLMs solve problems breadth-first: broad strokes first, then refinement. Single-shot generation stops at "broad strokes." Multiple passes force the depth work humans do naturally when revising.

**In practice**: Single-shot code ships with bugs that 5 passes catch. The example below found 4 issues—each surfaced by a different pass. Time: ~10 minutes. Alternative: debugging in production.

## Quick Start

Create todos for 5 passes. For each pass: re-read the full artifact, evaluate through that lens only, make changes.

```
todos: [
  { content: "Draft", activeForm: "Drafting", status: "in_progress" },
  { content: "Correctness", activeForm: "Checking correctness", status: "pending" },
  { content: "Clarity", activeForm: "Improving clarity", status: "pending" },
  { content: "Edge cases", activeForm: "Handling edge cases", status: "pending" },
  { content: "Excellence", activeForm: "Polishing", status: "pending" }
]
```

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

## Example

**Draft:**
```javascript
function calculateDiscount(price, discount) {
  return price - (price * discount);
}
```

**After 5 passes:**
```javascript
function applyPercentageDiscount(originalPrice, discountPercent) {
  if (typeof originalPrice !== 'number' || typeof discountPercent !== 'number') {
    throw new TypeError('Price and discount must be numbers');
  }
  if (originalPrice < 0) throw new RangeError('Price cannot be negative');
  if (discountPercent < 0 || discountPercent > 1) {
    throw new RangeError('Discount must be between 0 and 1');
  }
  return Math.round((originalPrice - discountPercent * originalPrice) * 100) / 100;
}
```

| Pass | Found |
|------|-------|
| Correctness | discount > 1 creates negative prices |
| Clarity | "discount" ambiguous—10 or 0.1 for 10%? |
| Edge Cases | Floating point: $17.991 instead of $17.99 |
| Excellence | Error types inconsistent, messages unclear |

## Why This Order

- **Breadth before depth** - Don't polish what might get deleted
- **Correct before clear** - Fix bugs before wordsmithing
- **Clear before robust** - Understand it before edge-casing it
- **Robust before excellent** - Handle failures before polishing

## When Passes Find Issues from Earlier Passes

If Excellence reveals a bug (Correctness issue): fix it, then re-run Excellence. Don't restart all passes - just fix and continue.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Multiple lenses in one pass | ONE lens per pass. Correctness pass ignores style. |
| Skipping passes on "simple" artifacts | All 5 or none. Choose a different approach for trivial work. |
| Rushing through passes | Each pass: genuinely re-read the full artifact |
| Pass finds nothing to change | That's fine. Move on. Not every pass surfaces issues. |
| Applying to entire codebase | Artifact = the unit you're changing. A function, component, or document—not the whole system. |
| Ignoring consumers when modifying | Grep for usages. Check if callers depend on specific behavior you're changing. |

## Modifying Existing Code

Shift the Correctness pass: **"Did I break anything?"** matters more than "Does my addition work?"

**Correctness checklist for modifications:**
1. Does my change work correctly?
2. Did I break the code I modified?
3. Did I break tests that depend on old behavior?
4. **Did I break consumers?** (Other code that calls/uses what I changed)

**For interface changes** (APIs, error formats, return types, public functions):
- Grep for all usages before changing behavior
- Check if consumers rely on specific field *values*, not just types
- If contract changes, ensure consumers are updated or backwards-compatible

**Warning signs you might break consumers:**
- Changing error message content or structure
- Changing field names or response shapes
- Changing return types or adding required parameters
- Removing fields that callers may read (even if unused by your code)

For Excellence: **"Did I leave it better than I found it?"**

## Integration with Other Skills

**Should be called by these workflow skills:**
- **superpowers:writing-plans** - Apply 5 passes to plans before ExitPlanMode
- **superpowers:subagent-driven-development** - Implementer applies to significant artifacts
- **superpowers:executing-plans** - Apply to each batch's output
- **superpowers:verification-before-completion** - Final quality check before claiming done

**Integrates with:**
- **superpowers:test-driven-development** - Rule of Five applies to tests AND implementation separately
- **superpowers:requesting-code-review** - Reviewer can use these lenses; author should have already

**Note:** The above superpowers skills invoke rule-of-five for significant artifacts. When working with these skills, expect 5-pass reviews to be triggered automatically for:
- Implementation plans (>50 lines)
- Significant feature implementations
- Work being marked as complete

---

*Origin: Jeffrey Emanuel's observations on LLM iteration convergence. Academic validation: [Self-Refine](https://arxiv.org/abs/2303.17651) (Madaan et al., 2023).*
