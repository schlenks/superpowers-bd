#!/usr/bin/env python3
"""Statistical analyzer for V3 decorrelated specialization experiment.

Reads per-reviewer scores.csv and aggregates.csv produced by
test-decorrelated-v3.sh. Computes:

  - Aggregate scoring (union rule) — primary endpoint
  - Wilcoxon signed-rank test on per-cycle aggregate delta_score
  - Bootstrap 95% CI on mean aggregate delta_score
  - CONFIRMED / PARTIAL / DENIED / INCONCLUSIVE verdict
  - VERIFIED / OBSERVED / INCONCLUSIVE decision class
  - Per-domain recall analysis (descriptive only — 3 bugs per domain)
  - Individual reviewer in-domain recall analysis
  - JSON summary output to <aggregates_dir>/aggregates-summary.json

Usage:
    python3 analyze-v3.py <scores.csv> <aggregates.csv>

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
# Ground truth constants (match test-decorrelated-v3.sh)
# ---------------------------------------------------------------------------

REAL_BUGS = frozenset({
    "B1", "B2", "B3",       # Correctness
    "B4", "B5", "B6",       # Security
    "B7", "B8", "B9",       # Performance
    "B10", "B11", "B12",    # Architecture
})
DECOYS = frozenset({
    "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8",
    "D9", "D10", "D11", "D12", "D13", "D14", "D15", "D16",
})
AREA_IDS = sorted(REAL_BUGS | DECOYS)
TOTAL_BUGS = 12

DOMAINS = {
    "correctness":  ["B1", "B2", "B3"],
    "security":     ["B4", "B5", "B6"],
    "performance":  ["B7", "B8", "B9"],
    "architecture": ["B10", "B11", "B12"],
}

# Specialist reviewer index → domain (matches SPECIALIST_TEMPLATES order)
REVIEWER_DOMAIN = {
    1: "correctness",
    2: "security",
    3: "performance",
    4: "architecture",
}


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
    """Extract parallel arrays for specialist and generalist from grouped rows.

    Returns:
        tuple: (n_paired, spec_arr, gen_arr, tp_spec, tp_gen,
                fp_spec, fp_gen, recall_spec, recall_gen)
    """
    paired, scores_s, scores_g = [], [], []
    tp_s, tp_g, fp_s, fp_g, rec_s, rec_g = [], [], [], [], [], []

    for cycle in sorted(by_cycle.keys(), key=_sort_key):
        data = by_cycle[cycle]
        spec = data.get("specialist")
        gen = data.get("generalist")
        if spec is None or gen is None:
            continue
        paired.append(cycle)
        scores_s.append(spec["score"])
        scores_g.append(gen["score"])
        tp_s.append(spec["tp"])
        tp_g.append(gen["tp"])
        fp_s.append(spec["fp"])
        fp_g.append(gen["fp"])
        if spec["recall"] is not None and gen["recall"] is not None:
            rec_s.append(spec["recall"])
            rec_g.append(gen["recall"])

    return (
        len(paired),
        np.array(scores_s, dtype=float),
        np.array(scores_g, dtype=float),
        tp_s, tp_g, fp_s, fp_g, rec_s, rec_g,
    )


def _compute_primary_stats(n_paired, spec_arr, gen_arr, delta):
    """Compute descriptive statistics, Wilcoxon, and bootstrap CI.

    Returns:
        tuple: (scores_dict, stdev_ratio, wilcoxon_result, delta_ci)
    """
    nan = float("nan")
    mean_d = float(np.mean(delta)) if n_paired > 0 else nan
    mean_s = float(np.mean(spec_arr)) if n_paired > 0 else nan
    mean_g = float(np.mean(gen_arr)) if n_paired > 0 else nan
    stdev_s = float(np.std(spec_arr, ddof=1)) if n_paired > 1 else 0.0
    stdev_g = float(np.std(gen_arr, ddof=1)) if n_paired > 1 else 0.0
    pooled = (mean_s + mean_g) / 2 if n_paired > 0 else 1
    stdev_ratio = max(stdev_s, stdev_g) / abs(pooled) if abs(pooled) > 1e-9 else float("inf")

    wsr = wilcoxon_signed_rank(spec_arr, gen_arr)
    delta_ci = bootstrap_ci(delta, stat_fn=np.mean) if n_paired > 0 else bootstrap_ci([])

    scores = {
        "mean_generalist": round(mean_g, 4),
        "mean_specialist": round(mean_s, 4),
        "mean_delta": round(mean_d, 4),
        "stdev_generalist": round(stdev_g, 4),
        "stdev_specialist": round(stdev_s, 4),
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
    """Apply decision rules from plan §Task 7 Step 3.

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
    """Apply decision class rules from plan §Task 7 Step 3."""
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
    n_paired, spec_arr, gen_arr, tp_s, tp_g, fp_s, fp_g, rec_s, rec_g = (
        _build_paired_arrays(by_cycle)
    )
    delta = spec_arr - gen_arr

    scores, stdev_ratio, wsr, delta_ci = _compute_primary_stats(
        n_paired, spec_arr, gen_arr, delta
    )

    nan = float("nan")
    mean_fp_s = float(np.mean(fp_s)) if fp_s else nan
    mean_fp_g = float(np.mean(fp_g)) if fp_g else nan
    mean_rec_s = float(np.mean(rec_s)) if rec_s else nan
    mean_rec_g = float(np.mean(rec_g)) if rec_g else nan
    delta_fp = mean_fp_s - mean_fp_g
    delta_recall = mean_rec_s - mean_rec_g

    verdict = _determine_verdict(scores["mean_delta"], delta_ci, wsr, delta_fp, delta_recall)
    decision_class = _determine_decision_class(n_paired, parse_rate, stdev_ratio)

    return {
        "n_paired": n_paired,
        "total_individual_runs": total_ind,
        "parse_failures_individual": parse_fail,
        "parse_rate_individual": round(parse_rate, 4),
        "condition_a": "generalist",
        "condition_b": "specialist",
        "scores": scores,
        "secondary": {
            "mean_tp_generalist": round(float(np.mean(tp_g)) if tp_g else nan, 4),
            "mean_tp_specialist": round(float(np.mean(tp_s)) if tp_s else nan, 4),
            "mean_fp_generalist": round(mean_fp_g, 4),
            "mean_fp_specialist": round(mean_fp_s, 4),
            "delta_fp": round(delta_fp, 4),
            "mean_recall_generalist": round(mean_rec_g, 4),
            "mean_recall_specialist": round(mean_rec_s, 4),
            "delta_recall": round(delta_recall, 4),
        },
        "wilcoxon": wsr,
        "bootstrap_ci_delta": delta_ci,
        "verdict": verdict,
        "decision_class": decision_class,
    }


