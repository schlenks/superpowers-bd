# Pass Order Rationale

## Why This Order

- **Breadth before depth** - Don't polish what might get deleted
- **Correct before clear** - Fix bugs before wordsmithing
- **Clear before robust** - Understand it before edge-casing it
- **Robust before excellent** - Handle failures before polishing

## Why It Works

LLMs solve problems breadth-first: broad strokes first, then refinement. Single-shot generation stops at "broad strokes." Multiple passes force the depth work humans do naturally when revising.

At 4-5 iterations, output "converges"--the point where further passes yield diminishing returns.

## When Passes Find Issues from Earlier Passes

If Excellence reveals a bug (Correctness issue): fix it, then re-run Excellence. Don't restart all passes--just fix and continue.

## Origin

Jeffrey Emanuel's observations on LLM iteration convergence. Academic validation: [Self-Refine](https://arxiv.org/abs/2303.17651) (Madaan et al., 2023).
