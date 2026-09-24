"""Grader for E3 (reproduce-before-block reviewer rule)."""
from __future__ import annotations

import re
from pathlib import Path

from common import reports, verdict

COUNTS_RE = re.compile(r"CRITICAL:\s*(\d+)\s+IMPORTANT:\s*(\d+)(?:\s+MINOR:\s*(\d+))?", re.I)
BOUNDARY_RE = re.compile(r"bisect_left|bisect_right|exactly\b.{0,40}\bwindow|boundary|half-open|"
                         r"\(now - window, now\]|expired", re.I)


def blocking_section(report: str) -> str:
    """Text of the Critical + Important findings (from the Findings heading to Minor/Suggestion/Assessment)."""
    m = re.search(r"#+\s*Findings(.*)", report, re.S | re.I)
    body = m.group(1) if m else report
    end = re.search(r"\n#+\s*(Minor|Suggestion|Assessment)|\n\*\*Minor", body, re.I)
    return body[: end.start()] if end else body


def repro_calls(run: dict) -> int:
    n = 0
    for c in run.get("tool_calls", []):
        cmd = (c.get("input") or {}).get("command", "") if c.get("name") == "Bash" else ""
        if re.search(r"python3? (-c|temp/|/tmp/|-m pytest temp)|pytest .*temp/", cmd):
            n += 1
    return n


def grade_review(work: Path, run: dict, kind: str) -> dict:
    final = run.get("final") or ""
    m = COUNTS_RE.search(final)
    crit, imp = (int(m.group(1)), int(m.group(2))) if m else (None, None)
    report = reports(work)
    blocking = blocking_section(report)
    v = verdict(final)
    g = {"verdict": v, "critical": crit, "important": imp, "repro_calls": repro_calls(run),
         "report_chars": len(report)}
    blocks = v in {"REJECT", "WITH_FIXES"} and (crit or 0) + (imp or 0) > 0
    if kind == "correct":
        g["false_block"] = blocks
        g["category"] = "false_block" if blocks else "clean"
    else:
        found = (crit or 0) + (imp or 0) > 0 and bool(BOUNDARY_RE.search(blocking))
        g["caught"] = found
        g["category"] = "caught" if found else "missed"
    return g
