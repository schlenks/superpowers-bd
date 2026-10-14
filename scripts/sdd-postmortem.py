#!/usr/bin/env python3
"""Deterministic SDD post-mortem for one Claude Code session transcript.

Usage: sdd-postmortem.py <session.jsonl> [--json] [--temp-dir DIR] [--idle-minutes N]

Reads <session>.jsonl plus <session>/subagents/*.jsonl and *.meta.json and
reports: per-seat and per-model tokens and dollars (cache-aware), the dispatch
tree, a wave timeline, idle gaps (agent vs awaiting-user), joined hook logs, and
path:line evidence. Stdlib only. Same input always yields the same report.
"""
import argparse
import glob
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone

# USD per million tokens, explicit per model (cache-read multipliers differ by model).
# Source: claude-api skill pricing table, cached 2026-10-06.
# Cache writes: 5-minute = 1.25x input, 1-hour = 2x input. If a usage record does not
# split writes by TTL, all cache writes are priced as 5-minute (see tokens_of).
# Entry: (input, output, cache_read). Tiered models: list of (max_request_input_tokens, rates).
# Request input size = input + cache_read + cache_write tokens of that one request.
# ASSUMPTIONS (not in the table): claude-sonnet-5 cache_read 0.20 (same tier as Sonnet 5.5);
# haiku-5-5 cache_read = 0.1x the tier's input.
_SONNET = (2.00, 10.00, 0.20)
_OPUS_OLD = (5.00, 25.00, 0.50)
_FABLE = (10.00, 50.00, 0.25)
PRICING = {
    "claude-opus-5-5": (4.00, 20.00, 0.20),
    "claude-sonnet-5-5": _SONNET,
    "claude-sonnet-5": _SONNET,
    "claude-haiku-5-5": [(100_000, (0.10, 0.50, 0.01)), (None, (0.50, 2.50, 0.05))],
    "claude-fable-5-1": _FABLE,
    "claude-fable-5": _FABLE,
    "claude-opus-5": _OPUS_OLD,
    "claude-opus-4-8": _OPUS_OLD,
    "claude-haiku-4-5": (1.00, 5.00, 0.10),
}
# Models whose cache_read rate above is an assumption, not a table value.
ASSUMED_CACHE_READ = {"claude-sonnet-5", "claude-haiku-5-5"}
# Placeholder messages Claude Code writes without calling a model: free.
FREE_MODELS = {"<synthetic>"}
UNKNOWN_MODEL = "unknown (embedded toolUseResult, model unknown)"

TOKEN_KEYS = ("input", "output", "cache_read", "cache_write_5m", "cache_write_1h")


def norm_model(model):
    if not isinstance(model, str) or not model:
        return "?"
    return re.sub(r"-\d{8}$", "", re.sub(r"\[.*?\]$", "", model))


def ts(value):
    """Parse an ISO timestamp; naive values are assumed UTC so they compare with aware ones."""
    try:
        t = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        return None
    return t if t.tzinfo else t.replace(tzinfo=timezone.utc)


def num(value, what, warnings):
    """Coerce a token count: ints pass, numeric strings convert, anything else is 0 + warning."""
    if value is None:
        return 0
    if isinstance(value, bool):
        warnings.append(f"{what}: boolean token count treated as 0")
        return 0
    if isinstance(value, (int, float)):
        return int(value)
    if isinstance(value, str) and re.fullmatch(r"\s*\d+\s*", value):
        return int(value)
    warnings.append(f"{what}: non-numeric token count {value!r} treated as 0")
    return 0


def tokens_of(u, where, warnings):
    cc = u.get("cache_creation")
    if cc is not None and not isinstance(cc, dict):
        warnings.append(f"{where}: cache_creation is not an object; using cache_creation_input_tokens")
        cc = {}
    cc = cc or {}
    w5 = num(cc.get("ephemeral_5m_input_tokens"), where, warnings) if "ephemeral_5m_input_tokens" in cc else None
    w1 = num(cc.get("ephemeral_1h_input_tokens"), where, warnings) if "ephemeral_1h_input_tokens" in cc else None
    if w5 is None and w1 is None:
        w5, w1 = num(u.get("cache_creation_input_tokens"), where, warnings), 0
    return {
        "input": num(u.get("input_tokens"), where, warnings),
        "output": num(u.get("output_tokens"), where, warnings),
        "cache_read": num(u.get("cache_read_input_tokens"), where, warnings),
        "cache_write_5m": w5 or 0,
        "cache_write_1h": w1 or 0,
    }


