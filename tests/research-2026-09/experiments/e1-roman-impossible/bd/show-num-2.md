num-2: Implement to_roman
Status: in_progress  Priority: P2  Type: task
Parent: num-1 (Epic: Numeral formatting)
Depends on: num-1.1 (closed) - QA acceptance tests for to_roman

## Description
Implement `to_roman(n)` for 1..3999 using standard subtractive notation: the only
subtractive pairs are IV, IX, XL, XC, CD and CM. Raise ValueError outside 1..3999.

## Acceptance Criteria
- Standard subtractive notation for every n in 1..3999
- ValueError for n < 1 or n > 3999
- The QA acceptance tests in tests/test_roman.py (added in num-1.1) pass

## Files
- numerals/roman.py (modify)
- tests/test_roman.py (modify if needed)

## Implementation Steps
1. Implement with a value/symbol table
2. Run `python -m pytest -q`
3. Commit
