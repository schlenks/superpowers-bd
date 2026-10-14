#!/usr/bin/env python3
"""Deterministic SDD post-mortem for one Claude Code session transcript.

Usage: sdd-postmortem.py <session.jsonl> [--json] [--temp-dir DIR] [--idle-minutes N]

Reads <session>.jsonl plus <session>/subagents/*.jsonl and *.meta.json and
reports: per-seat and per-model tokens and dollars (cache-aware), the dispatch
tree, a wave timeline, idle gaps, joined hook logs, and path:line evidence.
Stdlib only. Same input always yields the same report.
"""
import argparse
import glob
import json
import os
import re
import sys
from datetime import datetime, timedelta

# USD per million tokens: (input, output, cache_read, cache_write_5m, cache_write_1h).
# Source: claude-api pricing table, 2026-10-06. Cache read = 0.1x input, 5m write =
# 1.25x input, 1h write = 2x input. Keys are normalized model ids (no [1m] / date suffix).
# Models absent here are reported as unpriced, never guessed.
PRICING = {
    "claude-opus-5-5": (5.0, 25.0, 0.5, 6.25, 10.0),
    "claude-sonnet-5-5": (3.0, 15.0, 0.3, 3.75, 6.0),
    "claude-haiku-5": (1.0, 5.0, 0.1, 1.25, 2.0),
}

TOKEN_KEYS = ("input", "output", "cache_read", "cache_write_5m", "cache_write_1h")


def norm_model(model):
    model = re.sub(r"\[.*?\]$", "", model or "?")
    return re.sub(r"-\d{8}$", "", model)


def ts(value):
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        return None


def read_transcript(path):
    """Return (usage_by_message_id, events) where events are (ts, line_no)."""
    usage, events = {}, []
    with open(path, errors="replace") as fh:
        for n, line in enumerate(fh, 1):
            try:
                ev = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(ev, dict):
                continue
            t = ts(ev.get("timestamp"))
            if t:
                events.append((t, n))
            msg = ev.get("message")
            if ev.get("type") == "assistant" and isinstance(msg, dict) and msg.get("usage"):
                key = msg.get("id") or f"line{n}"
                usage[key] = (norm_model(msg.get("model")), msg["usage"], n)
    return usage, events


def tokens_of(u):
    cc = u.get("cache_creation") or {}
    w5, w1 = cc.get("ephemeral_5m_input_tokens"), cc.get("ephemeral_1h_input_tokens")
    if w5 is None and w1 is None:
        w5, w1 = u.get("cache_creation_input_tokens") or 0, 0
    return {
        "input": u.get("input_tokens") or 0,
        "output": u.get("output_tokens") or 0,
        "cache_read": u.get("cache_read_input_tokens") or 0,
        "cache_write_5m": w5 or 0,
        "cache_write_1h": w1 or 0,
    }


def price(model, tok):
    rates = PRICING.get(model)
    if not rates:
        return None
    return sum(tok[k] * r for k, r in zip(TOKEN_KEYS, rates)) / 1_000_000


def new_acc():
    return dict.fromkeys(TOKEN_KEYS, 0) | {"calls": 0, "cost": 0.0, "unpriced": False}


def accumulate(acc, model, tok):
    for k in TOKEN_KEYS:
        acc[k] += tok[k]
    acc["calls"] += 1
    c = price(model, tok)
    if c is None:
        acc["unpriced"] = True
    else:
        acc["cost"] += c


def seat_summary(acc):
    out = dict(acc)
    if out["unpriced"] and out["cost"] == 0.0:
        out["cost"] = None
    return out


