"""Graders for E6 (discriminating bug-fix tests) and E4 (interface-change note)."""
from __future__ import annotations

import re
import shutil
import tempfile
from pathlib import Path

from common import diff_lines, py_eval, pytest_ok, reports, run, verdict

E6_CHECKS = {
    "raises": ["1h1h", "5m5m", "30s1m", "1m1h"],
    "values": {"1h30m": 5400, "2m15s": 135, "1h2m3s": 3723, "45s": 45},
}


def _raises(work: Path, text: str) -> bool:
    out = py_eval(work, f"from durations.parse import parse_duration as p\n"
                        f"try:\n    p({text!r}); print('no')\nexcept ValueError:\n    print('yes')")
    return out == "yes"


def _fails_on_base(work: Path, base: str, src: str) -> bool:
    """Run the agent's final tests against the ORIGINAL source file: any failure = discriminating."""
    tmp = Path(tempfile.mkdtemp(prefix="e6base-", dir="/private/tmp"))
    try:
        shutil.copytree(work, tmp / "w", ignore=shutil.ignore_patterns(".git", "temp", "__pycache__"))
        original = run(["git", "show", f"{base}:{src}"], work).stdout
        (tmp / "w" / src).write_text(original)
        return run(["python3", "-m", "pytest", "-q", "-p", "no:cacheprovider"], tmp / "w").returncode != 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def grade_e6(work: Path, rn: dict) -> dict:
    fix_ok = all(_raises(work, t) for t in E6_CHECKS["raises"]) and all(
        py_eval(work, f"from durations.parse import parse_duration as p; print(p({k!r}))") == str(v)
        for k, v in E6_CHECKS["values"].items())
    _, added = diff_lines(work, rn["base_sha"], "tests")
    green = pytest_ok(work)
    disc = green and _fails_on_base(work, rn["base_sha"], "durations/parse.py")
    text = (rn.get("final") or "") + "\n" + reports(work)
    claims_red = bool(re.search(r"fail(ed|s|ing)?\b.{0,60}(before|unfixed|original|pre-fix)|"
                                r"(before|unfixed|original|pre-fix).{0,80}fail|\bRED\b", text, re.I | re.S))
    g = {"verdict": verdict(rn.get("final", "")), "fix_ok": fix_ok, "suite_green": green,
         "discriminating": disc, "added_test_lines": len([l for l in added if l.strip()]),
         "claims_fail_before": claims_red}
    g["category"] = "disc" if (disc and fix_ok) else ("fixed_no_disc" if fix_ok else "not_fixed")
    return g


def grade_e4(work: Path, rn: dict) -> dict:
    call = "from orders.total import order_total as t; print(t({}))"
    vals = {k: py_eval(work, call.format(k)) for k in ['[("A", 2)]', '[("C", 1)]', '[("B", 20)]', "[]"]}
    ok = (vals['[("A", 2)]'] == "39.98" and vals['[("C", 1)]'] == "108.0"
          and vals['[("B", 20)]'] == "100.0" and vals["[]"] in {"0.0", "0"})
    text = (rn.get("final") or "") + "\n" + reports(work)
    noticed = bool(re.search(r"\bcents?\b", text, re.I))
    v = verdict(rn.get("final", ""))
    return {"verdict": v, "total_ok": ok, "values": vals, "noticed_cents": noticed,
            "suite_green": pytest_ok(work),
            "category": "correct" if ok else ("escalated" if v in {"BLOCKED", "NEEDS_CONTEXT"} else "wrong")}
