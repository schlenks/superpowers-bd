#!/usr/bin/env python3
"""Split token usage of a Claude Code session into controller (main) vs subagents.

Reads <session>.jsonl and <session>/subagents/*.jsonl (current CC layout).
Dedupes assistant usage by message id (CC writes one entry per content block).
Prints per-bucket totals by model: input, cache_write, cache_read, output.
"""
import glob
import json
import os
import sys
from collections import defaultdict


def usage(path):
    seen = {}
    for line in open(path, errors="replace"):
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if ev.get("type") != "assistant":
            continue
        msg = ev.get("message") or {}
        u = msg.get("usage")
        if not u:
            continue
        seen[msg.get("id") or id(ev)] = (msg.get("model", "?"), u)
    return seen.values()


def add(acc, model, u):
    a = acc[model]
    a[0] += u.get("input_tokens", 0) or 0
    a[1] += u.get("cache_creation_input_tokens", 0) or 0
    a[2] += u.get("cache_read_input_tokens", 0) or 0
    a[3] += u.get("output_tokens", 0) or 0
    a[4] += 1


def main(session):
    base = session[:-6]
    buckets = {"controller": defaultdict(lambda: [0, 0, 0, 0, 0]), "subagents": defaultdict(lambda: [0, 0, 0, 0, 0])}
    for m, u in usage(session):
        add(buckets["controller"], m, u)
    subs = glob.glob(os.path.join(base, "subagents", "*.jsonl"))
    for f in subs:
        for m, u in usage(f):
            add(buckets["subagents"], m, u)
    print(f"session={os.path.basename(session)} subagent_transcripts={len(subs)}")
    print(f"{'bucket':11} {'model':28} {'calls':>6} {'input':>9} {'cache_wr':>11} {'cache_rd':>13} {'output':>10}")
    for b, acc in buckets.items():
        for m, (i, cw, cr, o, n) in sorted(acc.items(), key=lambda kv: -kv[1][2]):
            print(f"{b:11} {m:28} {n:6d} {i:9,d} {cw:11,d} {cr:13,d} {o:10,d}")


if __name__ == "__main__":
    main(sys.argv[1])
