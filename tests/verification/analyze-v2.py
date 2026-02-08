#!/usr/bin/env python3
"""Shared statistical analysis for V2 verification experiments.

Provides bootstrap confidence intervals and Wilcoxon signed-rank test
for Experiment B (latency) and Experiment C (reflective).

Usage:
    python3 analyze-v2.py latency <results.csv>
    python3 analyze-v2.py reflective <results.csv> [session_results.csv]

Dependencies: numpy (2.1.0). No scipy required.
"""

import csv
import json
import math
import os
import sys
from collections import defaultdict

import numpy as np


# ---------------------------------------------------------------------------
# Statistical primitives
# ---------------------------------------------------------------------------

def bootstrap_ci(values, stat_fn=np.median, n_resamples=10_000, ci=0.95, seed=42):
    """Compute bootstrap confidence interval for a statistic.

    Args:
        values: Array-like of observed values.
        stat_fn: Statistic function (default: np.median). Must accept 1-D array.
        n_resamples: Number of bootstrap resamples (default: 10,000).
        ci: Confidence level (default: 0.95).
        seed: RNG seed for reproducibility.

    Returns:
        dict with keys: point_estimate, ci_lower, ci_upper, ci_level, n, n_resamples
    """
    values = np.asarray(values, dtype=float)
    n = len(values)
    if n == 0:
        return {
            "point_estimate": float("nan"),
            "ci_lower": float("nan"),
            "ci_upper": float("nan"),
            "ci_level": ci,
            "n": 0,
            "n_resamples": n_resamples,
        }

    rng = np.random.default_rng(seed)
    point = float(stat_fn(values))

    # Generate all resamples at once: shape (n_resamples, n)
    indices = rng.integers(0, n, size=(n_resamples, n))
    resampled = values[indices]
    bootstrap_stats = np.apply_along_axis(stat_fn, axis=1, arr=resampled)

    alpha = 1.0 - ci
    lower = float(np.percentile(bootstrap_stats, 100 * alpha / 2))
    upper = float(np.percentile(bootstrap_stats, 100 * (1 - alpha / 2)))

    return {
        "point_estimate": point,
        "ci_lower": lower,
        "ci_upper": upper,
        "ci_level": ci,
        "n": n,
        "n_resamples": n_resamples,
    }


def _normal_cdf(z):
    """Standard normal CDF using math.erfc (no scipy needed)."""
    return 0.5 * math.erfc(-z / math.sqrt(2))


def _rank_with_ties(values):
    """Assign ranks to values, averaging ranks for tied values.

    Args:
        values: 1-D array-like of values to rank.

    Returns:
        numpy array of ranks (1-based, ties averaged).
    """
    arr = np.asarray(values, dtype=float)
    n = len(arr)
    order = np.argsort(arr)
    ranks = np.empty(n, dtype=float)

    i = 0
    while i < n:
        # Find run of tied values
        j = i + 1
        while j < n and arr[order[j]] == arr[order[i]]:
            j += 1
        # Average rank for ties (ranks are 1-based)
        avg_rank = (i + 1 + j) / 2.0
        for k in range(i, j):
            ranks[order[k]] = avg_rank
        i = j

    return ranks


