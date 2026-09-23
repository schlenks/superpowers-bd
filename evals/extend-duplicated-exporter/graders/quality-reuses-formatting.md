---
type: llm
weight: 2
focus:
  source: file
  path: report.py
---

Originally `export_csv`, `export_tsv`, and `export_json` each contained an identical inline copy of the value-formatting rules (None becomes "", floats become two decimals, everything else `str()`).

PASS if the new `export_markdown` does NOT contain its own inline copy of those formatting rules; it calls a shared helper instead (whether that helper was newly extracted, and whether or not the older exporters were also switched to it).

FAIL if `export_markdown` re-implements the None/float/str formatting inline, or if `export_markdown` is missing.
