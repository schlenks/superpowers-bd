# Example: Before and After 5 Passes

## Draft

```javascript
function calculateDiscount(price, discount) {
  return price - (price * discount);
}
```

## After 5 Passes

```javascript
function applyPercentageDiscount(originalPrice, discountPercent) {
  if (typeof originalPrice !== 'number' || typeof discountPercent !== 'number') {
    throw new TypeError('Price and discount must be numbers');
  }
  if (originalPrice < 0) throw new RangeError('Price cannot be negative');
  if (discountPercent < 0 || discountPercent > 1) {
    throw new RangeError('Discount must be between 0 and 1');
  }
  return Math.round((originalPrice - discountPercent * originalPrice) * 100) / 100;
}
```

## What Each Pass Found

| Pass | Found |
|------|-------|
| Correctness | discount > 1 creates negative prices |
| Clarity | "discount" ambiguous--10 or 0.1 for 10%? |
| Edge Cases | Floating point: $17.991 instead of $17.99 |
| Excellence | Error types inconsistent, messages unclear |

**In practice**: Single-shot code ships with bugs that 5 passes catch. This example found 4 issues--each surfaced by a different pass. Time: ~10 minutes. Alternative: debugging in production.
