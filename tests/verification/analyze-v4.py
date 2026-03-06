#!/usr/bin/env python3
"""Statistical analyzer for V4 mixed-model review experiment.

Reads per-reviewer scores.csv and aggregates.csv produced by
test-mixed-model-v4.sh. Computes:

  - Aggregate scoring (union rule) -- primary endpoint
  - Wilcoxon signed-rank test on per-cycle aggregate delta_score
  - Bootstrap 95% CI on mean aggregate delta_score
  - CONFIRMED / PARTIAL / DENIED / INCONCLUSIVE verdict
  - VERIFIED / OBSERVED / INCONCLUSIVE decision class
  - Unique-find analysis (bugs found only by Opus reviewer per cycle)
  - Cost analysis (Opus ~5x Sonnet per token)
  - JSON summary output to <aggregates_dir>/mixed-model-v4-summary.json

Usage:
    python3 analyze-v4.py <scores.csv> <aggregates.csv>

Dependencies: numpy (2.1.0). No scipy required.

Statistical primitives (wilcoxon_signed_rank, bootstrap_ci) are imported
from analyze-v2.py via importlib since the filename is hyphenated.
"""

import csv
import importlib.util
import json
import math
import os
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np


# ---------------------------------------------------------------------------
# Import statistical primitives from analyze-v2.py (hyphenated filename)
# ---------------------------------------------------------------------------

def _load_analyze_v2():
    """Load analyze-v2.py via importlib (hyphen prevents normal import)."""
    candidates = [
        Path(__file__).parent / "analyze-v2.py",
        Path("tests/verification/analyze-v2.py"),
        Path("analyze-v2.py"),
    ]
    for path in candidates:
        if path.exists():
            spec = importlib.util.spec_from_file_location("analyze_v2", path)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            return mod
    return None


_v2 = _load_analyze_v2()
if _v2 is not None:
    wilcoxon_signed_rank = _v2.wilcoxon_signed_rank
    bootstrap_ci = _v2.bootstrap_ci
else:
    # Fallback: minimal local copies (analyze-v2.py not found on path)

    def bootstrap_ci(values, stat_fn=np.median, n_resamples=10_000, ci=0.95, seed=42):
        """Bootstrap CI. Fallback copy from analyze-v2.py."""
        values = np.asarray(values, dtype=float)
        n = len(values)
        if n == 0:
            return {"point_estimate": float("nan"), "ci_lower": float("nan"),
                    "ci_upper": float("nan"), "ci_level": ci, "n": 0,
                    "n_resamples": n_resamples}
        rng = np.random.default_rng(seed)
        point = float(stat_fn(values))
        indices = rng.integers(0, n, size=(n_resamples, n))
        stats = np.apply_along_axis(stat_fn, 1, values[indices])
        alpha = 1.0 - ci
        return {"point_estimate": point,
                "ci_lower": float(np.percentile(stats, 100 * alpha / 2)),
                "ci_upper": float(np.percentile(stats, 100 * (1 - alpha / 2))),
                "ci_level": ci, "n": n, "n_resamples": n_resamples}

    def _ncdf(z):
        return 0.5 * math.erfc(-z / math.sqrt(2))

    def _rank_ties(values):
        arr = np.asarray(values, dtype=float)
        n, order = len(arr), np.argsort(arr)
        ranks = np.empty(n, dtype=float)
        i = 0
        while i < n:
            j = i + 1
            while j < n and arr[order[j]] == arr[order[i]]:
                j += 1
            for k in range(i, j):
                ranks[order[k]] = (i + 1 + j) / 2.0
            i = j
        return ranks

    def wilcoxon_signed_rank(x, y):
        """Wilcoxon signed-rank. Fallback copy from analyze-v2.py."""
        x, y = np.asarray(x, dtype=float), np.asarray(y, dtype=float)
        if len(x) != len(y):
            raise ValueError(f"Length mismatch: {len(x)} vs {len(y)}")
        d = x - y
        d_nz = d[d != 0]
        n = len(d_nz)
        if n == 0:
            return {"T_plus": 0.0, "T_minus": 0.0, "T_stat": 0.0,
                    "n_nonzero": 0, "z_stat": float("nan"),
                    "p_value": 1.0, "sufficient": False,
                    "method": "no_nonzero_differences"}
        ranks = _rank_ties(np.abs(d_nz))
        t_plus = float(np.sum(ranks[d_nz > 0]))
        t_minus = float(np.sum(ranks[d_nz < 0]))
        t_stat = min(t_plus, t_minus)
        if n < 10:
            return {"T_plus": t_plus, "T_minus": t_minus, "T_stat": t_stat,
                    "n_nonzero": n, "z_stat": float("nan"),
                    "p_value": float("nan"), "sufficient": False,
                    "method": "insufficient_sample_size"}
        mean_t = n * (n + 1) / 4.0
        var_t = n * (n + 1) * (2 * n + 1) / 24.0
        _, counts = np.unique(np.abs(d_nz), return_counts=True)
        var_t -= sum(c * (c**2 - 1) / 48.0 for c in counts if c > 1)
        if var_t <= 0:
            return {"T_plus": t_plus, "T_minus": t_minus, "T_stat": t_stat,
                    "n_nonzero": n, "z_stat": 0.0, "p_value": 1.0,
                    "sufficient": True, "method": "normal_approximation_degenerate"}
        z = (t_stat - mean_t) / math.sqrt(var_t)
        return {"T_plus": t_plus, "T_minus": t_minus, "T_stat": t_stat,
                "n_nonzero": n, "z_stat": round(z, 4),
                "p_value": round(2.0 * (1.0 - _ncdf(abs(z))), 6),
                "sufficient": True, "method": "normal_approximation"}


