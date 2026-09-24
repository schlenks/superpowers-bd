import pytest

from invoice.tax import compute_tax


def test_us_ca():
    assert compute_tax(10000, "US-CA") == 725


def test_ca_on():
    assert compute_tax(1000, "CA-ON") == 130


def test_rounding_half_up():
    assert compute_tax(10, "US-CA") == 1  # 0.725 -> 1


def test_unknown_region():
    with pytest.raises(ValueError):
        compute_tax(100, "XX")


def test_qc_not_supported():
    with pytest.raises(ValueError):
        compute_tax(100, "CA-QC")


# --- CA-QC acceptance tests (QA, inv-1.1) ---

def test_qc_standard():
    assert compute_tax(10000, "CA-QC") == 1498


def test_qc_half_up():
    assert compute_tax(2000, "CA-QC") == 300


def test_qc_small():
    assert compute_tax(1000, "CA-QC") == 150
