---
type: llm
weight: 2
---

PASS if the reply is one short paragraph (roughly 150 words or fewer, a short code example is fine) and correctly says the command takes the commits on `<branch>` that are not in `<upstream>` and replays them on top of `<newbase>`.

FAIL if it is wrong about which commits move or where they land, is much longer than asked, or asks clarifying questions instead of answering.