def wilcoxon_signed_rank(x, y):
    """Wilcoxon signed-rank test for paired samples.

    Pure Python + numpy implementation (no scipy).

    Args:
        x: Array-like of first sample values.
        y: Array-like of second sample values (same length as x).

    Returns:
        dict with keys: T_plus, T_minus, T_stat, n_nonzero, z_stat,
                        p_value, sufficient (bool), method
    """
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)

    if len(x) != len(y):
        raise ValueError(f"x and y must have same length, got {len(x)} and {len(y)}")

    # Step 1: Compute differences
    d = x - y

    # Step 2: Drop zero differences
    nonzero_mask = d != 0
    d_nonzero = d[nonzero_mask]
    n = len(d_nonzero)

    if n == 0:
        return {
            "T_plus": 0.0,
            "T_minus": 0.0,
            "T_stat": 0.0,
            "n_nonzero": 0,
            "z_stat": float("nan"),
            "p_value": 1.0,
            "sufficient": False,
            "method": "no_nonzero_differences",
        }

    # Step 3: Rank |d_i| with tie handling
    abs_d = np.abs(d_nonzero)
    ranks = _rank_with_ties(abs_d)

    # Step 4: Compute T+ and T-
    t_plus = float(np.sum(ranks[d_nonzero > 0]))
    t_minus = float(np.sum(ranks[d_nonzero < 0]))
    t_stat = min(t_plus, t_minus)

    # Step 5: Significance
    if n < 10:
        return {
            "T_plus": t_plus,
            "T_minus": t_minus,
            "T_stat": t_stat,
            "n_nonzero": n,
            "z_stat": float("nan"),
            "p_value": float("nan"),
            "sufficient": False,
            "method": "insufficient_sample_size",
        }

    # Normal approximation for n >= 10
    mean_t = n * (n + 1) / 4.0
    var_t = n * (n + 1) * (2 * n + 1) / 24.0

    # Correction for ties in |d|: subtract sum of t_j*(t_j^2-1)/48
    # where t_j is the number of ties in each group
    unique_abs, counts = np.unique(abs_d, return_counts=True)
    tie_correction = 0.0
    for count in counts:
        if count > 1:
            tie_correction += count * (count ** 2 - 1) / 48.0
    var_t -= tie_correction

    if var_t <= 0:
        # Degenerate case: all values identical
        return {
            "T_plus": t_plus,
            "T_minus": t_minus,
            "T_stat": t_stat,
            "n_nonzero": n,
            "z_stat": 0.0,
            "p_value": 1.0,
            "sufficient": True,
            "method": "normal_approximation_degenerate",
        }

    std_t = math.sqrt(var_t)
    z = (t_stat - mean_t) / std_t
    p_value = 2.0 * (1.0 - _normal_cdf(abs(z)))

    return {
        "T_plus": t_plus,
        "T_minus": t_minus,
        "T_stat": t_stat,
        "n_nonzero": n,
        "z_stat": round(z, 4),
        "p_value": round(p_value, 6),
        "sufficient": True,
        "method": "normal_approximation",
    }


# ---------------------------------------------------------------------------
# Latency analysis (Experiment B)
# ---------------------------------------------------------------------------

LATENCY_THRESHOLDS = {
    "FAST": 5000,       # < 5s
    "MODERATE": 15000,  # 5-15s
    "SLOW": 60000,      # 15-60s
    # >= 60s is BLOCKING
}


def _classify_overhead(overhead_ms):
    """Classify latency overhead into FAST/MODERATE/SLOW/BLOCKING."""
    if overhead_ms < LATENCY_THRESHOLDS["FAST"]:
        return "FAST"
    elif overhead_ms < LATENCY_THRESHOLDS["MODERATE"]:
        return "MODERATE"
    elif overhead_ms < LATENCY_THRESHOLDS["SLOW"]:
        return "SLOW"
    else:
        return "BLOCKING"


