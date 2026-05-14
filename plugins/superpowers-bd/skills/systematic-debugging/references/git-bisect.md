# Git Bisect for Regression Hunting

Binary search through commit history to pinpoint the exact commit that introduced a regression. Finds the answer in O(log2(N)) steps — 100 commits takes ~7 steps, 1000 takes ~10.

## When to Use

All three conditions must hold:

1. **Regression** — the bug is new ("this used to work", tests passed on a known commit)
2. **Many commits** — >10 commits between known-good and known-bad (≤10 → just read the diffs)
3. **Reproducible** — you can write a script that exits 0 (good) or 1 (bad)

**Skip bisect when:**
- Bug has always existed (no known-good commit)
- Bug depends on external state (database, API, environment)
- Flaky/nondeterministic reproduction
- You just wrote the broken code (no history to search)

## The Technique

Each step is a **separate Bash tool call** (no chaining).

### 1. Write Test Script

Write to `/tmp/bisect-test.sh` (outside the repo — files inside change across commits):

```sh
#!/bin/sh
# Build (skip if fails — not the commit's fault)
<build-command> || exit 125
# Test (bad if fails, good if passes)
<test-command> || exit 1
exit 0
```

**Exit codes:** 0 = good, 1-124 = bad, 125 = skip (build failure), 128+ = abort bisect.

### 2. Prepare Working Tree

```bash
git status              # check for uncommitted changes
```
```bash
git stash               # only if dirty — bisect needs clean working tree
```

### 3. Identify Endpoints

Find a known-good commit. Options:
- User-provided: "it worked on Monday" → `git log --before="2026-03-17" -1 --format=%H`
- Tag: `v2.3.0`
- CI: last green commit on main
- Manual: `git log --oneline -30`, test a candidate

### 4. Start and Run

```bash
chmod +x /tmp/bisect-test.sh
```
```bash
git bisect start HEAD <good-sha> -- [pathspec]
```
```bash
git bisect run /tmp/bisect-test.sh
```

The `-- [pathspec]` is optional but valuable for monorepos (see below). Use a Bash tool timeout of up to 600000ms (10 min) for slow test suites — bisect runs multiple iterations in a single command.

### 5. Read the Result

Output contains: `<sha> is the first bad commit` followed by the commit details. Use `git show <sha>` or `git diff <sha>~1 <sha>` to examine the exact changes.

**Verify the result makes sense.** If the identified commit seems unrelated to the bug, the test script may be flaky or testing the wrong thing. Run `git bisect log` before resetting to review bisect's decisions.

### 6. Clean Up (Always)

```bash
git bisect reset
```
```bash
git stash pop           # only if you stashed in step 2
```

## Monorepo Optimization

Pathspec filtering limits bisect to commits touching specific paths:

```bash
git bisect start HEAD abc123 -- packages/api/ apps/web/src/auth/
```

In a monorepo with 30 commits, maybe 8 touched the affected package. Bisect skips the rest — fewer steps, faster result.

## Safety

| Risk | Mitigation |
|------|------------|
| Dirty working tree | `git stash` before starting |
| Script changes across commits | Store in `/tmp/`, never inside the repo |
| Session crash mid-bisect | Next session: check for `.git/BISECT_START`, run `git bisect reset` |
| Detached HEAD after bisect | Always `git bisect reset` before other work |
| Build failures marked as "bad" | Use exit 125 (skip), not exit 1 |

## Edge Cases

**Merge commits:** Use `--first-parent` to treat merges as atomic units (follow mainline only):
```bash
git bisect start --first-parent HEAD <good-sha> --
```

**Commits that don't compile:** Exit 125 handles this — bisect skips to adjacent commits. If too many adjacent commits are skipped, bisect reports a range instead of a single commit.

**Flaky tests:** Run the test multiple times in your script. Mixed results should return 125 (skip). Only mark good if all runs pass.

**Multiple good commits:** Supply several to narrow the search space:
```bash
git bisect start HEAD v2.0 v1.9 v1.8 --
```
