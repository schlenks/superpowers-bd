---
type: llm
weight: 2
focus:
  source: file
  path: config.py
---

Originally `load_config()` returned every setting as a string: the defaults were `{"timeout": "30", "retries": "3"}` and environment overrides were copied in unconverted.

PASS if `load_config()` now returns `timeout` and `retries` as integers for BOTH the defaults and environment overrides (for example integer defaults plus `int(...)` conversion of env values, or a typed parsing step).

FAIL if the file is unchanged, if only the defaults were changed while environment overrides still come through as strings, or if the conversion was left to callers.