def analyze_latency(csv_path):
    """Analyze Experiment B latency results.

    Reads CSV with columns: variant, run|cycle, duration_ms, status, attempt, pass_label
    (also accepts 'label' as alias for 'variant', and 'hook_observed'/'proof_type' columns)

    Computes per-variant overhead vs baseline, bootstrap CI, and classification.

    Args:
        csv_path: Path to latency results CSV.

    Returns:
        dict with per-variant analysis and overall summary.
    """
    rows = _read_csv(csv_path)
    if not rows:
        return {"error": "No data rows found", "csv_path": csv_path}

    # Normalize column names: 'label' -> 'variant', 'run' or 'cycle' accepted
    variant_key = "variant" if "variant" in rows[0] else "label"

    # Group successful runs by variant
    by_variant = defaultdict(list)
    total_runs = 0
    failed_runs = 0
    for row in rows:
        total_runs += 1
        status = row.get("status", "succeeded")
        if status != "succeeded":
            failed_runs += 1
            continue
        variant = row[variant_key]
        duration = float(row["duration_ms"])
        by_variant[variant].append(duration)

    # Identify baseline variant
    baseline_key = None
    for candidate in ("none", "baseline"):
        if candidate in by_variant:
            baseline_key = candidate
            break
    if baseline_key is None:
        return {"error": "No baseline variant ('none' or 'baseline') found", "csv_path": csv_path}

    baseline_values = np.array(by_variant[baseline_key])
    baseline_median = float(np.median(baseline_values))
    baseline_ci = bootstrap_ci(baseline_values)

    results = {
        "csv_path": csv_path,
        "total_runs": total_runs,
        "failed_runs": failed_runs,
        "failure_rate": round(failed_runs / total_runs, 4) if total_runs > 0 else 0,
        "baseline": {
            "variant": baseline_key,
            "n": len(baseline_values),
            "median_ms": baseline_median,
            "bootstrap_ci": baseline_ci,
        },
        "variants": {},
    }

    for variant, durations in sorted(by_variant.items()):
        if variant == baseline_key:
            continue
        durations_arr = np.array(durations)
        variant_median = float(np.median(durations_arr))
        overhead = variant_median - baseline_median

        classification = _classify_overhead(overhead)

        # Bootstrap CI on overhead: resample each group independently
        overhead_samples = []
        rng = np.random.default_rng(42)
        for _ in range(10_000):
            v_sample = np.median(rng.choice(durations_arr, size=len(durations_arr), replace=True))
            b_sample = np.median(rng.choice(baseline_values, size=len(baseline_values), replace=True))
            overhead_samples.append(v_sample - b_sample)
        overhead_samples = np.array(overhead_samples)
        ci_lower = float(np.percentile(overhead_samples, 2.5))
        ci_upper = float(np.percentile(overhead_samples, 97.5))
        overhead_ci = {
            "point_estimate": overhead,
            "ci_lower": ci_lower,
            "ci_upper": ci_upper,
            "ci_level": 0.95,
            "n": len(durations_arr),
            "n_resamples": 10_000,
        }

        # Proof level: OBSERVED is the honest ceiling for latency
        proof_level = "OBSERVED"

        results["variants"][variant] = {
            "n": len(durations_arr),
            "median_ms": variant_median,
            "overhead_ms": round(overhead, 1),
            "classification": classification,
            "proof_level": proof_level,
            "bootstrap_ci_overhead": overhead_ci,
        }

    # Determine overall decision class
    all_n = [v["n"] for v in results["variants"].values()]
    min_runs = min(all_n) if all_n else 0
    ci_widths = [
        v["bootstrap_ci_overhead"]["ci_upper"] - v["bootstrap_ci_overhead"]["ci_lower"]
        for v in results["variants"].values()
        if not math.isnan(v["bootstrap_ci_overhead"]["ci_upper"])
    ]
    max_ci_width = max(ci_widths) if ci_widths else float("inf")

    if (min_runs >= 10
            and results["failure_rate"] <= 0.10
            and max_ci_width <= 5000):
        results["decision_class"] = "VERIFIED"
    elif min_runs >= 5:
        results["decision_class"] = "OBSERVED"
    else:
        results["decision_class"] = "INCONCLUSIVE"

    # Write summary JSON
    summary_path = csv_path.rsplit(".", 1)[0] + "-summary.json"
    _write_json(summary_path, results)
    results["summary_path"] = summary_path

    return results


# ---------------------------------------------------------------------------
# Reflective analysis (Experiment C)
# ---------------------------------------------------------------------------