# ---------------------------------------------------------------------------
# Ground truth constants (match test-mixed-model-v4.sh / V3 fixtures)
# ---------------------------------------------------------------------------

REAL_BUGS = [f"B{i}" for i in range(1, 13)]
TOTAL_BUGS = 12


# ---------------------------------------------------------------------------
# CSV I/O helpers
# ---------------------------------------------------------------------------

def _read_csv(path):
    """Read CSV and return list of dicts."""
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def _write_json(path, data):
    """Write data as formatted JSON."""
    with open(path, "w") as f:
        json.dump(data, f, indent=2, default=str)
    print(f"  Summary written to: {path}")


def _parse_ok(row):
    """Return True if the parse_ok column indicates a successful parse."""
    return row.get("parse_ok", "false").lower() in ("true", "1", "yes")


def _safe_parse_area(row):
    """Parse per_area_json from a row; return None on failure."""
    if not _parse_ok(row):
        return None
    try:
        return json.loads(row["per_area_json"])
    except (json.JSONDecodeError, KeyError):
        return None


def _sort_key(cycle_str):
    """Sort key for cycle strings: numeric if digit, lexicographic otherwise."""
    return int(cycle_str) if cycle_str.isdigit() else cycle_str


# ---------------------------------------------------------------------------
# Primary analysis helpers
# ---------------------------------------------------------------------------

def _group_aggregate_rows(aggregates_rows):
    """Parse aggregates.csv rows into {cycle: {condition: data | None}}."""
    by_cycle = defaultdict(dict)
    for row in aggregates_rows:
        cycle, condition = row["cycle"], row["condition"]
        if not _parse_ok(row):
            by_cycle[cycle][condition] = None
            continue
        try:
            by_cycle[cycle][condition] = {
                "score": float(row["score"]),
                "tp": float(row["tp"]),
                "fp": float(row["fp"]),
                "fn": float(row.get("fn", 0) or 0),
                "precision": float(row["precision"]) if row.get("precision") else None,
                "recall": float(row["recall"]) if row.get("recall") else None,
            }
        except (ValueError, KeyError):
            by_cycle[cycle][condition] = None
    return by_cycle


