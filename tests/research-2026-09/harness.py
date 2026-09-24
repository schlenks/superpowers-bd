#!/usr/bin/env python3
"""A/B harness for prompt/skill experiments (2026-09 research follow-up).

Each experiment lives in experiments/<name>/ with:
  fixture/            files copied into a fresh git repo per run
  setup.sh            optional; runs inside the workdir after the initial commit
  bd/                 stub beads data: show-<id>.md, comments-<id>.json
  prompt-<arm>.md     the full prompt sent to `claude -p` for that arm
  grade.py            defines grade(workdir: Path, run: dict) -> dict
  config.json         {"model": "...", "effort": "...", "timeout": secs}

Runs are isolated: workdirs live outside the repo (no project CLAUDE.md),
`--setting-sources project` keeps user plugins/hooks out, and a stub `bd`
on PATH serves the task text. User-level CLAUDE.md still loads (same for all arms).
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_RUN_ROOT = Path(os.environ.get("RESEARCH_RUN_ROOT", "/private/tmp/sbd-research-runs"))

BD_STUB = r"""#!/usr/bin/env bash
# Minimal beads stub for experiments. Data dir: $BD_STUB_DIR
set -u
d="$BD_STUB_DIR"
case "${1:-}" in
  show)
    f="$d/show-${2:-}.md"; [ -f "$f" ] && cat "$f" || { echo "issue ${2:-} not found" >&2; exit 1; } ;;
  comments)
    if [ "${2:-}" = "add" ]; then
      id="${3:-}"; shift 3
      file=""; while [ $# -gt 0 ]; do [ "$1" = "-f" ] && file="$2"; shift; done
      mkdir -p "$d/added"; ts=$(date +%s%N)
      if [ -n "$file" ] && [ -f "$file" ]; then cp "$file" "$d/added/$id-$ts.md"; else echo "(inline)" > "$d/added/$id-$ts.md"; fi
      echo "Comment added to $id"
    else
      # Seeded comments plus anything added this run, as a JSON array of {id, text}.
      id="${2:-}"; f="$d/comments-$id.json"; seeded="[]"; [ -f "$f" ] && seeded=$(cat "$f")
      added="[]"
      if ls "$d/added/$id-"*.md >/dev/null 2>&1; then
        added=$(for c in "$d/added/$id-"*.md; do jq -Rs '{text: .}' "$c"; done | jq -s 'to_entries | map({id: (.key + 100), text: .value.text})')
      fi
      jq -n --argjson a "$seeded" --argjson b "$added" '$a + $b'
    fi ;;
  *) echo "bd stub: unsupported command: $*" >&2; exit 0 ;;
