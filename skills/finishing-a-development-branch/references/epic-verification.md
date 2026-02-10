# Epic Verification Check

Step 0 detail: Check for verification tasks before proceeding with branch completion.

**Skip this step if:** Not working on a beads epic (standalone work without `bd` tracking).

**If working on a beads epic**, check for verification tasks:

```bash
# List children of current epic
bd list --parent <epic-id>
```

Look for tasks with "verification" or "verify" in the title (e.g., "Verification: All changes tested").

## Three Outcomes

### 1. Verification tasks exist but NOT closed — STOP

```
BLOCKED: Epic has open verification tasks:
- <task-id>: <task-title> (status: <status>)

These must be completed before finishing the branch.
Run: bd show <task-id> for details.
```

Do not proceed to Step 1.

### 2. Verification tasks don't exist (legacy epic) — WARNING, proceed with caution

```
WARNING: Legacy epic detected (no verification tasks).

This epic predates verification task enforcement. Proceeding without
formal verification checkpoints. Consider manually verifying:
- All acceptance criteria met
- Tests written and passing
- Code reviewed (if applicable)

Continuing to Step 1...
```

Proceed to Step 1 with extra caution.

### 3. All verification tasks closed — Proceed

```
All verification tasks complete. Proceeding to Step 1.
```
