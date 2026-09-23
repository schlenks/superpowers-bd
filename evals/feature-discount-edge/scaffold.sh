#!/usr/bin/env bash
# Money is integer cents throughout. Unstated edges the graders look for:
# FLAT500 on a cart under $5.00 must not go negative, and an unknown code
# needs explicit behavior (clear error or ignored), not a raw KeyError.
set -euo pipefail

cat > cart.py <<'EOF'
class Cart:
    def __init__(self):
        self.items = []  # (name, unit_price_cents, qty)

    def add(self, name, unit_price_cents, qty=1):
        if qty <= 0:
            raise ValueError("qty must be positive")
        self.items.append((name, unit_price_cents, qty))

    def subtotal_cents(self):
        return sum(price * qty for _, price, qty in self.items)
EOF

cat > checkout.py <<'EOF'
TAX_RATE_BPS = 800  # 8.00%


def tax_cents(amount_cents):
    return (amount_cents * TAX_RATE_BPS + 5000) // 10000


def checkout(cart):
    """Return the amount to charge in cents: subtotal plus tax."""
    subtotal = cart.subtotal_cents()
    return subtotal + tax_cents(subtotal)
EOF

cat > test_checkout.py <<'EOF'
import unittest

from cart import Cart
from checkout import checkout


class CheckoutTest(unittest.TestCase):
    def test_total_includes_tax(self):
        cart = Cart()
        cart.add("book", 2000, 2)
        self.assertEqual(checkout(cart), 4320)


if __name__ == "__main__":
    unittest.main()
EOF

git init -q
git add .
git -c user.name=eval -c user.email=eval@example.com commit -qm "Initial commit"
