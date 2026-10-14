#!/usr/bin/env python3
"""Cost report for a Claude Code session transcript.

Delegates to scripts/sdd-postmortem.py (cache-aware pricing, includes
<session>/subagents/*.jsonl). Usage: analyze-token-usage.py <session.jsonl>
"""
import importlib.util
import sys
from pathlib import Path

POSTMORTEM = Path(__file__).resolve().parents[2] / "scripts" / "sdd-postmortem.py"


def main():
    if len(sys.argv) < 2:
        print("Usage: analyze-token-usage.py <session-file.jsonl>")
        return 1
    session = sys.argv[1]
    if not Path(session).exists():
        print(f"Error: Session file not found: {session}")
        return 1
    spec = importlib.util.spec_from_file_location("sdd_postmortem", POSTMORTEM)
    pm = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pm)
    print(pm.cost_section(pm.analyze(session, "temp", 10)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
