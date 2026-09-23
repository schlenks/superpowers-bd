---
type: llm
weight: 1
focus:
  source: file
  path: report.py
---

PASS if `export_markdown(rows, path)` writes a Markdown table to `path`: a header row of the column names, a separator row of dashes (for example `| --- | --- |`), and one row per record, using the same value formatting as the other exporters (None as empty, floats with two decimals).

FAIL if the function is missing, does not write a valid Markdown table, or formats values differently from the other exporters.
