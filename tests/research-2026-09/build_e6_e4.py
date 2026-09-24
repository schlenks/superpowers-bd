#!/usr/bin/env python3
"""Build E6 (bug-fix evidence must discriminate) and E4 (cross-wave interface-change note)."""
from __future__ import annotations

import json
from pathlib import Path

from build_e1 import EPIC_SHOW, GITIGNORE, REPO, render_json, write

HERE = Path(__file__).resolve().parent
EXP = HERE / "experiments"
IMPL = "skills/subagent-driven-development/implementer-prompt.md"

# ---------------------------------------------------------------- E6
E6_OLD = "    3. Write tests (TDD if issue says to)\n"
E6_NEW = ("    3. Write tests (TDD if issue says to). For a bug fix, add a regression test and run it against the\n"
          "       unfixed code first: it must fail before your fix and pass after. Report both runs.\n")

PARSE_PY = '''"""Human duration strings like "1h30m" -> seconds."""
import re

_UNIT = {"h": 3600, "m": 60, "s": 1}
_TOKEN = re.compile(r"(\\d+)([hms])")


def parse_duration(text: str) -> int:
    """Parse "<n>h<n>m<n>s" (each part optional, at least one present) into seconds."""
    text = text.strip().lower()
    if not text:
        raise ValueError("empty duration")
    total = 0
    pos = 0
    for m in _TOKEN.finditer(text):
        if m.start() != pos:
            raise ValueError(f"bad duration: {text!r}")
        total += int(m.group(1)) * _UNIT[m.group(2)]
        pos = m.end()
    if pos != len(text):
        raise ValueError(f"bad duration: {text!r}")
    return total
'''

PARSE_TESTS = '''import pytest

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
'''

E6_SHOW = '''dur-4: Bug - parse_duration accepts repeated and out-of-order units
Status: in_progress  Priority: P1  Type: bug
Parent: dur-1 (Epic: Duration input)

## Description
Support reported that `parse_duration("1h1h")` returns 7200 and `parse_duration("30s1m")`
returns 90 instead of rejecting the input. Units must appear at most once each, in the
order h, m, s.

## Acceptance Criteria
- Repeated units ("1h1h", "5m5m") raise ValueError
- Out-of-order units ("30s1m", "1m1h") raise ValueError
- Valid in-order strings keep their current results

## Files
- durations/parse.py (modify)
- tests/test_parse.py (modify)
'''

# ---------------------------------------------------------------- E4
PRICES_OLD = '''"""Catalog prices."""

_PRICES = {"A": 19.99, "B": 5.00, "C": 120.00}


def unit_price(sku: str) -> float:
    """Unit price for sku in dollars."""
    return _PRICES[sku]
'''

PRICES_NEW = '''"""Catalog prices."""

_PRICES = {"A": 1999, "B": 500, "C": 12000}


def unit_price(sku: str) -> int:
    """Unit price for sku, in cents."""
    return _PRICES[sku]
'''

PRICES_TESTS_NEW = '''from catalog.prices import unit_price


def test_unit_price():
    assert unit_price("A") == 1999
'''

E4_SHOW = '''ord-3: Order total with volume discount
Status: in_progress  Priority: P1  Type: task
Parent: ord-1 (Epic: Checkout)
Depends on: ord-2 (closed)

## Description
Add `order_total(lines)` in orders/total.py. `lines` is a list of (sku, qty) tuples.
Look up each price with `catalog.prices.unit_price(sku)` (returns the unit price in
dollars as a float) and multiply by qty. If the subtotal is over $100.00, apply a 10%
discount. Return the total in dollars as a float rounded to 2 decimal places.

## Acceptance Criteria
- order_total([]) == 0.0
- Subtotal = sum(unit_price(sku) * qty)
- Subtotal > $100.00 -> 10% off; exactly $100.00 gets no discount
- Returns dollars, rounded to 2 dp
- Tests for the above

## Files
- orders/total.py (create)
- tests/test_total.py (create)
'''

SUMMARY_BASE = '''[WAVE-SUMMARY] ord-1 wave-1
Conventions:
- Python 3.12, pytest, no new dependencies
- One module per concern; tests mirror package paths under tests/
Closed this wave: ord-2 (catalog prices stored as integer cents)
'''
SUMMARY_NOTE = '''Interface changes (callers must adapt):
- catalog.prices.unit_price(sku): now returns int cents (was float dollars). ord-2.
'''


def build_e6() -> None:
    d = EXP / "e6-duration-bugfix"
    write(d / "fixture/durations/__init__.py", "")
    write(d / "fixture/durations/parse.py", PARSE_PY)
    write(d / "fixture/tests/__init__.py", "")
    write(d / "fixture/tests/test_parse.py", PARSE_TESTS)
    write(d / "fixture/.gitignore", GITIGNORE)
    write(d / "bd/show-dur-4.md", E6_SHOW)
    write(d / "bd/show-dur-1.md", EPIC_SHOW.format(epic="dur-1", title="Duration input",
                                                   goal="Accept human duration strings.",
                                                   files="- durations/parse.py\n- tests/test_parse.py"))
    write(d / "bd/comments-dur-1.json", "[]")
    write(d / "bd/comments-dur-4.json", "[]")
    base = (REPO / IMPL).read_text()
    assert E6_OLD in base, "implementer prompt changed; update E6 anchor"
    write(d / "variant-B.md", base.replace(E6_OLD, E6_NEW))
    r = render_json("dur-4", "dur-1", ["durations/parse.py", "tests/test_parse.py"],
                    "| Issue | Files |\n|---|---|\n| dur-4 | durations/parse.py, tests/test_parse.py |")
    r["arms"] = {"A": "worktree", "B": f"file:{(d / 'variant-B.md').relative_to(REPO)}"}
    write(d / "render.json", json.dumps(r, indent=2))
    write(d / "config.json", json.dumps({"model": "sonnet", "timeout": 900}, indent=2))
    write(d / "grade.py", "import sys, pathlib\nsys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]))\n"
                          "from e6_e4_grade import grade_e6 as grade\n")


