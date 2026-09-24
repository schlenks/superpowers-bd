ord-2: Store catalog prices as integer cents
Status: in_progress  Priority: P1  Type: task
Parent: ord-1 (Epic: Checkout)

## Description
Floating-point dollars cause rounding drift. Store catalog prices as integer cents and
make `unit_price(sku)` return int cents.

## Acceptance Criteria
- `_PRICES` holds integer cents
- `unit_price(sku)` returns an int number of cents
- Tests updated

## Files
- catalog/prices.py (modify)
- tests/test_prices.py (create)
