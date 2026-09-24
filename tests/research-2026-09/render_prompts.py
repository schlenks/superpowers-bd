#!/usr/bin/env python3
"""Render prompt-<arm>.md for an experiment from real skill files.

experiments/<name>/render.json:
  {
    "source": "skills/subagent-driven-development/implementer-prompt.md",
    "heading": "## Shared Implementer Prompt",
    "arms": {"A": "git:HEAD", "B": "worktree"},     # or "file:<repo-relative path>"
    "vars": {"issue_id": "inv-2", ...},
    "prefix": "optional text prepended to every arm",
    "suffix": "optional text appended to every arm"
  }
The first fenced block after `heading` is extracted, dedented, and {placeholders} filled.
Unfilled placeholders are an error so a prompt never ships with literal braces.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import textwrap
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent


def read_source(spec: str, source: str) -> str:
    if spec == "worktree":
        return (REPO / source).read_text()
    if spec.startswith("git:"):
        return subprocess.run(["git", "show", f"{spec[4:]}:{source}"], cwd=REPO, check=True,
                              capture_output=True, text=True).stdout
    if spec.startswith("file:"):
        return (REPO / spec[5:]).read_text()
    raise ValueError(spec)


def extract_block(text: str, heading: str) -> str:
    start = text.index(heading)
    m = re.search(r"^```[^\n]*\n(.*?)^```\s*$", text[start:], re.S | re.M)
    if not m:
        raise ValueError(f"no fenced block after {heading!r}")
    return textwrap.dedent(m.group(1))


def fill(block: str, variables: dict) -> str:
    def sub(m: re.Match) -> str:
        key = m.group(1)
        return str(variables[key]) if key in variables else m.group(0)
    out = re.sub(r"\{([a-z_]+)\}", sub, block)
    left = set(re.findall(r"\{([a-z_]+)\}", out))
    if left:
        raise ValueError(f"unfilled placeholders: {sorted(left)}")
    return out


def main(name: str) -> None:
    exp = HERE / "experiments" / name
    cfg = json.loads((exp / "render.json").read_text())
    for arm, spec in cfg["arms"].items():
        src = cfg.get("arm_source", {}).get(arm, cfg["source"])
        heading = cfg.get("arm_heading", {}).get(arm, cfg["heading"])
        variables = {**cfg["vars"], **cfg.get("arm_vars", {}).get(arm, {})}
        source_text = read_source(spec, src)
        # Extra fenced blocks from the same source file, appended in order (e.g. the
        # reviewer's "Append to the prompt" report/verdict block).
        blocks = [extract_block(source_text, h) for h in [heading, *cfg.get("append_headings", [])]]
        block = fill("\n".join(blocks), variables)
        text = cfg.get("prefix", "") + block + cfg.get("suffix", "")
        (exp / f"prompt-{arm}.md").write_text(text)
        print(f"{name}: prompt-{arm}.md ({len(text.split())} words) from {spec}:{src}")


if __name__ == "__main__":
    for n in sys.argv[1:]:
        main(n)