def _build_paired_arrays(by_cycle):
    """Extract parallel arrays for mixed and uniform from grouped rows.

    Returns:
        tuple: (n_paired, mixed_arr, uniform_arr, tp_mixed, tp_uniform,
                fp_mixed, fp_uniform, recall_mixed, recall_uniform)
    """
    paired = []
    scores_m, scores_u = [], []
    tp_m, tp_u, fp_m, fp_u, rec_m, rec_u = [], [], [], [], [], []

    for cycle in sorted(by_cycle.keys(), key=_sort_key):
        data = by_cycle[cycle]
        mixed = data.get("mixed")
        uniform = data.get("uniform")
        if mixed is None or uniform is None:
            continue
        paired.append(cycle)
        scores_m.append(mixed["score"])
        scores_u.append(uniform["score"])
        tp_m.append(mixed["tp"])
        tp_u.append(uniform["tp"])
        fp_m.append(mixed["fp"])
        fp_u.append(uniform["fp"])
        if mixed["recall"] is not None and uniform["recall"] is not None:
            rec_m.append(mixed["recall"])
            rec_u.append(uniform["recall"])

    return (
        len(paired),
        np.array(scores_m, dtype=float),
        np.array(scores_u, dtype=float),
        tp_m, tp_u, fp_m, fp_u, rec_m, rec_u,
    )


def _compute_primary_stats(n_paired, mixed_arr, uniform_arr, delta):
    """Compute descriptive statistics, Wilcoxon, and bootstrap CI.

    Returns:
        tuple: (scores_dict, stdev_ratio, wilcoxon_result, delta_ci)
    """
    nan = float("nan")
    mean_d = float(np.mean(delta)) if n_paired > 0 else nan
    mean_m = float(np.mean(mixed_arr)) if n_paired > 0 else nan
    mean_u = float(np.mean(uniform_arr)) if n_paired > 0 else nan
    stdev_m = float(np.std(mixed_arr, ddof=1)) if n_paired > 1 else 0.0
    stdev_u = float(np.std(uniform_arr, ddof=1)) if n_paired > 1 else 0.0
    pooled = (mean_m + mean_u) / 2 if n_paired > 0 else 1
    stdev_ratio = max(stdev_m, stdev_u) / abs(pooled) if abs(pooled) > 1e-9 else float("inf")

    wsr = wilcoxon_signed_rank(mixed_arr, uniform_arr)
    delta_ci = bootstrap_ci(delta, stat_fn=np.mean) if n_paired > 0 else bootstrap_ci([])

    scores = {
        "mean_uniform": round(mean_u, 4),
        "mean_mixed": round(mean_m, 4),
        "mean_delta": round(mean_d, 4),
        "stdev_uniform": round(stdev_u, 4),
        "stdev_mixed": round(stdev_m, 4),
        "stdev_ratio": round(stdev_ratio, 4),
    }
    return scores, stdev_ratio, wsr, delta_ci


def _ci_excludes_zero(delta_ci):
    """Return True if the bootstrap CI excludes zero on either side."""
    lo, hi = delta_ci["ci_lower"], delta_ci["ci_upper"]
    return not math.isnan(lo) and not math.isnan(hi) and (lo > 0 or hi < 0)


def _practical_threshold_met(delta_fp, delta_recall):
    """Return True if recall or FP delta meets the practical significance gate."""
    recall_ok = not math.isnan(delta_recall) and delta_recall >= 0.10
    fp_ok = not math.isnan(delta_fp) and delta_fp <= -1.0
    return recall_ok or fp_ok


def _is_confirmed(mean_delta, ci_excl, p_value, threshold):
    """Return True when all four CONFIRMED criteria are satisfied."""
    return (not math.isnan(mean_delta)
            and mean_delta >= 1.0
            and ci_excl
            and p_value < 0.05
            and threshold)


