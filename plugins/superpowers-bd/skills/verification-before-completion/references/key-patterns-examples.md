# Key Verification Patterns

**Tests:**
```
@ [Run test command] [See: 34/34 pass] "All tests pass"
X "Should pass now" / "Looks correct"
```

**Regression tests (TDD Red-Green):**
```
@ Write -> Run (pass) -> Revert fix -> Run (MUST FAIL) -> Restore -> Run (pass)
X "I've written a regression test" (without red-green verification)
```

**Build:**
```
@ [Run build] [See: exit 0] "Build passes"
X "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
@ Re-read plan -> Create checklist -> Verify each -> Report gaps or completion
X "Tests pass, phase complete"
```

**Agent delegation:**
```
@ Agent reports success -> Check VCS diff -> Verify changes -> Report actual state
X Trust agent report
```

**Visual (frontend):**
```
@ [Navigate to page] [Check console: 0 errors] [Elements render] "UI verified"
X "Build passed" / "Tests pass" (neither proves UI renders correctly)
```
