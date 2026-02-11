# Compression Style Guide

Rules for compressing skill, command, and agent files consumed exclusively by AI.

## SAFE to Compress

1. **"Why this matters" paragraphs** — delete entirely (extract embedded rules first)
2. **Markdown tables with 1-2 columns** → `key: value` lists (EXCEPT tables with 3+ columns encoding decision logic)
3. **Motivational/rhetorical prose** — delete
4. **Repeated TaskCreate blocks** → compact sequential notation
5. **Redundant bold/emphasis** — remove when already in heading/code block
6. **Box-drawing/decorative characters** (`═══`, `───`, `╔╗`) — delete
7. **Redundant restatements** — keep detailed version, delete summary version
8. **Reference File tables** → terse `filename: condition` lists
9. **Overview sections restating frontmatter description** — delete
10. **"Skills using this pattern" lists** — Claude already has skill descriptions in system prompt
11. **Graphviz dot blocks** — delete when they restate textual rules
12. **Example Dispatch sections** — keep one example, delete duplicates
13. **Old vs New comparisons** — delete "old" when deprecated

## NEVER Compress

- Anti-rationalization tables (excuse/reality pairs)
- Iron Law code blocks
- Red Flags sections
- TaskCreate/blockedBy dependency chains (structure, not notation)
- Precision gates / gate functions
- Common Failures tables (claim/requires/not-sufficient)
- Output format specifications (VERDICT blocks)
- EXTREMELY-IMPORTANT blocks
- Frontmatter (name, description, hooks, tools, etc.)
- Reference file listings (compress format, keep every entry)

## Format Rules

- Frontmatter: unchanged
- Every reference file: still listed
- Compression metadata: `<!-- compressed: YYYY-MM-DD, original: N words, compressed: M words -->` at file bottom
- Body: <=150 lines (writing-skills convention)
- Compact task notation: `TaskCreate "Phase N: Title" (blocked_by: [N-1]) → activeForm: "Doing X"`