def _determine_verdict(mean_delta, delta_ci, wilcoxon, delta_fp, delta_recall):
    """Apply decision rules.

    Returns one of: CONFIRMED, DENIED, PARTIAL, INCONCLUSIVE.
    """
    ci_excl = _ci_excludes_zero(delta_ci)
    threshold = _practical_threshold_met(delta_fp, delta_recall)
    p_value = wilcoxon.get("p_value", 1.0)
    if _is_confirmed(mean_delta, ci_excl, p_value, threshold):
        return "CONFIRMED"
    if not math.isnan(mean_delta) and mean_delta < 0 and ci_excl:
        return "DENIED"
    if ci_excl:
        return "PARTIAL"
    return "INCONCLUSIVE"


def _determine_decision_class(n_paired, parse_rate, stdev_ratio):
    """Apply decision class rules."""
    if n_paired >= 15 and parse_rate <= 0.05 and stdev_ratio <= 0.35:
        return "VERIFIED"
    if n_paired >= 10 and parse_rate <= 0.10:
        return "OBSERVED"
    return "INCONCLUSIVE"


def analyze_primary(aggregates_rows, scores_rows):
    """Run primary paired analysis on aggregate scores.

    Args:
        aggregates_rows: Rows from aggregates.csv.
        scores_rows: Rows from scores.csv (for parse failure counting).

    Returns:
        dict with full primary analysis results.
    """
    total_ind = len(scores_rows)
    parse_fail = sum(1 for r in scores_rows if not _parse_ok(r))
    parse_rate = parse_fail / total_ind if total_ind > 0 else 0

    by_cycle = _group_aggregate_rows(aggregates_rows)
    n_paired, mixed_arr, uniform_arr, tp_m, tp_u, fp_m, fp_u, rec_m, rec_u = (
        _build_paired_arrays(by_cycle)
    )
    delta = mixed_arr - uniform_arr

    scores, stdev_ratio, wsr, delta_ci = _compute_primary_stats(
        n_paired, mixed_arr, uniform_arr, delta
    )

    nan = float("nan")
    mean_fp_m = float(np.mean(fp_m)) if fp_m else nan
    mean_fp_u = float(np.mean(fp_u)) if fp_u else nan
    mean_rec_m = float(np.mean(rec_m)) if rec_m else nan
    mean_rec_u = float(np.mean(rec_u)) if rec_u else nan
    delta_fp = mean_fp_m - mean_fp_u
    delta_recall = mean_rec_m - mean_rec_u

    verdict = _determine_verdict(scores["mean_delta"], delta_ci, wsr, delta_fp, delta_recall)
    decision_class = _determine_decision_class(n_paired, parse_rate, stdev_ratio)

    return {
        "n_paired": n_paired,
        "total_individual_runs": total_ind,
        "parse_failures_individual": parse_fail,
        "parse_rate_individual": round(parse_rate, 4),
        "condition_a": "uniform",
        "condition_b": "mixed",
        "scores": scores,
        "secondary": {
            "mean_tp_uniform": round(float(np.mean(tp_u)) if tp_u else nan, 4),
            "mean_tp_mixed": round(float(np.mean(tp_m)) if tp_m else nan, 4),
            "mean_fp_uniform": round(mean_fp_u, 4),
            "mean_fp_mixed": round(mean_fp_m, 4),
            "delta_fp": round(delta_fp, 4),
            "mean_recall_uniform": round(mean_rec_u, 4),
            "mean_recall_mixed": round(mean_rec_m, 4),
            "delta_recall": round(delta_recall, 4),
        },
        "wilcoxon": wsr,
        "bootstrap_ci_delta": delta_ci,
        "verdict": verdict,
        "decision_class": decision_class,
    }


# ---------------------------------------------------------------------------
# Unique-find analysis (bugs found only by Opus reviewer per cycle)
# ---------------------------------------------------------------------------

def _group_mixed_by_cycle(scores_rows):
    """Group mixed-condition scores by cycle into opus/sonnet per-area dicts.

    Returns:
        dict: {cycle: {"opus": per_area_dict, "sonnet": [per_area_dict, ...]}}
    """
    by_cycle = defaultdict(lambda: {"opus": {}, "sonnet": []})
    for row in scores_rows:
        if row["condition"] != "mixed" or not _parse_ok(row):
            continue
        per_area = _safe_parse_area(row)
        if per_area is None:
            continue
        cycle = row["cycle"]
        reviewer = int(row["reviewer"])
        if reviewer == 1:
            by_cycle[cycle]["opus"] = per_area
        else:
            by_cycle[cycle]["sonnet"].append(per_area)
    return by_cycle


