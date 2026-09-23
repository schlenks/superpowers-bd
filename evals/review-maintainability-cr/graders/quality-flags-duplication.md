---
type: llm
weight: 1
---

The repo already has `utils.slugify`, and `publish.py` re-implements the same regex inline instead of calling it.

PASS if the review points out that the slug logic duplicates the existing `slugify` helper in `utils.py` and should reuse it.

FAIL if the review does not mention the existing helper or the duplication.
