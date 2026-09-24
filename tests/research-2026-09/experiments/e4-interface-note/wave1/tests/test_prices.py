from catalog.prices import unit_price


def test_unit_price():
    assert unit_price("A") == 1999