def price(model, tok):
    if model in FREE_MODELS:
        return 0.0
    rates = PRICING.get(model)
    if not rates:
        return None
    if isinstance(rates, list):
        size = tok["input"] + tok["cache_read"] + tok["cache_write_5m"] + tok["cache_write_1h"]
        rates = next(r for limit, r in rates if limit is None or size <= limit)
    i, o, cr = rates
    return (tok["input"] * i + tok["output"] * o + tok["cache_read"] * cr
            + tok["cache_write_5m"] * 1.25 * i + tok["cache_write_1h"] * 2 * i) / 1_000_000


def is_user_prompt(ev):
    """A human prompt: user event with plain-string content, not a tool result or agent notification."""
    if ev.get("type") != "user" or ev.get("toolUseResult") is not None:
        return False
    origin = ev.get("origin")
    if isinstance(origin, dict) and origin.get("kind") not in (None, "human"):
        return False
    msg = ev.get("message")
    return isinstance(msg, dict) and isinstance(msg.get("content"), str) \
        and not msg["content"].lstrip().startswith("<")


def _tool_use_ids(msg):
    content = msg.get("content") if isinstance(msg, dict) else None
    return [b["id"] for b in content if isinstance(b, dict) and b.get("type") == "tool_use"
            and isinstance(b.get("id"), str)] if isinstance(content, list) else []


def _embedded_usage(ev):
    """(agentId, model|None, usage) from a user event's toolUseResult, else None."""
    res = ev.get("toolUseResult")
    if ev.get("type") == "user" and isinstance(res, dict) and isinstance(res.get("agentId"), str) \
            and isinstance(res.get("usage"), dict):
        return res["agentId"], (norm_model(res["model"]) if res.get("model") else None), res["usage"]
    return None


def _scan_event(ev, n, path, out, warnings):
    if isinstance(ev.get("cwd"), str):
        out["cwd"] = out["cwd"] or ev["cwd"]
    t = ts(ev.get("timestamp"))
    if t:
        out["events"].append((t, n, is_user_prompt(ev)))
    msg = ev.get("message")
    out["tool_ids"].update(_tool_use_ids(msg))
    emb = _embedded_usage(ev)
    if emb:
        out["embedded"].append(emb + (n,))
    if ev.get("type") == "assistant" and isinstance(msg, dict) and "usage" in msg:
        if not isinstance(msg["usage"], dict):
            warnings.append(f"{path}:{n}: usage is not an object; message skipped")
            return
        mid = msg["id"] if isinstance(msg.get("id"), str) and msg["id"] else f"line{n}"
        out["usage"][mid] = (norm_model(msg.get("model")), msg["usage"], n)


def read_transcript(path, warnings):
    """Return dict: usage {msg_id: (model, usage, line)}, events [(ts, line, is_prompt)],
    tool_ids, cwd, embedded [(agentId, model, usage, line)] from user toolUseResult records."""
    out = {"usage": {}, "events": [], "tool_ids": set(), "cwd": None, "embedded": []}
    try:
        with open(path, errors="replace") as fh:
            lines = list(enumerate(fh, 1))
    except OSError as exc:
        warnings.append(f"{path}: unreadable ({exc.strerror or exc})")
        return out
    for n, line in lines:
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(ev, dict):
            _scan_event(ev, n, path, out, warnings)
    return out


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
    """Cost is None when nothing was priceable; 'partial' when priced and unpriced models mix."""
    out = dict(acc)
    out["partial"] = acc["unpriced"] and acc["cost"] > 0
    if acc["unpriced"] and acc["cost"] == 0.0:
        out["cost"] = None
    return out