def analyze_reflective(csv_path, session_results_path=None):
    """Analyze Experiment C reflective review results.

    Reads CSV with columns: cycle, method, score, tp, fp, fn, precision, recall, parse_ok
    (also accepts 'run' as alias for 'cycle', 'true_positives'/'false_positives' for tp/fp,
     'parse_failed' as inverse of 'parse_ok')

    Computes delta_score, Wilcoxon p-value, bootstrap CI.

    Args:
        csv_path: Path to reflective results CSV.
        session_results_path: Optional path to session-level stability CSV.

    Returns:
        dict with paired analysis and verdict.
    """
    rows = _read_csv(csv_path)
    if not rows:
        return {"error": "No data rows found", "csv_path": csv_path}

    # Normalize column names
    cycle_key = "cycle" if "cycle" in rows[0] else "run"
    tp_key = "tp" if "tp" in rows[0] else "true_positives"
    fp_key = "fp" if "fp" in rows[0] else "false_positives"
    fn_key = "fn" if "fn" in rows[0] else None  # may not exist in v1
    score_key = "score"

    # Detect parse status column
    parse_key = None
    if "parse_ok" in rows[0]:
        parse_key = "parse_ok"
    elif "parse_failed" in rows[0]:
        parse_key = "parse_failed"

    # Detect method names
    methods = sorted(set(row["method"] for row in rows))
    if len(methods) != 2:
        return {
            "error": f"Expected exactly 2 methods, found {len(methods)}: {methods}",
            "csv_path": csv_path,
        }

    # Identify method_a (baseline) and method_b (treatment)
    # Convention: 'current' is baseline, 'twophase' is treatment
    if "current" in methods:
        method_a = "current"
        method_b = [m for m in methods if m != "current"][0]
    else:
        method_a, method_b = methods[0], methods[1]

    # Group by cycle and method
    by_cycle = defaultdict(dict)
    total_parse_failures = 0
    total_runs = 0
    for row in rows:
        total_runs += 1
        cycle = row[cycle_key]
        method = row["method"]

        # Parse status
        parse_ok = True
        if parse_key == "parse_ok":
            parse_ok = row[parse_key].lower() in ("true", "1", "yes")
        elif parse_key == "parse_failed":
            parse_ok = row[parse_key].lower() in ("false", "0", "no")
        if not parse_ok:
            total_parse_failures += 1

        by_cycle[cycle][method] = {
            "score": float(row[score_key]),
            "tp": float(row[tp_key]),
            "fp": float(row[fp_key]),
            "fn": float(row.get(fn_key, 0)) if fn_key and row.get(fn_key) else 0,
            "precision": float(row["precision"]) if "precision" in row and row["precision"] else None,
            "recall": float(row["recall"]) if "recall" in row and row["recall"] else None,
            "parse_ok": parse_ok,
        }

    parse_rate = total_parse_failures / total_runs if total_runs > 0 else 0

    # Build paired arrays (only cycles where both methods have data and parsed OK)
    paired_cycles = []
    scores_a = []
    scores_b = []
    tp_a_list = []
    tp_b_list = []
    fp_a_list = []
    fp_b_list = []
    recall_a_list = []
    recall_b_list = []

    for cycle in sorted(by_cycle.keys(), key=lambda c: int(c) if c.isdigit() else c):
        data = by_cycle[cycle]
        if method_a not in data or method_b not in data:
            continue
        a = data[method_a]
        b = data[method_b]
        if not a["parse_ok"] or not b["parse_ok"]:
            continue
        paired_cycles.append(cycle)
        scores_a.append(a["score"])
        scores_b.append(b["score"])
        tp_a_list.append(a["tp"])
        tp_b_list.append(b["tp"])
        fp_a_list.append(a["fp"])
        fp_b_list.append(b["fp"])
        if a["recall"] is not None:
            recall_a_list.append(a["recall"])
        if b["recall"] is not None:
            recall_b_list.append(b["recall"])

    n_paired = len(paired_cycles)
    scores_a = np.array(scores_a)
    scores_b = np.array(scores_b)
    delta_scores = scores_b - scores_a

    # Core statistics
    mean_delta = float(np.mean(delta_scores)) if n_paired > 0 else float("nan")
    mean_score_a = float(np.mean(scores_a)) if n_paired > 0 else float("nan")
    mean_score_b = float(np.mean(scores_b)) if n_paired > 0 else float("nan")

    # Wilcoxon signed-rank test
    wilcoxon = wilcoxon_signed_rank(scores_b, scores_a)

    # Bootstrap CI on mean delta_score
    delta_ci = bootstrap_ci(delta_scores, stat_fn=np.mean) if n_paired > 0 else bootstrap_ci([])

    # Secondary endpoints
    mean_tp_a = float(np.mean(tp_a_list)) if tp_a_list else float("nan")
    mean_tp_b = float(np.mean(tp_b_list)) if tp_b_list else float("nan")
    mean_fp_a = float(np.mean(fp_a_list)) if fp_a_list else float("nan")
    mean_fp_b = float(np.mean(fp_b_list)) if fp_b_list else float("nan")
    delta_fp = mean_fp_b - mean_fp_a

    mean_recall_a = float(np.mean(recall_a_list)) if recall_a_list else float("nan")
    mean_recall_b = float(np.mean(recall_b_list)) if recall_b_list else float("nan")
    delta_recall = mean_recall_b - mean_recall_a

    # Variance stability
    stdev_a = float(np.std(scores_a, ddof=1)) if n_paired > 1 else 0
    stdev_b = float(np.std(scores_b, ddof=1)) if n_paired > 1 else 0
    pooled_mean = (mean_score_a + mean_score_b) / 2 if n_paired > 0 else 1
    stdev_ratio = max(stdev_a, stdev_b) / pooled_mean if pooled_mean > 0 else float("inf")

    # Session stability check
    session_stable = True
    session_stability_info = None
    if session_results_path and os.path.exists(session_results_path):
        session_stability_info = _check_session_stability(session_results_path)
        session_stable = session_stability_info.get("stable", True)

    # Verdict determination
    ci_excludes_zero = (
        not math.isnan(delta_ci["ci_lower"])
        and not math.isnan(delta_ci["ci_upper"])
        and (delta_ci["ci_lower"] > 0 or delta_ci["ci_upper"] < 0)
    )

    recall_or_fp_improved = (
        (not math.isnan(delta_recall) and delta_recall >= 0.15)
        or (not math.isnan(delta_fp) and delta_fp <= -0.5)
    )

    if (not math.isnan(mean_delta)
            and mean_delta >= 0.5
            and ci_excludes_zero
            and wilcoxon.get("p_value", 1.0) < 0.05
            and recall_or_fp_improved):
        verdict = "CONFIRMED"
    elif not math.isnan(mean_delta) and mean_delta < 0 and ci_excludes_zero:
        verdict = "DENIED"
    elif ci_excludes_zero:
        verdict = "PARTIAL"
    else:
        verdict = "INCONCLUSIVE"

    # Decision class
    if (n_paired >= 20
            and parse_rate <= 0.05
            and stdev_ratio <= 0.35
            and session_stable):
        decision_class = "VERIFIED"
    elif n_paired >= 10 and parse_rate <= 0.10:
        decision_class = "OBSERVED"
    else:
        decision_class = "INCONCLUSIVE"

    results = {
        "csv_path": csv_path,
        "method_a": method_a,
        "method_b": method_b,
        "n_paired": n_paired,
        "total_runs": total_runs,
        "parse_failures": total_parse_failures,
        "parse_rate": round(parse_rate, 4),
        "scores": {
            "mean_a": round(mean_score_a, 4),
            "mean_b": round(mean_score_b, 4),
            "mean_delta": round(mean_delta, 4),
            "stdev_a": round(stdev_a, 4),
            "stdev_b": round(stdev_b, 4),
            "stdev_ratio": round(stdev_ratio, 4),
        },
        "secondary": {
            "mean_tp_a": round(mean_tp_a, 4),
            "mean_tp_b": round(mean_tp_b, 4),
            "mean_fp_a": round(mean_fp_a, 4),
            "mean_fp_b": round(mean_fp_b, 4),
            "delta_fp": round(delta_fp, 4),
            "mean_recall_a": round(mean_recall_a, 4),
            "mean_recall_b": round(mean_recall_b, 4),
            "delta_recall": round(delta_recall, 4),
        },
        "wilcoxon": wilcoxon,
        "bootstrap_ci_delta": delta_ci,
        "verdict": verdict,
        "decision_class": decision_class,
    }

    if session_stability_info:
        results["session_stability"] = session_stability_info

    # Write summary JSON
    summary_path = csv_path.rsplit(".", 1)[0] + "-summary.json"
    _write_json(summary_path, results)
    results["summary_path"] = summary_path

    return results


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _read_csv(path):
    """Read CSV file and return list of dicts."""
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        return list(reader)