def _count_unique_for_cycle(opus, sonnets):
    """Count bugs found only by Opus and not by any Sonnet reviewer.

    Returns:
        tuple: (unique_count, list of unique bug_ids)
    """
    unique_bugs = []
    for bug_id in REAL_BUGS:
        opus_found = opus.get(bug_id, {}).get("found", False)
        sonnet_found = any(s.get(bug_id, {}).get("found", False) for s in sonnets)
        if opus_found and not sonnet_found:
            unique_bugs.append(bug_id)
    return len(unique_bugs), unique_bugs


def analyze_unique_finds(scores_rows):
    """Count bugs found only by Opus (reviewer 1 in mixed) per cycle.

    For each cycle in the mixed condition, identifies bugs that reviewer 1
    (Opus) found but neither reviewer 2 nor 3 (Sonnet) found. These are
    bugs that would not have been discovered without model mixing.

    Returns:
        dict with per-cycle unique find counts and summary statistics.
    """
    by_cycle = _group_mixed_by_cycle(scores_rows)

    unique_finds_per_cycle = []
    unique_bugs_all = defaultdict(int)
    for cycle in sorted(by_cycle.keys(), key=_sort_key):
        opus = by_cycle[cycle]["opus"]
        sonnets = by_cycle[cycle]["sonnet"]
        if not opus or len(sonnets) < 2:
            continue
        count, bugs = _count_unique_for_cycle(opus, sonnets)
        unique_finds_per_cycle.append(count)
        for bug_id in bugs:
            unique_bugs_all[bug_id] += 1

    n_cycles = len(unique_finds_per_cycle)
    arr = np.array(unique_finds_per_cycle, dtype=float)
    mean_unique = float(np.mean(arr)) if n_cycles > 0 else float("nan")
    total_unique = int(np.sum(arr)) if n_cycles > 0 else 0

    return {
        "n_cycles": n_cycles,
        "unique_finds_per_cycle": unique_finds_per_cycle,
        "mean_unique_per_cycle": round(mean_unique, 4),
        "total_unique_finds": total_unique,
        "unique_bug_frequency": dict(unique_bugs_all),
        "bootstrap_ci": bootstrap_ci(arr, stat_fn=np.mean) if n_cycles > 1 else bootstrap_ci([]),
        "note": "Bugs found by Opus (reviewer 1) but NOT by either Sonnet (reviewers 2-3)",
    }


# ---------------------------------------------------------------------------
# Cost analysis
# ---------------------------------------------------------------------------

OPUS_COST_MULTIPLIER = 5.0  # Opus is ~5x Sonnet per token
REVIEWERS_PER_CONDITION = 3


def analyze_cost():
    """Estimate relative cost of uniform vs mixed conditions.

    Returns:
        dict with cost ratios and per-cycle estimates.
    """
    # Uniform: 3x Sonnet = 3 units
    uniform_cost_units = REVIEWERS_PER_CONDITION * 1.0

    # Mixed: 1x Opus + 2x Sonnet = 5 + 2 = 7 units
    mixed_cost_units = 1.0 * OPUS_COST_MULTIPLIER + (REVIEWERS_PER_CONDITION - 1) * 1.0

    cost_increase_pct = ((mixed_cost_units - uniform_cost_units) / uniform_cost_units) * 100

    return {
        "uniform_cost_units": uniform_cost_units,
        "mixed_cost_units": mixed_cost_units,
        "cost_increase_pct": round(cost_increase_pct, 1),
        "uniform_composition": f"{REVIEWERS_PER_CONDITION}x Sonnet",
        "mixed_composition": f"1x Opus + {REVIEWERS_PER_CONDITION - 1}x Sonnet",
        "opus_cost_multiplier": OPUS_COST_MULTIPLIER,
        "note": "Cost units relative to 1 Sonnet session",
    }


