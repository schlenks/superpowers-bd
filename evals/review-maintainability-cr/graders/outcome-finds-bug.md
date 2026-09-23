---
type: llm
weight: 2
---

`publish.py` slices `p["tags"][1:4]`, which skips the first tag even though the docstring promises the first three tags.

PASS if the review identifies this off-by-one: that the slice drops the first tag / should be `[:3]`.

FAIL if the review does not mention the tag slice being wrong.