esac
"""


def load_grader(exp_dir: Path):
    spec = importlib.util.spec_from_file_location(f"grade_{exp_dir.name}", exp_dir / "grade.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    return mod


def sh(cmd: list[str], cwd: Path, env=None, check=True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, env=env, check=check, capture_output=True, text=True)


def prepare_workdir(exp_dir: Path, run_dir: Path, overrides: dict | None = None) -> tuple[Path, Path]:
    work = run_dir / "work"
    shutil.copytree(exp_dir / "fixture", work)
    stub_data = run_dir / "bd-data"
    if (exp_dir / "bd").exists():
        shutil.copytree(exp_dir / "bd", stub_data)
    else:
        stub_data.mkdir()
    for name, src in (overrides or {}).items():  # per-arm bd data, e.g. a different WAVE-SUMMARY
        shutil.copy(src, stub_data / name)
    shim = run_dir / "shim"
    shim.mkdir()
    (shim / "bd").write_text(BD_STUB)
    (shim / "bd").chmod(0o755)
    git_env = {**os.environ, "GIT_AUTHOR_NAME": "fixture", "GIT_AUTHOR_EMAIL": "fixture@example.com",
               "GIT_COMMITTER_NAME": "fixture", "GIT_COMMITTER_EMAIL": "fixture@example.com"}
    sh(["git", "init", "-q", "-b", "main"], work)
    sh(["git", "add", "-A"], work, env=git_env)
    sh(["git", "commit", "-q", "-m", "fixture baseline"], work, env=git_env)
    if (exp_dir / "setup.sh").exists():
        sh(["bash", str(exp_dir / "setup.sh")], work, env={**git_env, "BD_STUB_DIR": str(stub_data)})
    base = sh(["git", "rev-parse", "HEAD"], work).stdout.strip()
    (run_dir / "base_sha").write_text(base)
    return work, shim


def parse_transcript(path: Path) -> dict:
    result: dict = {}
    tool_calls: list[dict] = []
    for line in path.read_text().splitlines():
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if ev.get("type") == "assistant":
            for block in ev.get("message", {}).get("content", []) or []:
                if block.get("type") == "tool_use":
                    tool_calls.append({"name": block.get("name"), "input": block.get("input")})
        if ev.get("type") == "result":
            result = ev
    usage = result.get("usage", {}) or {}
    return {
        "final": result.get("result", ""),
        "is_error": result.get("is_error"),
        "cost_usd": result.get("total_cost_usd"),
        "num_turns": result.get("num_turns"),
        "duration_ms": result.get("duration_ms"),
        "output_tokens": usage.get("output_tokens"),
        "input_tokens": (usage.get("input_tokens") or 0) + (usage.get("cache_creation_input_tokens") or 0)
        + (usage.get("cache_read_input_tokens") or 0),
        "tool_calls": tool_calls,
    }


def one_run(exp_dir: Path, arm: str, idx: int, out_root: Path, cfg: dict, grader) -> dict:
    run_dir = out_root / f"{arm}-{idx:02d}"
    if run_dir.exists():
        shutil.rmtree(run_dir)
    run_dir.mkdir(parents=True)
    work, shim = prepare_workdir(exp_dir, run_dir, cfg.get("arm_bd_overrides", {}).get(arm))
    prompt = (exp_dir / f"prompt-{arm}.md").read_text()
    env = {**os.environ, "PATH": f"{shim}:{os.environ['PATH']}", "BD_STUB_DIR": str(run_dir / "bd-data")}
    cmd = ["claude", "-p", prompt, "--model", cfg["model"], "--output-format", "stream-json", "--verbose",
           "--permission-mode", "bypassPermissions", "--setting-sources", "project", "--no-session-persistence"]
    if cfg.get("effort"):
        cmd += ["--effort", cfg["effort"]]
    transcript = run_dir / "transcript.jsonl"
    t0 = time.time()
    timed_out = False
    with transcript.open("w") as fh:
        try:
            subprocess.run(cmd, cwd=work, env=env, stdout=fh, stderr=subprocess.DEVNULL,
                           timeout=cfg.get("timeout", 1200))
        except subprocess.TimeoutExpired:
            timed_out = True
    run = parse_transcript(transcript)
    run.update({"arm": arm, "idx": idx, "timed_out": timed_out, "wall_s": round(time.time() - t0, 1),
                "base_sha": (run_dir / "base_sha").read_text(), "run_dir": str(run_dir)})
    try:
        run["grade"] = grader.grade(work, run)
    except Exception as e:  # grading bugs must not kill the batch
        run["grade"] = {"grader_error": repr(e)}
    slim = {k: v for k, v in run.items() if k != "tool_calls"}
    slim["n_tool_calls"] = len(run["tool_calls"])
    (run_dir / "run.json").write_text(json.dumps(slim, indent=2))
    return slim


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("experiment")
    ap.add_argument("--arms", default="A,B")
    ap.add_argument("-n", type=int, default=10)
    ap.add_argument("--start", type=int, default=0, help="first run index (to extend a batch)")
    ap.add_argument("-j", type=int, default=4, help="concurrency")
    ap.add_argument("--model")
    ap.add_argument("--tag", default="")
    args = ap.parse_args()

    exp_dir = HERE / "experiments" / args.experiment
    cfg = json.loads((exp_dir / "config.json").read_text())
    if args.model:
        cfg["model"] = args.model
    grader = load_grader(exp_dir)
    tag = args.tag or cfg["model"]
    out_root = DEFAULT_RUN_ROOT / args.experiment / tag
    out_root.mkdir(parents=True, exist_ok=True)
    results_file = HERE / "results" / f"{args.experiment}--{tag}.jsonl"
    results_file.parent.mkdir(exist_ok=True)

    arms = args.arms.split(",")
    # Interleave arms so drift over time affects both equally.
    jobs = [(arm, i) for i in range(args.start, args.start + args.n) for arm in arms]
    print(f"{args.experiment}: {len(jobs)} runs, model={cfg['model']} effort={cfg.get('effort')}", flush=True)
    with cf.ThreadPoolExecutor(max_workers=args.j) as ex, results_file.open("a") as out:
        futs = {ex.submit(one_run, exp_dir, arm, i, out_root, cfg, grader): (arm, i) for arm, i in jobs}
        for fut in cf.as_completed(futs):
            arm, i = futs[fut]
            try:
                r = fut.result()
            except Exception as e:
                r = {"arm": arm, "idx": i, "harness_error": repr(e)}
            out.write(json.dumps(r) + "\n")
            out.flush()
            print(f"  {arm}-{i:02d} cost=${r.get('cost_usd')} grade={json.dumps(r.get('grade'))}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