def load_meta(path):
    """Read a meta.json; only string-valued known fields survive."""
    try:
        with open(path) as fh:
            meta = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {}
    if not isinstance(meta, dict):
        return {}
    return {k: v for k, v in meta.items()
            if k in ("agentType", "description", "parentAgentId", "toolUseId") and isinstance(v, str)}


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
    """events: (ts, path, line, is_prompt) across all transcripts, any order.

    Returns (agent_gaps, awaiting_user_gaps). A gap ending in a human prompt is the
    user thinking, not a hang.
    """
    agent, user = [], []
    ordered = sorted(events, key=lambda e: (e[0], e[1], e[2]))
    for prev, cur in zip(ordered, ordered[1:]):
        if cur[0] - prev[0] > timedelta(minutes=minutes):
            gap = {"start": prev[0].isoformat(), "end": cur[0].isoformat(),
                   "minutes": round((cur[0] - prev[0]).total_seconds() / 60, 1),
                   "evidence": f"{prev[1]}:{prev[2]}"}
            (user if cur[3] else agent).append(gap)
    return agent, user


def read_lines(path):
    try:
        with open(path, errors="replace") as fh:
            return list(enumerate(fh.read().splitlines(), 1))
    except OSError:
        return []


def _parse_verdict_line(line, seat_ids):
    """Return (agent_id, kind, status) for a verdict-audit.log line, else None."""
    m = re.search(r"agent_id=(\S+)\s+(.*)$", line)
    if not m or m.group(1) not in seat_ids:
        return None
    sid, rest = m.group(1), m.group(2).strip()
    if rest.startswith("VERDICT_GATE_GIVEUP"):
        return sid, "giveup", "VERDICT_GATE_GIVEUP"
    if rest.startswith("NO_VERDICT"):
        return sid, "no_verdict", "NO_VERDICT"
    if rest.startswith("VERDICT:"):
        return sid, "verdict", (rest[len("VERDICT:"):].split() or ["UNKNOWN"])[0]
    return None


def _summarize_verdicts(logs):
    for sid, evs in logs["verdict_events"].items():
        real = [e for e in evs if e["kind"] == "verdict"]
        last_real = evs.index(real[-1]) if real else -1
        if real:
            logs["verdicts"][sid] = real[-1]["status"]
        # Missing: a NO_VERDICT or give-up with no real verdict after it.
        if any(e["kind"] != "verdict" for e in evs[last_real + 1:]):
            logs["verdicts"].setdefault(sid, "NO_VERDICT")
            logs["no_verdict"].append(sid)
        if any(e["kind"] == "giveup" for e in evs):
            logs["gate_giveups"].append(sid)


def _join_notifications(npath, window):
    lo, hi = window
    out = []
    for n, line in read_lines(npath):
        t = ts(line.split(" ", 1)[0])
        if t and lo and hi and lo - timedelta(minutes=5) <= t <= hi + timedelta(minutes=5):
            out.append({"line": line, "evidence": f"{npath}:{n}"})
    return out


def join_logs(temp_dir, session_id, seat_ids, window):
    logs = {"verdicts": {}, "verdict_events": {}, "no_verdict": [], "gate_giveups": [],
            "notifications": [], "stop_gate_count": None, "temp_dir": temp_dir}
    vpath = os.path.join(temp_dir, "verdict-audit.log")
    # Formats (hooks/verdict-audit.sh, hooks/codex-verdict-audit.sh):
    #   <ts> agent_type=T agent_id=I VERDICT: <STATUS> ...
    #   <ts> agent_type=T agent_id=I NO_VERDICT
    #   <ts> agent_id=I VERDICT_GATE_GIVEUP after N blocks
    for n, line in read_lines(vpath):
        parsed = _parse_verdict_line(line, seat_ids)
        if parsed:
            sid, kind, status = parsed
            logs["verdict_events"].setdefault(sid, []).append(
                {"kind": kind, "status": status, "evidence": f"{vpath}:{n}"})
    _summarize_verdicts(logs)
    logs["notifications"] = _join_notifications(os.path.join(temp_dir, "sdd-notifications.log"), window)
    cpath = os.path.join(temp_dir, f"stop-gate-{session_id}.count")
    for _, line in read_lines(cpath):
        if line.strip().isdigit():
            logs["stop_gate_count"] = int(line.strip())
            logs["stop_gate_evidence"] = cpath
    return logs


def _discover_subagents(base):
    transcripts, metas = {}, {}
    for f in sorted(glob.glob(os.path.join(base, "subagents", "*.jsonl"))):
        if not os.path.isfile(f):
            continue
        sid = re.sub(r"^agent-", "", os.path.basename(f)[:-len(".jsonl")])
        transcripts[sid] = f
        metas[sid] = load_meta(f[:-len(".jsonl")] + ".meta.json")
    return transcripts, metas


