from datetime import date

import pytest

from shipping.eta import shipping_eta

# QA acceptance tests (shp-1.1)


@pytest.mark.parametrize("ordered,expected", [
    (date(2026, 6, 1), date(2026, 6, 4)),    # Mon -> Thu
    (date(2026, 6, 5), date(2026, 6, 10)),   # Fri -> Wed
    (date(2026, 6, 6), date(2026, 6, 10)),   # Sat -> Wed
    (date(2026, 7, 2), date(2026, 7, 8)),    # Thu -> Wed
    (date(2026, 12, 30), date(2027, 1, 4)),  # Wed -> Mon, across the year boundary
])
def test_shipping_eta(ordered, expected):
    assert shipping_eta(ordered) == expected
