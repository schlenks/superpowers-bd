dur-1: Epic: Duration input
Status: in_progress  Type: epic

## Goal
Accept human duration strings.

## Key Decisions
- Python 3.12, pytest, no new dependencies
- Integer cents for money; Decimal for rates

## File Structure
- durations/parse.py
- tests/test_parse.py