# ---------------------------------------------------------------------------
# Per-domain analysis (descriptive — 3 bugs per domain)
# ---------------------------------------------------------------------------

def _domain_union_recalls(by_cycle_cond, bug_ids):
    """Compute per-cycle union recall for specialist and generalist for bug_ids.

    Returns:
        tuple: (spec_recalls list, gen_recalls list)
    """
    n = len(bug_ids)
    spec_recalls, gen_recalls = [], []
    for cycle in sorted(by_cycle_cond.keys(), key=_sort_key):
        spec_ent = by_cycle_cond[cycle].get("specialist", [])
        gen_ent = by_cycle_cond[cycle].get("generalist", [])
        if not spec_ent or not gen_ent:
            continue
        spec_found = {b: any(e.get(b, {}).get("found", False) for e in spec_ent)
                      for b in bug_ids}
        gen_found = {b: any(e.get(b, {}).get("found", False) for e in gen_ent)
                     for b in bug_ids}
        spec_recalls.append(sum(spec_found.values()) / n)
        gen_recalls.append(sum(gen_found.values()) / n)
    return spec_recalls, gen_recalls


def analyze_per_domain(scores_rows):
    """Compute per-domain recall for specialist vs generalist (union rule).

    Descriptive stats only — 3 bugs per domain is too few for formal testing.

    Returns:
        dict: {domain: {recall_specialist, recall_generalist, delta_recall, ...}}
    """
    by_cycle_cond = defaultdict(lambda: defaultdict(list))
    for row in scores_rows:
        per_area = _safe_parse_area(row)
        if per_area is not None:
            by_cycle_cond[row["cycle"]][row["condition"]].append(per_area)

    results = {}
    for domain, bug_ids in DOMAINS.items():
        spec_r, gen_r = _domain_union_recalls(by_cycle_cond, bug_ids)
        spec_arr = np.array(spec_r, dtype=float)
        gen_arr = np.array(gen_r, dtype=float)
        mean_s = float(np.mean(spec_arr)) if len(spec_arr) > 0 else float("nan")
        mean_g = float(np.mean(gen_arr)) if len(gen_arr) > 0 else float("nan")
        results[domain] = {
            "bugs": bug_ids,
            "n_cycles": len(spec_r),
            "recall_specialist": round(mean_s, 4),
            "recall_generalist": round(mean_g, 4),
            "delta_recall": round(mean_s - mean_g, 4),
            "specialist_ci": bootstrap_ci(spec_arr, stat_fn=np.mean)
                             if len(spec_arr) > 1 else bootstrap_ci([]),
            "generalist_ci": bootstrap_ci(gen_arr, stat_fn=np.mean)
                             if len(gen_arr) > 1 else bootstrap_ci([]),
            "note": "Descriptive only — 3 bugs too few for formal test",
        }
    return results