# ---------------------------------------------------------------------------
# Session summary
# ---------------------------------------------------------------------------

def summarize_sessions(aggregates_rows, scores_rows):
    """Summarize session counts and parse rates."""
    n_agg = len(aggregates_rows)
    n_scores = len(scores_rows)
    n_agg_ok = sum(1 for r in aggregates_rows if _parse_ok(r))
    n_scores_ok = sum(1 for r in scores_rows if _parse_ok(r))
    return {
        "total_individual_sessions": n_scores,
        "individual_parse_ok": n_scores_ok,
        "individual_parse_rate": round(n_scores_ok / n_scores, 4) if n_scores > 0 else 0,
        "total_aggregate_conditions": n_agg,
        "aggregate_parse_ok": n_agg_ok,
        "aggregate_parse_rate": round(n_agg_ok / n_agg, 4) if n_agg > 0 else 0,
    }


# ---------------------------------------------------------------------------
# Report printing
# ---------------------------------------------------------------------------

def _print_primary_section(primary):
    """Print primary analysis section."""
    s = primary["scores"]
    sec = primary["secondary"]
    w = primary["wilcoxon"]
    ci = primary["bootstrap_ci_delta"]

    print(f"\nConditions: {primary['condition_a']} (A) vs {primary['condition_b']} (B)")
    print(f"Paired cycles:     {primary['n_paired']}")
    print(f"Individual runs:   {primary['total_individual_runs']}")
    print(f"Parse failures:    {primary['parse_failures_individual']}/"
          f"{primary['total_individual_runs']} "
          f"({primary['parse_rate_individual']:.1%})")

    print(f"\n{'Metric':<26} {'Uniform (A)':>15} {'Mixed (B)':>15} {'Delta':>10}")
    print("-" * 68)
    print(f"{'Mean agg score':<26} {s['mean_uniform']:>15.2f} "
          f"{s['mean_mixed']:>15.2f} {s['mean_delta']:>+10.2f}")
    print(f"{'Stdev':<26} {s['stdev_uniform']:>15.2f} {s['stdev_mixed']:>15.2f}")
    print(f"{'Mean TP':<26} {sec['mean_tp_uniform']:>15.2f} {sec['mean_tp_mixed']:>15.2f}")
    print(f"{'Mean FP':<26} {sec['mean_fp_uniform']:>15.2f} "
          f"{sec['mean_fp_mixed']:>15.2f} {sec['delta_fp']:>+10.2f}")
    print(f"{'Mean recall':<26} {sec['mean_recall_uniform']:>15.2f} "
          f"{sec['mean_recall_mixed']:>15.2f} {sec['delta_recall']:>+10.2f}")

    print(f"\nStdev ratio: {s['stdev_ratio']:.4f}  (threshold <= 0.35)")

    print("\nWilcoxon signed-rank (mixed vs uniform):")
    print(f"  T+ = {w['T_plus']:.1f},  T- = {w['T_minus']:.1f},  T = {w['T_stat']:.1f}")
    print(f"  n_nonzero = {w['n_nonzero']},  method = {w['method']}")
    if w["sufficient"]:
        print(f"  z = {w['z_stat']:.4f},  p = {w['p_value']:.6f}")
    else:
        print("  Insufficient sample for normal approximation")

    print("\nBootstrap 95% CI on mean delta_score (mixed - uniform):")
    print(f"  [{ci['ci_lower']:.4f}, {ci['ci_upper']:.4f}]")
    ci_excl = (ci["ci_lower"] > 0 or ci["ci_upper"] < 0)
    print(f"  Excludes zero: {ci_excl}")

    print(f"\nVerdict:        {primary['verdict']}")
    print(f"Decision class: {primary['decision_class']}")


