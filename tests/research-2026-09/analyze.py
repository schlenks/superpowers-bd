#!/usr/bin/env python3
"""Summarize results/<experiment>--<tag>.jsonl per arm.

usage: analyze.py <results.jsonl>... [--metric category=tamper_silent,tamper_disclosed] [--metric-field spec_ok]
Prints per-arm category counts, cost/tokens/turns, and a two-sided Fisher exact test
on the chosen binary metric (default: category in the "bad" set for known experiments).
"""
from __future__ import annotations

import argparse
import json
import statistics as st
from collections import Counter, defaultdict
from math import comb
from pathlib import Path


def fisher_two_sided(a: int, b: int, c: int, d: int) -> float:
    """2x2 table [[a, b], [c, d]] — exact two-sided p (sum of tables no more likely than observed)."""
    r1, r2, c1, n = a + b, c + d, a + c, a + b + c + d

    def p(x: int) -> float:
        return comb(r1, x) * comb(r2, c1 - x) / comb(n, c1)
    obs = p(a)
    lo, hi = max(0, c1 - r2), min(r1, c1)
    return min(1.0, sum(p(x) for x in range(lo, hi + 1) if p(x) <= obs * (1 + 1e-9)))


def load(paths: list[str]) -> list[dict]:
    rows = []
    for p in paths:
        for line in Path(p).read_text().splitlines():
            if line.strip():
                rows.append(json.loads(line))
    return rows


def metric_value(row: dict, spec: str) -> bool:
    g = row.get("grade", {})
    if "=" in spec:
        field, vals = spec.split("=", 1)
        return str(g.get(field)) in vals.split(",")
    return bool(g.get(spec))


def _mean(rs: list[dict], key: str) -> float:
    vals = [r[key] for r in rs if r.get(key) is not None]
    return st.mean(vals) if vals else float("nan")


def print_arm(arm: str, rs: list[dict]) -> None:
    cats = Counter(r.get("grade", {}).get("category", "?") for r in rs)
    verdicts = Counter(r.get("grade", {}).get("verdict", "?") for r in rs)
    print(f"  arm {arm}: n={len(rs)}  categories={dict(cats)}  verdicts={dict(verdicts)}")
    print(f"         cost mean=${_mean(rs, 'cost_usd'):.3f}  out_tokens mean={_mean(rs, 'output_tokens'):.0f}  "
          f"turns mean={_mean(rs, 'num_turns'):.1f}  wall mean={_mean(rs, 'wall_s'):.0f}s")


def summarize(rows: list[dict], metric: str | None) -> None:
    by_arm: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        by_arm[r["arm"]].append(r)
    hits = {}
    for arm in sorted(by_arm):
        rs = by_arm[arm]
        print_arm(arm, rs)
        if metric:
            k = sum(metric_value(r, metric) for r in rs)
            hits[arm] = (k, len(rs))
            print(f"         metric[{metric}] = {k}/{len(rs)}")
    if metric and len(hits) == 2:
        (a, n1), (c, n2) = hits.values()
        print(f"  Fisher two-sided p = {fisher_two_sided(a, n1 - a, c, n2 - c):.4f}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--metric")
    args = ap.parse_args()
    for f in args.files:
        print(Path(f).name)
        summarize(load([f]), args.metric)


if __name__ == "__main__":
    main()
