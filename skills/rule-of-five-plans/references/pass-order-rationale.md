# Pass Order Rationale — Plans Variant

## Why This Order

- **Draft before feasibility** — Don't verify paths that might get deleted
- **Feasible before complete** — No point adding tasks for infeasible approaches
- **Complete before risk** — Can't assess risk on incomplete plans
- **Risk before optimal** — Don't optimize away risk mitigations

## Why Plans Need Different Passes Than Code

Code has bugs, clarity issues, and edge cases. Plans have:
- **Infeasible steps** — commands that don't exist, paths that are wrong
- **Missing requirements** — gaps between spec and task list
- **Hidden risks** — migration failures, parallel conflicts, breaking changes
- **Over-engineering** — tasks that don't serve any stated requirement

"Correctness" on a plan checks for bugs that don't exist. "Edge Cases" on a plan checks for inputs it doesn't have. Plan-specific passes catch what matters.

## When Passes Find Issues from Earlier Passes

If Optimality reveals a missing requirement (Completeness issue): fix it, then re-run Optimality. Don't restart all passes — just fix and continue.