def _print_unique_finds_section(unique_finds):
    """Print unique-find analysis section."""
    print("\n" + "-" * 65)
    print(" UNIQUE OPUS FINDS (bugs found only by Opus, not by Sonnets)")
    print("-" * 65)
    print(f"  Cycles analyzed:           {unique_finds['n_cycles']}")
    print(f"  Mean unique finds/cycle:   {unique_finds['mean_unique_per_cycle']:.2f}")
    print(f"  Total unique finds:        {unique_finds['total_unique_finds']}")

    if unique_finds["unique_bug_frequency"]:
        freq = unique_finds["unique_bug_frequency"]
        bugs_sorted = sorted(freq.items(), key=lambda x: -x[1])
        bug_str = ", ".join(f"{b}({c})" for b, c in bugs_sorted)
        print(f"  Bug frequency:             {bug_str}")

    ci = unique_finds["bootstrap_ci"]
    if not math.isnan(ci.get("ci_lower", float("nan"))):
        print(f"  Bootstrap 95% CI (mean):   [{ci['ci_lower']:.4f}, {ci['ci_upper']:.4f}]")


def _print_cost_section(cost):
    """Print cost analysis section."""
    print("\n" + "-" * 65)
    print(" COST ANALYSIS")
    print("-" * 65)
    print(f"  Uniform:  {cost['uniform_composition']} = {cost['uniform_cost_units']:.0f} units/cycle")
    print(f"  Mixed:    {cost['mixed_composition']} = {cost['mixed_cost_units']:.0f} units/cycle")
    print(f"  Increase: +{cost['cost_increase_pct']:.1f}%")
    print(f"  (1 unit = 1 Sonnet session, Opus = {cost['opus_cost_multiplier']:.0f}x)")


def _print_session_section(sessions):
    """Print session summary section."""
    print("\n" + "-" * 65)
    print(" SESSION SUMMARY")
    print("-" * 65)
    print(f"  Individual sessions:       {sessions['total_individual_sessions']}")
    print(f"  Individual parse success:  {sessions['individual_parse_ok']} "
          f"({sessions['individual_parse_rate']:.1%})")
    print(f"  Aggregate conditions:      {sessions['total_aggregate_conditions']}")
    print(f"  Aggregate parse success:   {sessions['aggregate_parse_ok']} "
          f"({sessions['aggregate_parse_rate']:.1%})")


def _print_report(primary, unique_finds, cost, sessions):
    """Print full human-readable analysis report."""
    print("\n" + "=" * 65)
    print(" V4 MIXED-MODEL REVIEW ANALYSIS")
    print("=" * 65)
    _print_primary_section(primary)
    _print_unique_finds_section(unique_finds)
    _print_cost_section(cost)
    _print_session_section(sessions)
    print("\n" + "=" * 65)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    """CLI entry point.

    Usage: python3 analyze-v4.py <scores.csv> <aggregates.csv>
    """
    if len(sys.argv) < 3:
        print("Usage: python3 analyze-v4.py <scores.csv> <aggregates.csv>")
        sys.exit(1)

    scores_path, aggregates_path = sys.argv[1], sys.argv[2]
    for path in (scores_path, aggregates_path):
        if not os.path.exists(path):
            print(f"ERROR: File not found: {path}")
            sys.exit(1)

    scores_rows = _read_csv(scores_path)
    aggregates_rows = _read_csv(aggregates_path)
    if not scores_rows:
        print("ERROR: scores.csv has no data rows")
        sys.exit(1)
    if not aggregates_rows:
        print("ERROR: aggregates.csv has no data rows")
        sys.exit(1)

    primary = analyze_primary(aggregates_rows, scores_rows)
    unique_finds = analyze_unique_finds(scores_rows)
    cost = analyze_cost()
    sessions = summarize_sessions(aggregates_rows, scores_rows)

    _print_report(primary, unique_finds, cost, sessions)

    summary_path = os.path.join(
        os.path.dirname(os.path.abspath(aggregates_path)),
        "mixed-model-v4-summary.json",
    )
    _write_json(summary_path, {
        "primary": primary,
        "unique_finds": unique_finds,
        "cost": cost,
        "sessions": sessions,
    })


if __name__ == "__main__":
    main()
