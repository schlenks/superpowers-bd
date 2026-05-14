# Test Verification Protocol

Step 1 detail: Task-tracked test verification before presenting completion options.

## TaskCreate Block

```
TaskCreate: "Verify all tests pass"
  description: "Run full test suite. Must capture actual output showing pass/fail. Cannot proceed with failing tests."
  activeForm: "Running test verification"
```

## Run Project's Test Suite

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

## Enforcement Rules

This task CANNOT be marked `completed` unless:
- Test command was run (fresh, in this message)
- Output shows 0 failures
- Exit code was 0

## If Tests Fail

```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed to Step 2. Leave verification task incomplete.

## If Tests Pass

- Mark verification task `completed`
- Continue to Step 2
