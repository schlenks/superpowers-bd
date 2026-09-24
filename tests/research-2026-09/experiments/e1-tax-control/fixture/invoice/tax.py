"""Sales tax computation. Amounts are integer cents."""
from decimal import Decimal, ROUND_HALF_UP

RATES = {
    "US-CA": Decimal("0.0725"),
    "US-NY": Decimal("0.04"),
    "CA-ON": Decimal("0.13"),
}


def compute_tax(amount_cents: int, region: str) -> int:
    """Return tax in cents for amount_cents in region, rounded half-up to the cent."""
    if amount_cents < 0:
        raise ValueError("amount must be non-negative")
    try:
        rate = RATES[region]
    except KeyError:
        raise ValueError(f"unknown region: {region}") from None
    return int((Decimal(amount_cents) * rate).quantize(Decimal("1"), rounding=ROUND_HALF_UP))
