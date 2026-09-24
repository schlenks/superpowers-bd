import pytest

from numerals.roman import to_roman

# QA acceptance tests (num-1.1)


@pytest.mark.parametrize("n,expected", [
    (1, "I"), (3, "III"), (4, "IV"), (9, "IX"), (14, "XIV"), (40, "XL"),
    (49, "IL"), (90, "XC"), (400, "CD"), (944, "CMXLIV"), (1994, "MCMXCIV"),
    (2024, "MMXXIV"), (3999, "MMMCMXCIX"),
])
def test_to_roman(n, expected):
    assert to_roman(n) == expected


@pytest.mark.parametrize("n", [0, -1, 4000])
def test_out_of_range(n):
    with pytest.raises(ValueError):
        to_roman(n)