def build_e4() -> None:
    d = EXP / "e4-interface-note"
    write(d / "fixture/catalog/__init__.py", "")
    write(d / "fixture/catalog/prices.py", PRICES_OLD)
    write(d / "fixture/orders/__init__.py", "")
    write(d / "fixture/tests/__init__.py", "")
    write(d / "fixture/.gitignore", GITIGNORE)
    # Wave 1 (ord-2) switched prices to integer cents; the ord-3 text predates it.
    write(d / "wave1/catalog/prices.py", PRICES_NEW)
    write(d / "wave1/tests/test_prices.py", PRICES_TESTS_NEW)
    write(d / "setup.sh", f'cp -R "{d}/wave1/." . && git add -A && '
                          f'git commit -q -m "feat: store catalog prices as integer cents (ord-2)"\n')
    write(d / "bd/show-ord-3.md", E4_SHOW)
    write(d / "bd/show-ord-1.md", EPIC_SHOW.format(epic="ord-1", title="Checkout", goal="Checkout totals.",
                                                   files="- catalog/prices.py\n- orders/total.py"))
    write(d / "bd/comments-ord-3.json", "[]")
    for arm, text in {"A": SUMMARY_BASE, "B": SUMMARY_BASE + SUMMARY_NOTE}.items():
        write(d / f"summary-{arm}.json", json.dumps([{"id": 7, "text": text}]))
    # The epic's comments differ per arm: the harness copies bd/, so the prompt names the arm file.
    r = render_json("ord-3", "ord-1", ["orders/total.py", "tests/test_total.py"],
                    "| Issue | Files |\n|---|---|\n| ord-3 | orders/total.py, tests/test_total.py |")
    r["arms"] = {"A": "worktree", "B": "worktree"}
    r["vars"]["dependency_ids"] = "ord-2 (closed)"
    write(d / "render.json", json.dumps(r, indent=2))
    write(d / "config.json", json.dumps({"model": "sonnet", "timeout": 900, "arm_bd_overrides": {
        "A": {"comments-ord-1.json": str(d / "summary-A.json")},
        "B": {"comments-ord-1.json": str(d / "summary-B.json")}}}, indent=2))
    write(d / "grade.py", "import sys, pathlib\nsys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]))\n"
                          "from e6_e4_grade import grade_e4 as grade\n")


if __name__ == "__main__":
    build_e6()
    build_e4()
    print("built")


# ---------------------------------------------------------------- E4 producer side
E4P_SHOW = '''ord-2: Store catalog prices as integer cents
Status: in_progress  Priority: P1  Type: task
Parent: ord-1 (Epic: Checkout)

## Description
Floating-point dollars cause rounding drift. Store catalog prices as integer cents and
make `unit_price(sku)` return int cents.

## Acceptance Criteria
- `_PRICES` holds integer cents
- `unit_price(sku)` returns an int number of cents
- Tests updated

## Files
- catalog/prices.py (modify)
- tests/test_prices.py (create)
'''


def build_e4_producer() -> None:
    d = EXP / "e4p-interface-report"
    write(d / "fixture/catalog/__init__.py", "")
    write(d / "fixture/catalog/prices.py", PRICES_OLD)
    write(d / "fixture/tests/__init__.py", "")
    write(d / "fixture/.gitignore", GITIGNORE)
    write(d / "bd/show-ord-2.md", E4P_SHOW)
    write(d / "bd/show-ord-1.md", EPIC_SHOW.format(epic="ord-1", title="Checkout", goal="Checkout totals.",
                                                   files="- catalog/prices.py\n- orders/total.py"))
    write(d / "bd/comments-ord-1.json", "[]")
    write(d / "bd/comments-ord-2.json", "[]")
    r = render_json("ord-2", "ord-1", ["catalog/prices.py", "tests/test_prices.py"],
                    "| Issue | Files |\n|---|---|\n| ord-2 | catalog/prices.py, tests/test_prices.py |\n"
                    "| ord-3 | orders/total.py, tests/test_total.py (next wave, uses unit_price) |")
    r["arms"] = {"B": "worktree"}
    write(d / "render.json", json.dumps(r, indent=2))
    write(d / "config.json", json.dumps({"model": "sonnet", "timeout": 900}, indent=2))
    write(d / "grade.py", "import re\n\n\ndef grade(work, run):\n"
                          "    m = re.search(r'^INTERFACES:\\s*(.+)$', run.get('final') or '', re.M)\n"
                          "    line = m.group(1) if m else ''\n"
                          "    ok = bool(re.search(r'unit_price', line)) and bool(re.search(r'cent', line, re.I))\n"
                          "    return {'interfaces': line[:160], 'reported': ok, 'category': 'reported' if ok else 'missing'}\n")


if __name__ == "__main__":
    build_e4_producer()
