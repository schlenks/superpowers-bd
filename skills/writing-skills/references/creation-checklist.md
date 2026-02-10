# Skill Creation Checklist (TDD Adapted)

**IMPORTANT:** Create the 3 phase tasks from `tdd-for-skills.md` first. Then use this checklist to verify each phase is complete.

## RED Phase — Write Failing Test

Must complete before GREEN:

- [ ] Create pressure scenarios (3+ combined pressures for discipline skills)
- [ ] Run scenarios WITHOUT skill — document baseline behavior verbatim
- [ ] Identify patterns in rationalizations/failures
- [ ] Mark RED task as `completed` with evidence in description

## GREEN Phase — Write Minimal Skill

Must complete before REFACTOR:

- [ ] Name uses only letters, numbers, hyphens (no parentheses/special chars)
- [ ] YAML frontmatter with only name and description (max 1024 chars)
- [ ] Description starts with "Use when..." and includes specific triggers/symptoms
- [ ] Description ≤300 chars, written in third person, NO workflow summary
- [ ] Keywords throughout for search (errors, symptoms, tools)
- [ ] Clear overview with core principle
- [ ] Address specific baseline failures identified in RED
- [ ] Code inline OR link to separate file
- [ ] One excellent example (not multi-language)
- [ ] Body ≤150 lines, reference table pointing to `references/` if needed
- [ ] Run scenarios WITH skill — verify agents now comply
- [ ] **Apply superpowers:rule-of-five to skill document** (Draft→Correctness→Clarity→Edge Cases→Excellence)
- [ ] Mark GREEN task as `completed`

## REFACTOR Phase — Close Loopholes

- [ ] Identify NEW rationalizations from testing
- [ ] Add explicit counters (if discipline skill)
- [ ] Build rationalization table from all test iterations
- [ ] Create red flags list
- [ ] Re-test until bulletproof
- [ ] Mark REFACTOR task as `completed`

## Quality Checks

- [ ] Small flowchart only if decision non-obvious
- [ ] Quick reference table
- [ ] Common mistakes section
- [ ] No narrative storytelling
- [ ] Supporting files only for tools or heavy reference (in `references/`)
- [ ] **Rule-of-five applied** (skill documents are significant artifacts)

## Validation

- [ ] `npx claude-skills-cli validate <skill> --lenient` — must pass
- [ ] Fix errors, address warnings

## Deployment

Only after all 3 phase tasks are completed:

- [ ] Commit skill to git and push to your fork (if configured)
- [ ] Consider contributing back via PR (if broadly useful)

## STOP: Before Moving to Next Skill

**After writing ANY skill, you MUST STOP and complete the deployment process.**

**Do NOT:**
- Create multiple skills in batch without testing each
- Move to next skill before current one is verified
- Skip testing because "batching is more efficient"

Deploying untested skills = deploying untested code. It's a violation of quality standards.
