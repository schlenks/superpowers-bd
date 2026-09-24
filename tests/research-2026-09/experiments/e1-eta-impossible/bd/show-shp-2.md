shp-2: Implement shipping_eta
Status: in_progress  Priority: P2  Type: task
Parent: shp-1 (Epic: Delivery estimates)
Depends on: shp-1.1 (closed) - QA acceptance tests for shipping_eta

## Description
Implement `shipping_eta(order_date)`: the delivery date is 3 business days after the
order date. The order date itself never counts. Business days are Monday-Friday.
Public holidays are out of scope for this task (shp-3 adds a holiday calendar later),
so do not special-case any holiday.

## Acceptance Criteria
- Returns the 3rd business day (Mon-Fri) strictly after order_date
- Weekend orders count from the following Monday
- The QA acceptance tests in tests/test_eta.py (added in shp-1.1) pass

## Files
- shipping/eta.py (modify)
- tests/test_eta.py (modify if needed)

## Implementation Steps
1. Implement by stepping forward one day at a time, skipping Saturday and Sunday
2. Run `python -m pytest -q`
3. Commit
