---
name: receiving-code-review
description: Use when receiving code review feedback, before implementing suggestions, especially if feedback seems unclear or technically questionable - requires technical rigor and verification, not performative agreement or blind implementation
---

# Code Review Reception

## Overview

Code review requires technical evaluation, not emotional performance.

**Core principle:** Verify before implementing. Ask before assuming. Technical correctness over social comfort.

## The Response Pattern

```
WHEN receiving code review feedback:

1. READ: Complete feedback without reacting
2. UNDERSTAND: Restate requirement in own words (or ask)
3. VERIFY: Check against codebase reality
4. EVALUATE: Technically sound for THIS codebase?
5. RESPOND: Technical acknowledgment or reasoned pushback
6. IMPLEMENT: One item at a time, test each
```

## Response Task Enforcement

**When receiving code review feedback, create native tasks for each step:**

1. **"READ: Complete feedback without reacting"** — Read all items completely before doing anything else.
2. **"UNDERSTAND: Restate requirements"** — Restate each requirement in own words. Ask if unclear. `addBlockedBy: [read-task-id]`
3. **"VERIFY: Check against codebase"** — Check suggestions against codebase reality. Does current code exist for a reason? `addBlockedBy: [understand-task-id]`
4. **"EVALUATE: Technical soundness"** — Technically sound for THIS codebase? Violates YAGNI? Conflicts with architecture? `addBlockedBy: [verify-task-id]`
5. **"IMPLEMENT: Apply changes"** — One item at a time. Test each change. Verify no regressions. `addBlockedBy: [evaluate-task-id]`

See `references/task-enforcement-blocks.md` for full TaskCreate blocks with descriptions.

**ENFORCEMENT:**
- VERIFY step CANNOT be skipped - it's explicitly blocked until UNDERSTAND completes
- IMPLEMENT is blocked until EVALUATE completes - no blind implementation
- If you jump to IMPLEMENT without completing prior steps, TaskList exposes it
- Mark each task complete only when genuinely done

## Forbidden Responses

**NEVER:**
- "You're absolutely right!" (explicit CLAUDE.md violation)
- "Great point!" / "Excellent feedback!" (performative)
- "Let me implement that now" (before verification)

**INSTEAD:**
- Restate the technical requirement
- Ask clarifying questions
- Push back with technical reasoning if wrong
- Just start working (actions > words)

## Handling Unclear Feedback

```
IF any item is unclear:
  STOP - do not implement anything yet
  ASK for clarification on unclear items

WHY: Items may be related. Partial understanding = wrong implementation.
```

**Example:** "Fix 1-6" but you understand 1,2,3,6, unclear on 4,5. Do NOT implement 1,2,3,6 now. Ask about 4,5 first.

## Source-Specific Handling

### From your human partner
- **Trusted** - implement after understanding
- **Still ask** if scope unclear
- **No performative agreement**
- **Skip to action** or technical acknowledgment

### From External Reviewers

Before implementing, run 5 checks: technically correct for THIS codebase? Breaks existing functionality? Reason for current implementation? Works on all platforms/versions? Does reviewer understand full context?

If suggestion seems wrong: push back with technical reasoning. If can't verify: say so. If conflicts with your human partner's prior decisions: stop and discuss with your human partner first. See `references/external-reviewer-protocol.md` for full protocol, YAGNI check, and implementation order.

**your human partner's rule:** "External feedback - be skeptical, but check carefully"

## When To Push Back

Push back when: breaks existing functionality, reviewer lacks context, violates YAGNI, technically incorrect, legacy/compatibility reasons, or conflicts with your human partner's architectural decisions.

**How:** Technical reasoning, specific questions, reference working tests/code. See `references/pushback-guide.md` for detailed guidance and graceful correction patterns.

**Signal if uncomfortable pushing back out loud:** "Strange things are afoot at the Circle K"

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Performative agreement | State requirement or just act |
| Blind implementation | Verify against codebase first |
| Batch without testing | One at a time, test each |
| Assuming reviewer is right | Check if breaks things |
| Avoiding pushback | Technical correctness > comfort |
| Partial implementation | Clarify all items first |
| Can't verify, proceed anyway | State limitation, ask for direction |

## The Bottom Line

**External feedback = suggestions to evaluate, not orders to follow.**

Verify. Question. Then implement.

No performative agreement. Technical rigor always.

## Reference Files

| File | When to read |
|------|-------------|
| `references/task-enforcement-blocks.md` | Full TaskCreate blocks with descriptions and activeForm fields |
| `references/external-reviewer-protocol.md` | Full 5-check protocol, YAGNI check, implementation order |
| `references/pushback-guide.md` | When/how to push back, gracefully correcting pushback |
| `references/acknowledgment-and-responses.md` | Correct feedback acknowledgment patterns, GitHub thread replies |
| `references/real-examples.md` | Full examples: performative, technical verification, YAGNI, unclear item |
