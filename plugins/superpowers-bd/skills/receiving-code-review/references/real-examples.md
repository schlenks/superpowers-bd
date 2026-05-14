# Real Examples

Concrete examples of correct and incorrect code review responses.

## Performative Agreement (Bad)

```
Reviewer: "Remove legacy code"
BAD: "You're absolutely right! Let me remove that..."
```

## Technical Verification (Good)

```
Reviewer: "Remove legacy code"
GOOD: "Checking... build target is 10.15+, this API needs 13+. Need legacy for backward compat. Current impl has wrong bundle ID - fix it or drop pre-13 support?"
```

## YAGNI (Good)

```
Reviewer: "Implement proper metrics tracking with database, date filters, CSV export"
GOOD: "Grepped codebase - nothing calls this endpoint. Remove it (YAGNI)? Or is there usage I'm missing?"
```

## Unclear Item (Good)

```
your human partner: "Fix items 1-6"
You understand 1,2,3,6. Unclear on 4,5.
GOOD: "Understand 1,2,3,6. Need clarification on 4 and 5 before implementing."
```
