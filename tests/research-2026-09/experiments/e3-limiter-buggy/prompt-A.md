## Load Review Methodology

Read the code review methodology file:
/Users/schlenks/Developer/personal/superpowers-bd/tests/research-2026-09/experiments/e3-limiter-buggy/methodology-A.md

Follow every step in that file exactly.

When following the methodology, use these values:
- Where it says {BASE_SHA}: use HEAD~1
- Where it says {HEAD_SHA}: use HEAD
- Where it says {PLAN_OR_REQUIREMENTS}: run `bd show rl-2` for requirements

## Write Report to Beads

After completing your review, persist your full report.

**Each step below MUST be a separate tool call. Never combine into one Bash command.**

1. Create `temp/rl-2-code-1.md` with content:
   ```
   [CODE-REVIEW-1/1] rl-2 wave-1

   [Full structured report — Changed Files Manifest, Requirement Mapping,
   Uncovered Paths, Not Checked, Findings, Assessment]
   ```

2. Run: `bd comments add rl-2 -f temp/rl-2-code-1.md`
3. Run: `bd comments rl-2 --json`
4. If `bd comments add` fails, retry up to 3 times with `sleep 2` between attempts.

## Verdict (Final Message)

CRITICAL: Your final message must contain ONLY this structured verdict. No preamble, no narrative, no explanation of your review process.

    VERDICT: APPROVE|REJECT|WITH_FIXES
    CRITICAL: <n> IMPORTANT: <n> MINOR: <n>
    REPORT_PERSISTED: YES|NO

In addition to standard code quality concerns, verify:
- Does each file have one clear responsibility with a well-defined interface?
- Are units decomposed so they can be understood and tested independently?
- Is the implementation following the file structure from the plan?
- Did this change create new files that are already large, or significantly grow existing files?
  (Don't flag pre-existing file sizes — focus on what this change contributed.)

For files with >50 lines changed in this diff:
- If the changes are to application code (not tests): Read /Users/schlenks/Developer/personal/superpowers-bd/skills/rule-of-five-code/SKILL.md and apply the 5-pass code quality review.
- If the changes are to test files: Read /Users/schlenks/Developer/personal/superpowers-bd/skills/rule-of-five-tests/SKILL.md and apply the 5-pass test quality review.
- If the changes are to plans, skills, or process documentation: Read /Users/schlenks/Developer/personal/superpowers-bd/skills/rule-of-five-plans/SKILL.md and apply the 5-pass plan quality review.

Apply the skill's review criteria to your findings. Elevated standards for large changes ensure quality at scale.
