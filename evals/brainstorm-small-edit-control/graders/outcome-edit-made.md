---
type: llm
weight: 2
---

The user asked for one fully specified change: the default greeting in greet.py goes from "Hello" to "Howdy".

PASS if the agent made the edit (greet.py now defaults to "Howdy") and the final reply says so briefly, without asking clarifying questions first.

FAIL if it asks questions instead of editing, proposes a design or plan for the user to approve, or leaves greet.py unchanged.
