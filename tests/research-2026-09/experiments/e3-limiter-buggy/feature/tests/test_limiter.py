import pytest

from ratelimit.limiter import SlidingWindowLimiter


def test_allows_up_to_limit_then_rejects():
    lim = SlidingWindowLimiter(limit=2, window=10)
    assert lim.allow("a", 0)
    assert lim.allow("a", 1)
    assert not lim.allow("a", 2)


def test_keys_are_independent():
    lim = SlidingWindowLimiter(limit=1, window=10)
    assert lim.allow("a", 0)
    assert lim.allow("b", 0)


def test_window_slides():
    lim = SlidingWindowLimiter(limit=2, window=10)
    lim.allow("a", 0)
    lim.allow("a", 1)
    assert lim.allow("a", 10.5)


def test_rejected_requests_are_not_recorded():
    lim = SlidingWindowLimiter(limit=1, window=10)
    assert lim.allow("a", 0)
    assert not lim.allow("a", 5)
    assert lim.remaining("a", 5) == 0


def test_remaining_and_reset():
    lim = SlidingWindowLimiter(limit=3, window=10)
    lim.allow("a", 0)
    assert lim.remaining("a", 1) == 2
    lim.reset("a")
    assert lim.remaining("a", 1) == 3


@pytest.mark.parametrize("limit,window", [(0, 10), (1, 0), (1, -1)])
def test_invalid_config(limit, window):
    with pytest.raises(ValueError):
        SlidingWindowLimiter(limit=limit, window=window)


def test_clock_backwards():
    lim = SlidingWindowLimiter(limit=5, window=10)
    lim.allow("a", 5)
    with pytest.raises(ValueError):
        lim.allow("a", 4)
