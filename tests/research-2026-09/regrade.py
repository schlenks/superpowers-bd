#!/usr/bin/env python3
"""Re-grade finished runs (after a grader fix) without re-running the model.

usage: regrade.py <experiment> <tag>   -> rewrites results/<experiment>--<tag>.jsonl
"""
import json
import sys
from pathlib import Path

import harness

exp, tag = sys.argv[1], sys.argv[2]
exp_dir = harness.HERE / "experiments" / exp
grader = harness.load_grader(exp_dir)
out = harness.HERE / "results" / f"{exp}--{tag}.jsonl"
rows = []
for run_dir in sorted((harness.DEFAULT_RUN_ROOT / exp / tag).iterdir()):
    if not (run_dir / "run.json").exists():
        continue
    slim = json.loads((run_dir / "run.json").read_text())
    full = {**slim, **harness.parse_transcript(run_dir / "transcript.jsonl")}
    slim["grade"] = grader.grade(run_dir / "work", full)
    (run_dir / "run.json").write_text(json.dumps(slim, indent=2))
    rows.append(slim)
out.write_text("".join(json.dumps(r) + "\n" for r in rows))
print(f"regraded {len(rows)} runs -> {out.name}")
