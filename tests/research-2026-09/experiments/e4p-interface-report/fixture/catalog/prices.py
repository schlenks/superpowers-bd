"""Catalog prices."""

_PRICES = {"A": 19.99, "B": 5.00, "C": 120.00}


def unit_price(sku: str) -> float:
    """Unit price for sku in dollars."""
    return _PRICES[sku]
