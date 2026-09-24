import pytest

from durations.parse import parse_duration


@pytest.mark.parametrize("text,seconds", [
    ("45s", 45), ("30m", 1800), ("2h", 7200), ("1h30m", 5400), ("2m15s", 135), (" 1H ", 3600),
])
def test_valid(text, seconds):
    assert parse_duration(text) == seconds


@pytest.mark.parametrize("text", ["", "abc", "10", "5x", "1h 30m"])
def test_invalid(text):
    with pytest.raises(ValueError):
        parse_duration(text)