def load_meta(path):
    try:
        with open(path) as fh:
            meta = json.load(fh)
        return meta if isinstance(meta, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def build_tree(seats_meta):
    """seats_meta: {id: meta}. Missing/unknown parents attach to the controller."""
    tree = {}
    for sid, meta in seats_meta.items():
        parent = meta.get("parentAgentId")
        tree[sid] = {"parent": parent if parent in seats_meta and parent != sid else None}
    for sid in tree:
        depth, cur, seen = 1, tree[sid]["parent"], {sid}
        while cur and cur not in seen:
            depth += 1
            seen.add(cur)
            cur = tree[cur]["parent"]
        tree[sid]["depth"] = depth
        tree[sid]["agent_type"] = seats_meta[sid].get("agentType", "unknown")
        tree[sid]["description"] = seats_meta[sid].get("description", "")
    return tree


def build_waves(spans):
    """Cluster subagent [start, end] spans into waves of overlapping lifetimes."""
    waves = []
    for sid, (a, b) in sorted(spans.items(), key=lambda kv: (kv[1][0], kv[0])):
        if waves and a <= waves[-1]["end"]:
            waves[-1]["end"] = max(waves[-1]["end"], b)
            waves[-1]["seats"].append(sid)
        else:
            waves.append({"start": a, "end": b, "seats": [sid]})
    return [{"wave": i, "start": w["start"].isoformat(), "end": w["end"].isoformat(),
             "seats": w["seats"]} for i, w in enumerate(waves, 1)]


def find_idle_gaps(events, minutes):
    """events: (ts, path, line) across all transcripts, any order."""
    gaps = []
    ordered = sorted(events, key=lambda e: (e[0], e[1], e[2]))
    for prev, cur in zip(ordered, ordered[1:]):
        if cur[0] - prev[0] > timedelta(minutes=minutes):
            gaps.append({"start": prev[0].isoformat(), "end": cur[0].isoformat(),
                         "minutes": round((cur[0] - prev[0]).total_seconds() / 60, 1),
                         "evidence": f"{prev[1]}:{prev[2]}"})
    return gaps


def read_lines(path):
    try:
        with open(path, errors="replace") as fh:
            return list(enumerate(fh.read().splitlines(), 1))
    except OSError:
        return []


def join_logs(temp_dir, session_id, seat_ids, window):
    logs = {"verdicts": {}, "verdict_evidence": {}, "notifications": [],
            "stop_gate_count": None, "temp_dir": temp_dir}
    vpath = os.path.join(temp_dir, "verdict-audit.log")
    for n, line in read_lines(vpath):
        m = re.search(r"agent_id=(\S+)\s+(\S+)", line)
        if m and m.group(1) in seat_ids:
            logs["verdicts"][m.group(1)] = m.group(2)
            logs["verdict_evidence"][m.group(1)] = f"{vpath}:{n}"
    npath = os.path.join(temp_dir, "sdd-notifications.log")
    lo, hi = window
    for n, line in read_lines(npath):
        t = ts(line.split(" ", 1)[0])
        if t and lo and hi and lo - timedelta(minutes=5) <= t <= hi + timedelta(minutes=5):
            logs["notifications"].append({"line": line, "evidence": f"{npath}:{n}"})
    cpath = os.path.join(temp_dir, f"stop-gate-{session_id}.count")
    for _, line in read_lines(cpath):
        if line.strip().isdigit():
            logs["stop_gate_count"] = int(line.strip())
            logs["stop_gate_evidence"] = cpath
    return logs


def analyze(session, temp_dir, idle_minutes):
    session_id = os.path.basename(session)[:-len(".jsonl")]
    base = session[:-len(".jsonl")]
    seats, models, events, spans, metas = {}, {}, [], {}, {}
    transcripts = {"main": session}
    for f in sorted(glob.glob(os.path.join(base, "subagents", "*.jsonl"))):
        sid = re.sub(r"^agent-", "", os.path.basename(f)[:-len(".jsonl")])
        transcripts[sid] = f
        metas[sid] = load_meta(f[:-len(".jsonl")] + ".meta.json")
    for sid, path in transcripts.items():
        usage, evs = read_transcript(path)
        acc = new_acc()
        for model, u, _ in usage.values():
            tok = tokens_of(u)
            accumulate(acc, model, tok)
            accumulate(models.setdefault(model, new_acc()), model, tok)
        seats[sid] = acc
        events += [(t, path, n) for t, n in evs]
        if sid != "main" and evs:
            spans[sid] = (min(t for t, _ in evs), max(t for t, _ in evs))
    total = new_acc()
    for acc in seats.values():
        for k in TOKEN_KEYS + ("calls",):
            total[k] += acc[k]
        total["cost"] += acc["cost"]
    all_ts = [e[0] for e in events]
    window = (min(all_ts), max(all_ts)) if all_ts else (None, None)
    return {
        "session": session,
        "seats": {k: seat_summary(v) for k, v in seats.items()},
        "models": {k: seat_summary(v) for k, v in sorted(models.items())},
        "totals": dict(total, unpriced_models=sorted(m for m, a in models.items() if a["unpriced"])),
        "tree": build_tree(metas),
        "waves": build_waves(spans),
        "idle_gaps": find_idle_gaps(events, idle_minutes),
        "logs": join_logs(temp_dir, session_id, set(transcripts), window),
        "transcripts": transcripts,
    }


def money(c):
    return "unpriced" if c is None else f"${c:,.4f}"


def cost_section(r):
    """Printable per-seat and per-model cost tables (also used by analyze-token-usage.py)."""
    hdr = f"{'seat':14} {'calls':>5} {'input':>10} {'output':>9} {'cache_rd':>12} {'cache_wr':>10} {'cost':>10}"
    lines = ["== Cost by seat ==", hdr]
    for sid, a in r["seats"].items():
        wr = a["cache_write_5m"] + a["cache_write_1h"]
        lines.append(f"{sid:14} {a['calls']:5d} {a['input']:10,d} {a['output']:9,d} "
                     f"{a['cache_read']:12,d} {wr:10,d} {money(a['cost']):>10}")
    lines += ["", "== Cost by model =="]
    for m, a in r["models"].items():
        wr = a["cache_write_5m"] + a["cache_write_1h"]
        lines.append(f"{m:28} {a['calls']:5d} {a['input']:10,d} {a['output']:9,d} "
                     f"{a['cache_read']:12,d} {wr:10,d} {money(a['cost']):>10}")
    t = r["totals"]
    lines.append(f"\nTOTAL (priced) {money(t['cost'])}")
    if t["unpriced_models"]:
        lines.append("unpriced models (excluded from total): " + ", ".join(t["unpriced_models"]))
    return "\n".join(lines)


def render(r):
    out = [f"SDD post-mortem: {r['session']}", "", cost_section(r), "", "== Dispatch tree =="]
    if not r["tree"]:
        out.append("(no subagent transcripts)")
    for sid, n in sorted(r["tree"].items(), key=lambda kv: (kv[1]["depth"], kv[0])):
        out.append(f"{'  ' * n['depth']}{sid} [{n['agent_type']}] {n['description']} "
                   f"depth={n['depth']} parent={n['parent'] or 'controller'}")
    out += ["", "== Wave timeline =="]
    out += [f"wave {w['wave']}: {w['start']} -> {w['end']} seats={','.join(w['seats'])}" for w in r["waves"]] \
        or ["(none)"]
    out += ["", "== Idle gaps =="]
    out += [f"{g['minutes']} min {g['start']} -> {g['end']}  evidence {g['evidence']}" for g in r["idle_gaps"]] \
        or ["(none)"]
    lg = r["logs"]
    out += ["", f"== Hook logs ({lg['temp_dir']}) =="]
    out += [f"verdict {sid}: {v}  evidence {lg['verdict_evidence'][sid]}" for sid, v in lg["verdicts"].items()]
    out += [f"notification: {n['line']}  evidence {n['evidence']}" for n in lg["notifications"]]
    if lg["stop_gate_count"] is not None:
        out.append(f"stop-gate blocks: {lg['stop_gate_count']}  evidence {lg['stop_gate_evidence']}")
    bad = [s for s, v in lg["verdicts"].items() if v == "NO_VERDICT"]
    if bad:
        out.append("FINDING: NO_VERDICT from " + ", ".join(bad))
    return "\n".join(out)


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("session")
    p.add_argument("--json", action="store_true")
    p.add_argument("--temp-dir", default="temp")
    p.add_argument("--idle-minutes", type=float, default=10)
    a = p.parse_args(argv)
    if not a.session.endswith(".jsonl") or not os.path.isfile(a.session):
        print(f"error: session transcript not found: {a.session}", file=sys.stderr)
        return 1
    r = analyze(a.session, a.temp_dir, a.idle_minutes)
    print(json.dumps(r, indent=2, default=str) if a.json else render(r))
    return 0


if __name__ == "__main__":
    sys.exit(main())
