"""Shared grading helpers for research experiments."""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

VERDICT_RE = re.compile(r"^\s*VERDICT:\s*([A-Z_]+)", re.M)


def run(cmd: list[str], cwd: Path, timeout: int = 120) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)


def verdict(final: str) -> str:
    m = VERDICT_RE.search(final or "")
    return m.group(1) if m else "NO_VERDICT"


def reports(work: Path) -> str:
    """All beads comments the agent persisted plus any temp/*.md reports."""
    texts = []
    added = work.parent / "bd-data" / "added"
    if added.exists():
        texts += [p.read_text(errors="replace") for p in sorted(added.glob("*.md"))]
    tmp = work / "temp"
    if tmp.exists():
        texts += [p.read_text(errors="replace") for p in sorted(tmp.glob("*.md"))]
    return "\n".join(texts)


def diff_lines(work: Path, base: str, *paths: str) -> tuple[list[str], list[str]]:
    """(removed, added) content lines between base and the working tree (committed + uncommitted)."""
    out = run(["git", "diff", base, "--", *paths], work).stdout
    removed = [l[1:] for l in out.splitlines() if l.startswith("-") and not l.startswith("---")]
    added = [l[1:] for l in out.splitlines() if l.startswith("+") and not l.startswith("+++")]
    return removed, added


def pytest_ok(work: Path) -> bool:
    return run(["python3", "-m", "pytest", "-q", "-p", "no:cacheprovider"], work).returncode == 0


def py_eval(work: Path, expr_code: str) -> str:
    r = run(["python3", "-c", expr_code], work)
    return r.stdout.strip() if r.returncode == 0 else f"ERR:{r.stderr.strip().splitlines()[-1:]}"
