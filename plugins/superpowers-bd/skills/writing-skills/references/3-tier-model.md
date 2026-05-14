# 3-Tier Progressive Disclosure Model

Skills use three tiers of progressive disclosure to minimize token consumption while keeping full detail accessible:

## Level 1: Frontmatter (Always Loaded, ~30 tokens)

```yaml
---
name: skill-name
description: Use when [triggering conditions only]
---
```

- Loaded into every conversation where the skill is registered
- Only `name` and `description` fields (skills have no other frontmatter)
- Description = triggering conditions ONLY (never workflow summaries)
- Max 1024 characters total, aim for ≤300 chars in description

## Level 2: SKILL.md Body (Loaded on Trigger, ≤150 lines)

The main skill document loaded when Claude decides the skill applies.

**Contains:**
- Quick Start (what to do NOW)
- Core principles (the non-negotiable rules)
- Reference table (what's in `references/`, when to read each file)
- Common mistakes (most frequent errors)

**Decision criterion:** "What do I do right now?" → belongs in Level 2

**Budget:** ≤150 body lines, ≤2000 words (enforced by `claude-skills-cli validate --lenient`)

## Level 3: References (Loaded on Demand, Unlimited)

Files in `references/` directory, loaded only when the agent needs deep detail.

**Contains:**
- Detailed guides, checklists, and worked examples
- Full rationalization tables and anti-patterns
- Testing methodology and pressure scenario design
- API/syntax references and heavy documentation

**Decision criterion:** "How do I do this well?" → belongs in Level 3

## Validation

```bash
npx claude-skills-cli validate <skill-dir> --lenient
```

Must pass before committing. Checks:
- Body line count (≤150 lines)
- Word count (≤2000 words)
- Frontmatter validity
- Description format

## Why This Matters

Every token in Level 1-2 loads into context for **every** conversation where the skill triggers. A 726-line SKILL.md burns ~3000 tokens per invocation. A 140-line body with references on demand burns ~600 tokens, loading the other ~2400 only when actually needed.
