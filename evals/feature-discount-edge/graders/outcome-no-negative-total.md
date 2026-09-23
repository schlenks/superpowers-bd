---
type: llm
weight: 2
focus:
  source: file
  path: discounts.py
---

PASS if the discount logic cannot produce a negative amount: a fixed `FLAT500` discount on a subtotal below 500 cents is capped at the subtotal (clamped to zero), or is explicitly rejected with a clear error.

FAIL if subtracting 500 cents from a smaller subtotal would yield a negative number, or if `discounts.py` is missing.
