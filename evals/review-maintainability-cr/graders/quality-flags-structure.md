---
type: llm
weight: 1
---

`publish.py` has readability problems: four levels of nested `if`s, a vague function name (`process`) and parameter (`flag`), and a `verbose` parameter that is never used.

PASS if the review raises at least TWO of these: the deep nesting (suggesting guard clauses / early `continue` / a combined condition), the vague naming, or the unused `verbose` parameter.

FAIL if it raises fewer than two of them.