def _write_json(path, data):
    """Write data as formatted JSON."""
    with open(path, "w") as f:
        json.dump(data, f, indent=2, default=str)
    print(f"  Summary written to: {path}")


def _check_session_stability(session_csv_path):
    """Check session-level stability from a separate results CSV.

    Expects columns: cycle, method, status (at minimum).
    Stability: no 'failed' or 'timed_out' statuses, no retries.
    """
    rows = _read_csv(session_csv_path)
    total = len(rows)
    failed = sum(1 for r in rows if r.get("status") in ("failed", "timed_out"))
    retries = sum(1 for r in rows if int(r.get("attempt", 1)) > 1)

    return {
        "total_sessions": total,
        "failed_sessions": failed,
        "retried_sessions": retries,
        "stable": failed == 0 and retries == 0,
    }


# ---------------------------------------------------------------------------
# CLI + pretty printing
# ---------------------------------------------------------------------------

def _print_latency_report(results):
    """Print human-readable latency analysis report."""
    if "error" in results:
        print(f"ERROR: {results['error']}")
        return

    print("\n" + "=" * 60)
    print("EXPERIMENT B: LATENCY ANALYSIS")
    print("=" * 60)

    bl = results["baseline"]
    print(f"\nBaseline ({bl['variant']}): median={bl['median_ms']:.0f}ms  "
          f"n={bl['n']}  "
          f"CI=[{bl['bootstrap_ci']['ci_lower']:.0f}, {bl['bootstrap_ci']['ci_upper']:.0f}]")

    print(f"\nTotal runs: {results['total_runs']}  "
          f"Failed: {results['failed_runs']}  "
          f"Failure rate: {results['failure_rate']:.1%}")

    print(f"\n{'Variant':<12} {'N':>4} {'Median':>10} {'Overhead':>10} {'Class':>10} {'CI':>20}")
    print("-" * 68)
    for variant, data in sorted(results["variants"].items()):
        ci = data["bootstrap_ci_overhead"]
        ci_str = f"[{ci['ci_lower']:.0f}, {ci['ci_upper']:.0f}]"
        print(f"{variant:<12} {data['n']:>4} {data['median_ms']:>9.0f}ms "
              f"{data['overhead_ms']:>+9.0f}ms {data['classification']:>10} {ci_str:>20}")

    print(f"\nDecision class: {results['decision_class']}")
    print("=" * 60)


