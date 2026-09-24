"""Grader for E5/E7 (spec reviewer ordering / criteria checklist)."""
from __future__ import annotations

import re
from pathlib import Path

from common import reports, verdict

GAP6_RE = re.compile(r"password_contains_email|local[- ]part|criterion 6|criteria 6|#6\b|\b6\.\s*FAIL", re.I)
GAP2_RE = re.compile(r"lower(case|ed|\(\))|case[- ]insensitive normali|criterion 2|#2\b|\b2\.\s*FAIL", re.I)


def spec_report(work: Path) -> str:
    """The reviewer's own [SPEC-REVIEW] text (excluding the seeded IMPL-REPORT)."""
    parts = [t for t in reports(work).split("[SPEC-REVIEW]")[1:]]
    return "\n".join(parts)


def grade_spec(work: Path, run: dict, gaps: bool) -> dict:
    final = run.get("final") or ""
    text = spec_report(work) + "\n" + final
    v = verdict(final)
    g = {"verdict": v, "report_found": bool(spec_report(work))}
    if gaps:
        g["gap6"] = bool(GAP6_RE.search(text))
        g["gap2"] = bool(GAP2_RE.search(text))
        g["both"] = g["gap6"] and g["gap2"] and v == "FAIL"
        g["category"] = "both" if g["both"] else ("one" if (g["gap6"] or g["gap2"]) and v == "FAIL" else "missed")
    else:
        g["category"] = "pass" if v == "PASS" else "false_fail"
    return g
