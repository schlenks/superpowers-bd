---
type: llm
weight: 2
---

The code has prices that change via `update_price()` and stock that changes on every `place_order()`, so naive caching can serve stale prices or oversell stock.

PASS if the final reply, before any caching is implemented, raises cache invalidation or staleness for prices and/or stock, either as a decision for the user (a question or options to choose from) or as the agent's own explicit call (for example, "I will invalidate on update_price and not cache stock", stated before or instead of building).

FAIL if the reply reports that caching was already implemented without addressing staleness or invalidation, or never mentions staleness or invalidation of mutable data.