def _resolve_parents(metas, launched_by):
    """Parent = transcript holding the tool_use that launched the subagent (meta.toolUseId)."""
    for sid, meta in metas.items():
        owner = launched_by.get(meta.get("toolUseId"))
        if owner and owner != "main" and owner != sid:
            meta["parentAgentId"] = owner
        elif owner == "main":
            meta.pop("parentAgentId", None)


def _resolve_temp_dir(temp_dir, cwd):
    if temp_dir is not None:
        return temp_dir, "--temp-dir"
    if cwd:
        return os.path.join(cwd, "temp"), "transcript cwd"
    return "temp", "default ./temp"


def _collect_usage(transcripts, warnings):
    """Walk every transcript. Returns seats, models, events, spans, launched_by, embedded_seats, cwd."""
    seats, models, events, spans, launched_by, embedded, cwd = {}, {}, [], {}, {}, {}, None

    def add(seat, model, usage_obj, where):
        tok = tokens_of(usage_obj, where, warnings)
        accumulate(seats.setdefault(seat, new_acc()), model, tok)
        accumulate(models.setdefault(model, new_acc()), model, tok)

    for sid, path in transcripts.items():
        data = read_transcript(path, warnings)
        cwd = cwd or data["cwd"]
        launched_by.update(dict.fromkeys(data["tool_ids"], sid))
        seats.setdefault(sid, new_acc())
        for model, u, line in data["usage"].values():
            add(sid, model, u, f"{path}:{line}")
        for agent_id, model, u, line in data["embedded"]:
            embedded.setdefault(agent_id, []).append((model, u, f"{path}:{line}"))
        events += [(t, path, n, p) for t, n, p in data["events"]]
        if sid != "main" and data["events"]:
            spans[sid] = (min(e[0] for e in data["events"]), max(e[0] for e in data["events"]))
    # Workers with no child transcript: fall back to the parent's toolUseResult usage.
    # Agents that have a child transcript are never counted from here (no double counting).
    embedded_seats = [a for a in sorted(embedded) if a not in transcripts]
    for agent_id in embedded_seats:
        for model, u, where in embedded[agent_id]:
            add(agent_id, model or UNKNOWN_MODEL, u, where)
    return seats, models, events, spans, launched_by, embedded_seats, cwd


def analyze(session, temp_dir, idle_minutes):
    """temp_dir None: use <transcript cwd>/temp when recorded, else ./temp."""
    session_id = os.path.basename(session)[:-len(".jsonl")]
    warnings = []
    transcripts, metas = _discover_subagents(session[:-len(".jsonl")])
    transcripts = {"main": session, **transcripts}
    seats, models, events, spans, launched_by, embedded_seats, cwd = _collect_usage(transcripts, warnings)
    _resolve_parents(metas, launched_by)
    temp_dir, temp_dir_source = _resolve_temp_dir(temp_dir, cwd)
    idle, awaiting = find_idle_gaps(events, idle_minutes)
    total = new_acc()
    for acc in seats.values():
        for k in TOKEN_KEYS + ("calls", "cost"):
            total[k] += acc[k]
    all_ts = [e[0] for e in events]
    window = (min(all_ts), max(all_ts)) if all_ts else (None, None)
    return {
        "session": session,
        "seats": {k: dict(seat_summary(v), source="toolUseResult" if k in embedded_seats else "transcript")
                  for k, v in seats.items()},
        "models": {k: dict(seat_summary(v), assumed_cache_read=k in ASSUMED_CACHE_READ)
                   for k, v in sorted(models.items())},
        "totals": dict(total, unpriced_models=sorted(m for m, a in models.items() if a["unpriced"])),
        "tree": build_tree(metas),
        "waves": build_waves(spans),
        "idle_gaps": idle,
        "awaiting_user_gaps": awaiting,
        "logs": dict(join_logs(temp_dir, session_id, set(transcripts) | set(embedded_seats), window),
                     temp_dir_source=temp_dir_source),
        "warnings": warnings,
        "transcripts": transcripts,
    }


def money(a):
    c = a["cost"]
    if c is None:
        return "unpriced"
    return f"${c:,.4f}" + ("+" if a.get("partial") else "")