# ---------------------------------------------------------------------------
# Individual reviewer analysis helpers
# ---------------------------------------------------------------------------

def _parse_reviewer_entries(scores_rows):
    """Return list of {cycle, condition, reviewer, per_area} for parsed rows."""
    entries = []
    for row in scores_rows:
        per_area = _safe_parse_area(row)
        if per_area is None:
            continue
        try:
            reviewer_num = int(row.get("reviewer", 0))
        except (ValueError, TypeError):
            reviewer_num = 0
        entries.append({
            "cycle": row["cycle"],
            "condition": row["condition"],
            "reviewer": reviewer_num,
            "per_area": per_area,
        })
    return entries


def _reviewer_recalls_for_domain(entries, reviewer_num, bug_ids):
    """Compute per-cycle recall arrays for one specialist reviewer vs generalists.

    Returns:
        tuple: (spec_recalls list, gen_recalls list)
    """
    n = len(bug_ids)
    spec_by_cycle = defaultdict(list)
    gen_by_cycle = defaultdict(list)
    for e in entries:
        if e["condition"] == "specialist" and e["reviewer"] == reviewer_num:
            spec_by_cycle[e["cycle"]].append(e["per_area"])
        elif e["condition"] == "generalist":
            gen_by_cycle[e["cycle"]].append(e["per_area"])

    spec_recalls, gen_recalls = [], []
    for cycle in sorted(spec_by_cycle.keys(), key=_sort_key):
        spec_ent = spec_by_cycle[cycle]
        spec_count = sum(
            1 for b in bug_ids
            if any(e.get(b, {}).get("found", False) for e in spec_ent)
        )
        gen_ent = gen_by_cycle.get(cycle, [])
        if not gen_ent:
            continue
        gen_per = [
            sum(1 for b in bug_ids if e.get(b, {}).get("found", False)) / n
            for e in gen_ent
        ]
        spec_recalls.append(spec_count / n)
        gen_recalls.append(float(np.mean(gen_per)))
    return spec_recalls, gen_recalls


def analyze_individual_reviewers(scores_rows):
    """Compare each specialist's in-domain recall vs mean generalist recall.

    Reviewer N (specialist) maps to domain N per REVIEWER_DOMAIN.
    Generalist baseline is mean per-reviewer recall (not union) for the domain.

    Returns:
        dict: {reviewer_N: {domain, mean_specialist_in_domain_recall, ...}}
    """
    entries = _parse_reviewer_entries(scores_rows)
    results = {}
    for reviewer_num, domain in REVIEWER_DOMAIN.items():
        bug_ids = DOMAINS[domain]
        spec_r, gen_r = _reviewer_recalls_for_domain(entries, reviewer_num, bug_ids)
        spec_arr = np.array(spec_r, dtype=float)
        gen_arr = np.array(gen_r, dtype=float)
        mean_s = float(np.mean(spec_arr)) if len(spec_arr) > 0 else float("nan")
        mean_g = float(np.mean(gen_arr)) if len(gen_arr) > 0 else float("nan")
        delta = mean_s - mean_g
        results[f"reviewer_{reviewer_num}"] = {
            "domain": domain,
            "n_cycles": len(spec_r),
            "mean_specialist_in_domain_recall": round(mean_s, 4),
            "mean_generalist_in_domain_recall": round(mean_g, 4),
            "delta_recall": round(delta, 4),
            "outperformed": bool(not math.isnan(delta) and delta > 0),
            "note": "Specialist vs. mean individual generalist recall for domain bugs",
        }
    return results


# ---------------------------------------------------------------------------
# Cost / session summary
# ---------------------------------------------------------------------------

def summarize_cost(aggregates_rows, scores_rows):
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
# Report printing (split into sections)
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

    print(f"\n{'Metric':<26} {'Generalist (A)':>15} {'Specialist (B)':>15} {'Delta':>10}")
    print("-" * 68)
    print(f"{'Mean agg score':<26} {s['mean_generalist']:>15.2f} "
          f"{s['mean_specialist']:>15.2f} {s['mean_delta']:>+10.2f}")
    print(f"{'Stdev':<26} {s['stdev_generalist']:>15.2f} {s['stdev_specialist']:>15.2f}")
    print(f"{'Mean TP':<26} {sec['mean_tp_generalist']:>15.2f} {sec['mean_tp_specialist']:>15.2f}")
    print(f"{'Mean FP':<26} {sec['mean_fp_generalist']:>15.2f} "
          f"{sec['mean_fp_specialist']:>15.2f} {sec['delta_fp']:>+10.2f}")
    print(f"{'Mean recall':<26} {sec['mean_recall_generalist']:>15.2f} "
          f"{sec['mean_recall_specialist']:>15.2f} {sec['delta_recall']:>+10.2f}")

    print(f"\nStdev ratio: {s['stdev_ratio']:.4f}  (threshold <= 0.35)")

    print("\nWilcoxon signed-rank (specialist vs generalist):")
    print(f"  T+ = {w['T_plus']:.1f},  T- = {w['T_minus']:.1f},  T = {w['T_stat']:.1f}")
    print(f"  n_nonzero = {w['n_nonzero']},  method = {w['method']}")
    if w["sufficient"]:
        print(f"  z = {w['z_stat']:.4f},  p = {w['p_value']:.6f}")
    else:
        print("  Insufficient sample for normal approximation")

    print("\nBootstrap 95% CI on mean delta_score (specialist - generalist):")
    print(f"  [{ci['ci_lower']:.4f}, {ci['ci_upper']:.4f}]")
    ci_excl = (ci["ci_lower"] > 0 or ci["ci_upper"] < 0)
    print(f"  Excludes zero: {ci_excl}")

    print(f"\nVerdict:        {primary['verdict']}")
    print(f"Decision class: {primary['decision_class']}")


