# Subagent-Driven Development - Behavior Tests

Manual test cases to verify context loading works correctly.

## Test 1: Epic Context Extraction

**Setup:**
1. Create epic with description:
   ```
   Build user authentication system.

   **Key Decisions:**
   - **JWT over sessions** — Stateless scaling
   - **bcrypt for passwords** — Industry standard
   - **24h token expiry** — Balance security/UX
   ```

**Expected:**
- `[EPIC_GOAL]` = "Build user authentication system."
- `[KEY_DECISIONS]` includes all 3 decisions with rationale

**Verify:**
- Implementer prompt contains epic goal in "Epic Context" section
- Key decisions appear with rationale, not just names

## Test 2: Wave Conventions Extraction

**Setup:**
1. Epic has wave summary comments:
   ```
   Wave 1 complete:
   - Closed: hub-abc.1, hub-abc.2
   - Conventions: camelCase JSON, uuid v4 IDs
   ```

**Expected:**
- `[WAVE_CONVENTIONS]` includes "camelCase JSON, uuid v4 IDs"

**Verify:**
- Implementer prompt contains conventions in "Established Conventions" section
- Wave 2 implementers see Wave 1 conventions

## Test 3: First Wave (No Conventions)

**Setup:**
1. Epic has no wave summary comments yet

**Expected:**
- `[WAVE_CONVENTIONS]` = "None yet (first wave)"

**Verify:**
- Implementer prompt indicates they are establishing conventions
- No empty section

## Test 4: Task Purpose Inference

**Setup:**
1. Epic goal: "Build user authentication system"
2. Task title: "Create User Model"

**Expected:**
- `[TASK_PURPOSE]` connects task to epic goal
- Example: "Provides the data model for user authentication"

**Verify:**
- Implementer understands how their task contributes
- Not just restating the task title
