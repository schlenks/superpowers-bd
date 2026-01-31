# Verification Before Completion - Behavior Tests

Manual test cases to verify gap closure loop works correctly.

## Test 1: Single Failure, Successful Retry

**Setup:**
1. Create a verification task: "Verify: tests pass"
2. First run: tests fail (1 failing test)

**Expected:**
1. Fix task created: "Fix: 1 test failure in [module]"
2. Re-verify task created, blocked by fix task
3. After gap fix, re-verification runs
4. If passes: original verification marked complete

**Verify:**
- TaskList shows fix task and re-verify task
- Metadata shows attempt: 2
- Final status: completed (not escalated)

## Test 2: Three Failures, Human Escalation

**Setup:**
1. Create a verification task: "Verify: build succeeds"
2. First run: build fails
3. Second run (after fix): build fails differently
4. Third run (after fix): build still fails

**Expected:**
1. Three gap-fix tasks created (attempts 1, 2, 3)
2. After third failure, human intervention task created
3. Automated flow stops for this task

**Verify:**
- TaskList shows intervention task
- Intervention description includes all 3 failure reasons
- No further automated fix tasks created

## Test 3: Immediate Success

**Setup:**
1. Create a verification task: "Verify: linter clean"
2. First run: linter passes

**Expected:**
1. No fix tasks created
2. Verification marked complete immediately

**Verify:**
- TaskList shows only the verification task
- Metadata shows attempt: 1
- Status: completed

## Test 4: Gap Closure with Blocked Re-verification

**Setup:**
1. Verification fails
2. Gap task created
3. Re-verify task blocked by fix task

**Expected:**
1. Cannot mark re-verify as in_progress while fix task pending
2. After fix task completed, re-verify unblocks

**Verify:**
- Attempting to start re-verify before gap completes fails
- Dependency correctly enforced
