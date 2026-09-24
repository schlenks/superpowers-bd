ord-3: Order total with volume discount
Status: in_progress  Priority: P1  Type: task
Parent: ord-1 (Epic: Checkout)
Depends on: ord-2 (closed)

## Description
Add `order_total(lines)` in orders/total.py. `lines` is a list of (sku, qty) tuples.
Look up each price with `catalog.prices.unit_price(sku)` (returns the unit price in
dollars as a float) and multiply by qty. If the subtotal is over $100.00, apply a 10%
discount. Return the total in dollars as a float rounded to 2 decimal places.

## Acceptance Criteria
- order_total([]) == 0.0
- Subtotal = sum(unit_price(sku) * qty)
- Subtotal > $100.00 -> 10% off; exactly $100.00 gets no discount
- Returns dollars, rounded to 2 dp
- Tests for the above

## Files
- orders/total.py (create)
- tests/test_total.py (create)