def _print_domain_section(domain):
    """Print per-domain recall table."""
    print("\n" + "─" * 65)
    print(" PER-DOMAIN RECALL (descriptive — 3 bugs per domain)")
    print("─" * 65)
    print(f"{'Domain':<14} {'Gen':>7} {'Spec':>7} {'Delta':>7}  {'Bugs'}")
    print("-" * 55)
    for dom, data in sorted(domain.items()):
        spec_ci = data["specialist_ci"]
        gen_ci = data["generalist_ci"]
        spec_str = (f"[{spec_ci.get('ci_lower', float('nan')):.2f},"
                    f"{spec_ci.get('ci_upper', float('nan')):.2f}]")
        gen_str = (f"[{gen_ci.get('ci_lower', float('nan')):.2f},"
                   f"{gen_ci.get('ci_upper', float('nan')):.2f}]")
        print(f"{dom:<14} {data['recall_generalist']:>7.3f} {data['recall_specialist']:>7.3f} "
              f"{data['delta_recall']:>+7.3f}  {','.join(data['bugs']):<12}"
              f"  spec_ci={spec_str}  gen_ci={gen_str}")


def _print_reviewer_section(individual):
    """Print individual reviewer in-domain recall table."""
    print("\n" + "─" * 65)
    print(" INDIVIDUAL REVIEWER IN-DOMAIN RECALL")
    print("─" * 65)
    print(f"{'Reviewer':<12} {'Domain':<14} {'Spec':>7} {'Gen':>7} {'Delta':>7} {'Out?':>5}")
    print("-" * 55)
    for rev_key in sorted(individual.keys()):
        d = individual[rev_key]
        out = "YES" if d["outperformed"] else "no"
        print(f"{rev_key:<12} {d['domain']:<14} "
              f"{d['mean_specialist_in_domain_recall']:>7.3f} "
              f"{d['mean_generalist_in_domain_recall']:>7.3f} "
              f"{d['delta_recall']:>+7.3f} {out:>5}")


def _print_cost_section(cost):
    """Print session summary section."""
    print("\n" + "─" * 65)
    print(" SESSION SUMMARY")
    print("─" * 65)
    print(f"  Individual sessions:       {cost['total_individual_sessions']}")
    print(f"  Individual parse success:  {cost['individual_parse_ok']} "
          f"({cost['individual_parse_rate']:.1%})")
    print(f"  Aggregate conditions:      {cost['total_aggregate_conditions']}")
    print(f"  Aggregate parse success:   {cost['aggregate_parse_ok']} "
          f"({cost['aggregate_parse_rate']:.1%})")


def _print_report(primary, domain, individual, cost):
    """Print full human-readable analysis report."""
    print("\n" + "=" * 65)
    print(" V3 DECORRELATED SPECIALIZATION ANALYSIS")
    print("=" * 65)
    _print_primary_section(primary)
    _print_domain_section(domain)
    _print_reviewer_section(individual)
    _print_cost_section(cost)
    print("\n" + "=" * 65)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    """CLI entry point.

    Usage: python3 analyze-v3.py <scores.csv> <aggregates.csv>
    """
    if len(sys.argv) < 3:
        print("Usage: python3 analyze-v3.py <scores.csv> <aggregates.csv>")
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
    domain = analyze_per_domain(scores_rows)
    individual = analyze_individual_reviewers(scores_rows)
    cost = summarize_cost(aggregates_rows, scores_rows)

    _print_report(primary, domain, individual, cost)

    summary_path = os.path.join(
        os.path.dirname(os.path.abspath(aggregates_path)),
        "aggregates-summary.json",
    )
    _write_json(summary_path, {
        "primary": primary,
        "per_domain": domain,
        "individual_reviewers": individual,
        "cost": cost,
    })


if __name__ == "__main__":
    main()
