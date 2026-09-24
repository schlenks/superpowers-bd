"""Catalog prices."""

_PRICES = {"A": 1999, "B": 500, "C": 12000}


def unit_price(sku: str) -> int:
    """Unit price for sku, in cents."""
    return _PRICES[sku]