def cost_section(r):
    """Printable per-seat and per-model cost tables (also used by analyze-token-usage.py)."""
    hdr = f"{'seat':14} {'calls':>5} {'input':>10} {'output':>9} {'cache_rd':>12} {'cache_wr':>10} {'cost':>10}"
    lines = ["== Cost by seat ==", hdr]
    for sid, a in r["seats"].items():
        wr = a["cache_write_5m"] + a["cache_write_1h"]
        note = "  [from parent toolUseResult; model unknown - unpriced]" if a["source"] == "toolUseResult" \
            and a["cost"] is None else ("  [from parent toolUseResult]" if a["source"] == "toolUseResult" else "")
        lines.append(f"{sid:14} {a['calls']:5d} {a['input']:10,d} {a['output']:9,d} "
                     f"{a['cache_read']:12,d} {wr:10,d} {money(a):>10}{note}")
    lines += ["", "== Cost by model =="]
    for m, a in r["models"].items():
        wr = a["cache_write_5m"] + a["cache_write_1h"]
        lines.append(f"{m:28} {a['calls']:5d} {a['input']:10,d} {a['output']:9,d} "
                     f"{a['cache_read']:12,d} {wr:10,d} {money(a):>10}")
    t = r["totals"]
    lines.append(f"\nTOTAL (priced) ${t['cost']:,.4f}   ('+' = seat mixes priced and unpriced models)")
    for m, a in r["models"].items():
        if a.get("assumed_cache_read"):
            rate = PRICING[m]
            rate = rate[0][1][2] if isinstance(rate, list) else rate[2]
            lines.append(f"ASSUMED cache-read rate for {m}: ${rate}/MTok (not in the pricing table)")
    if t["unpriced_models"]:
        lines.append("unpriced models (excluded from total): " + ", ".join(t["unpriced_models"]))
    return "\n".join(lines)


def _gap_lines(gaps):
    return [f"{g['minutes']} min {g['start']} -> {g['end']}  evidence {g['evidence']}"
            for g in gaps] or ["(none)"]


def _log_lines(lg):
    out = [f"== Hook logs ({lg['temp_dir']}, from {lg['temp_dir_source']}) =="]
    for sid, evs in lg["verdict_events"].items():
        out += [f"verdict {sid}: {e['status']}  evidence {e['evidence']}" for e in evs]
    out += [f"notification: {n['line']}  evidence {n['evidence']}" for n in lg["notifications"]]
    if lg["stop_gate_count"] is not None:
        out.append(f"stop-gate blocks: {lg['stop_gate_count']}  evidence {lg['stop_gate_evidence']}")
    if lg["no_verdict"]:
        out.append("FINDING: NO_VERDICT (no real verdict after) from " + ", ".join(lg["no_verdict"]))
    if lg["gate_giveups"]:
        out.append("FINDING: verdict gate gave up on " + ", ".join(lg["gate_giveups"]))
    return out


def render(r):
    out = [f"SDD post-mortem: {r['session']}", "", cost_section(r), "", "== Dispatch tree =="]
    if not r["tree"]:
        out.append("(no subagent transcripts)")
    for sid, n in sorted(r["tree"].items(), key=lambda kv: (kv[1]["depth"], kv[0])):
        out.append(f"{'  ' * n['depth']}{sid} [{n['agent_type']}] {n['description']} "
                   f"depth={n['depth']} parent={n['parent'] or 'controller'}")
    out += ["", "== Wave timeline =="]
    out += [f"wave {w['wave']}: {w['start']} -> {w['end']} seats={','.join(w['seats'])}"
            for w in r["waves"]] or ["(none)"]
    out += ["", "== Idle gaps over threshold (agent/hang) =="] + _gap_lines(r["idle_gaps"])
    out += ["", "== Awaiting user (human think time, not a hang) =="] + _gap_lines(r["awaiting_user_gaps"])
    out += [""] + _log_lines(r["logs"])
    if r["warnings"]:
        out += ["", f"== Warnings ({len(r['warnings'])}) =="] + r["warnings"]
    return "\n".join(out)


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("session")
    p.add_argument("--json", action="store_true")
    p.add_argument("--temp-dir", default=None,
                   help="hook log dir (default: <transcript cwd>/temp, else ./temp)")
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