def _print_reflective_report(results):
    """Print human-readable reflective analysis report."""
    if "error" in results:
        print(f"ERROR: {results['error']}")
        return

    print("\n" + "=" * 60)
    print("EXPERIMENT C: REFLECTIVE ANALYSIS")
    print("=" * 60)

    s = results["scores"]
    sec = results["secondary"]
    w = results["wilcoxon"]
    ci = results["bootstrap_ci_delta"]

    print(f"\nMethods: {results['method_a']} (A) vs {results['method_b']} (B)")
    print(f"Paired cycles: {results['n_paired']}")
    print(f"Parse failures: {results['parse_failures']}/{results['total_runs']} "
          f"({results['parse_rate']:.1%})")

    print(f"\n{'Metric':<20} {'A':>10} {'B':>10} {'Delta':>10}")
    print("-" * 52)
    print(f"{'Mean score':<20} {s['mean_a']:>10.2f} {s['mean_b']:>10.2f} {s['mean_delta']:>+10.2f}")
    print(f"{'Stdev':<20} {s['stdev_a']:>10.2f} {s['stdev_b']:>10.2f}")
    print(f"{'Mean TP':<20} {sec['mean_tp_a']:>10.2f} {sec['mean_tp_b']:>10.2f}")
    print(f"{'Mean FP':<20} {sec['mean_fp_a']:>10.2f} {sec['mean_fp_b']:>10.2f} {sec['delta_fp']:>+10.2f}")
    print(f"{'Mean recall':<20} {sec['mean_recall_a']:>10.2f} {sec['mean_recall_b']:>10.2f} {sec['delta_recall']:>+10.2f}")

    print(f"\nStdev ratio: {s['stdev_ratio']:.4f} (threshold: <= 0.35)")

    print(f"\nWilcoxon signed-rank test:")
    print(f"  T+ = {w['T_plus']:.1f}, T- = {w['T_minus']:.1f}, T = {w['T_stat']:.1f}")
    print(f"  n_nonzero = {w['n_nonzero']}, method = {w['method']}")
    if w["sufficient"]:
        print(f"  z = {w['z_stat']:.4f}, p = {w['p_value']:.6f}")
    else:
        print(f"  Insufficient sample size for normal approximation")

    print(f"\nBootstrap 95% CI on mean delta_score:")
    print(f"  [{ci['ci_lower']:.4f}, {ci['ci_upper']:.4f}]")

    ci_excludes_zero = (ci["ci_lower"] > 0 or ci["ci_upper"] < 0)
    print(f"  Excludes zero: {ci_excludes_zero}")

    print(f"\nVerdict: {results['verdict']}")
    print(f"Decision class: {results['decision_class']}")

    if "session_stability" in results:
        ss = results["session_stability"]
        print(f"\nSession stability: {'STABLE' if ss['stable'] else 'UNSTABLE'}")
        print(f"  Sessions: {ss['total_sessions']}, Failed: {ss['failed_sessions']}, "
              f"Retried: {ss['retried_sessions']}")

    print("=" * 60)


def main():
    """CLI entry point."""
    if len(sys.argv) < 3:
        print("Usage:")
        print("  python3 analyze-v2.py latency <results.csv>")
        print("  python3 analyze-v2.py reflective <results.csv> [session_results.csv]")
        sys.exit(1)

    mode = sys.argv[1]
    csv_path = sys.argv[2]

    if not os.path.exists(csv_path):
        print(f"ERROR: File not found: {csv_path}")
        sys.exit(1)

    if mode == "latency":
        results = analyze_latency(csv_path)
        _print_latency_report(results)
    elif mode == "reflective":
        session_path = sys.argv[3] if len(sys.argv) > 3 else None
        results = analyze_reflective(csv_path, session_path)
        _print_reflective_report(results)
    else:
        print(f"ERROR: Unknown mode '{mode}'. Use 'latency' or 'reflective'.")
        sys.exit(1)


if __name__ == "__main__":
    main()
