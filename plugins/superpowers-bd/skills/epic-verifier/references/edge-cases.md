# Edge Cases

## No Significant Artifacts (All Files <50 Lines Changed)

- Skip Rule-of-Five section
- Still run full engineering checklist
- Note in output: "No files exceeded 50-line threshold"

## Test Command Unknown

- Ask orchestrator for test command before dispatch
- If no tests exist, note: "No test suite - manual verification needed"

## Epic Has Only Verification/Review Tasks

- Still run verification (may be quick)
- Confirms meta-work was done properly
