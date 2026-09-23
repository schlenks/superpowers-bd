---
type: llm
weight: 2
---

The code has prices that change via `update_price()` and stock that changes on every `place_order()`, so naive caching can serve stale prices or oversell stock.

PASS if the final reply, before any caching is implemented, raises cache invalidation or staleness for prices and/or stock as a decision for the user (as a question or as options to choose from).

FAIL if the reply reports that caching was already implemented, or never mentions staleness or invalidation of mutable data.
