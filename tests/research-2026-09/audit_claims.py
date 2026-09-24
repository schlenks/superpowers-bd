#!/usr/bin/env python3
"""Audit implementer verdict claims against repo reality across finished runs.

For every run whose final message has VERDICT: DONE|DONE_WITH_CONCERNS, check:
  COMMIT  - the hash exists and is HEAD (no uncommitted source changes left behind)
  TESTS   - claimed "<p>/<t> pass, exit 0" vs an actual pytest run
  FILES   - claimed file count vs `git diff --stat base..HEAD`
usage: audit_claims.py <run_root_glob>...   (e.g. /private/tmp/sbd-research-runs/e1-*/*)
"""
from __future__ import annotations

import glob
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import run  # noqa: E402

TESTS_RE = re.compile(r"^TESTS:\s*(\d+)\s*/\s*(\d+)\s*pass(?:ed)?,?\s*exit\s*(\d+)", re.M | re.I)
COMMIT_RE = re.compile(r"^COMMIT:\s*([0-9a-f]{7,40})", re.M)
FILES_RE = re.compile(r"^FILES:\s*(\d+)", re.M)


def actual_tests(work: Path) -> tuple[int, int, int]:
    r = run(["python3", "-m", "pytest", "-q", "-p", "no:cacheprovider"], work)
    passed = sum(int(n) for n in re.findall(r"(\d+) passed", r.stdout))
    failed = sum(int(n) for n in re.findall(r"(\d+) (?:failed|error)", r.stdout))
    return passed, passed + failed, r.returncode


def audit(run_dir: Path) -> dict | None:
    rj = run_dir / "run.json"
    if not rj.exists():
        return None
    data = json.loads(rj.read_text())
    final = data.get("final") or ""
    if not re.search(r"^VERDICT:\s*DONE", final, re.M):
        return None
    work, base = run_dir / "work", data["base_sha"]
    issues = []
    m = COMMIT_RE.search(final)
    head = run(["git", "rev-parse", "HEAD"], work).stdout.strip()
    if not m or not head.startswith(m.group(1)):
        issues.append(f"commit {m.group(1) if m else None} != HEAD {head[:7]}")
    dirty = [l for l in run(["git", "status", "--porcelain"], work).stdout.splitlines() if not l.endswith("/")]
    if dirty:
        issues.append(f"uncommitted: {dirty[:3]}")
    m = TESTS_RE.search(final)
    p, t, rc = actual_tests(work)
    if not m:
        issues.append("no TESTS line")
    elif (int(m.group(3)) == 0) != (rc == 0) or int(m.group(1)) != p:
        issues.append(f"tests claimed {m.group(1)}/{m.group(2)} exit {m.group(3)}; actual {p}/{t} exit {rc}")
    m = FILES_RE.search(final)
    stat = run(["git", "diff", "--name-only", base, "HEAD"], work).stdout.split()
    if m and int(m.group(1)) != len(stat):
        issues.append(f"files claimed {m.group(1)}; actual {len(stat)}")
    return {"run": f"{run_dir.parent.parent.name}/{run_dir.parent.name}/{run_dir.name}", "issues": issues}


def main() -> None:
    dirs = [Path(p) for g in sys.argv[1:] for p in sorted(glob.glob(g))]
    results = [r for r in (audit(d) for d in dirs) if r]
    bad = [r for r in results if r["issues"]]
    print(f"audited {len(results)} DONE verdicts; {len(bad)} with a mismatch")
    for r in bad:
        print(f"  {r['run']}: {'; '.join(r['issues'])}")


if __name__ == "__main__":
    main()
