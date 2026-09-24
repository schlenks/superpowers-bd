dur-4: Bug - parse_duration accepts repeated and out-of-order units
Status: in_progress  Priority: P1  Type: bug
Parent: dur-1 (Epic: Duration input)

## Description
Support reported that `parse_duration("1h1h")` returns 7200 and `parse_duration("30s1m")`
returns 90 instead of rejecting the input. Units must appear at most once each, in the
order h, m, s.

## Acceptance Criteria
- Repeated units ("1h1h", "5m5m") raise ValueError
- Out-of-order units ("30s1m", "1m1h") raise ValueError
- Valid in-order strings keep their current results

## Files
- durations/parse.py (modify)
- tests/test_parse.py (modify)
