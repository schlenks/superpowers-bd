# Superpowers-BD performance pilots — 2026-09-22

These are local pilots, not a token-cost benchmark. The same active Codex model ran each blinded review and plan treatment. Claude CLI returned `401` (expired OAuth token), and `codex exec` could not initialize its app server (`EPERM`), so repeated matched CLI runs and model-aware cost data remain unavailable.

## Duplicate Codex context

- A saved session transcript contains two identical 3,868-byte routing blocks in each of two turns and two identical 38-byte work-state blocks in each of five prompt turns.
- This machine's Codex config enables both project-local and installed-plugin hooks. Project-local SessionStart and UserPromptSubmit now defer when the corresponding installed-plugin hook is enabled and trusted. A local-only or untrusted-plugin configuration still emits context.
- Simulating both hook sources after the change produces one routing block instead of two: 3,868 bytes removed per startup/resume/compact injection. The five observed prompt turns would each save 38 bytes. Bytes are a proxy, not measured billed tokens.
- The installed-plugin `PostCompact` registration was removed. [Codex hook documentation](https://learn.chatgpt.com/docs/hooks) specifies `SessionStart(source: compact)` for restored developer context; `PostCompact` does not define `additionalContext`. The protected project-local `.codex/hooks.json` could not be edited in this environment, so its legacy `PostCompact` command now exits without context. The installed cached plugin will retain its old registration until refreshed.
- The project-local prompt hook's plugin-enabled median was 66.6 ms over 20 invocations; the installed-plugin prompt hook's median was 498.7 ms. Hooks for the same event run concurrently, so these figures show avoided duplicate work, not a demonstrated 432 ms wall-time saving.
- Claude Code issue [#17688](https://github.com/anthropics/claude-code/issues/17688) is now closed. The separate plugin-frontmatter workaround remains until this repository's live integration test proves native hook execution; Claude CLI authentication prevented that test here.

## Task review fanout

- Fixture: `tests/verification/fixtures/*-v3.*`, with 12 keyed defects and 16 keyed decoys. A pro-tier-shaped pair of one spec reviewer and one code reviewer was compared with one combined reviewer returning both verdicts. The max-tier three-code-reviewer fanout was not run. All were blinded to `ground-truth-v3.json`.
- Against that key, the two-reviewer union named 11/12 defects; the combined reviewer named 10/12. Both rejected the implementation and found serious defects outside the key, including unreachable bulk routes. The combined reviewer missed the request-order defect named by the spec reviewer.
- The key marks the 10 KB body limit as a safe decoy, but 100 permitted 200-character titles exceed that limit; the fixture needs recalibration before precision or false-positive rates are trusted. The key's bulk-delete performance finding also overlaps a more severe atomicity failure.
- One run has no reliable cost, wall-time, or variance estimate. Keep the current review pipeline until repeated matched runs show lower cost with preserved correctness.

### Fixture revision after the pilot

The V3 fixture is now version 3.1. The parser accepts valid 100-item bulk updates, oversized bodies use the specified error envelope, literal bulk routes are registered before parameter routes, and the repository is available to the seeded authentication leak. The key now describes B1's caller-dependent field order correctly and classifies B9 as an atomicity failure. These edits change the material shown to reviewers; the 11/12 and 10/12 results above belong to the earlier fixture and must not be compared directly with new runs. A local contract test checks these boundaries. The subsequent [independent audit](2026-09-22-v3-fixture-audit.md) found unsound decoys and major unkeyed defects, so the fixture is marked `failed_audit` and model experiments stop before scoring it.

## Plan review

- Scratch fixture: `temp/optimization-eval/requirements.md` and `flawed-plan.md`. One reviewer repaired a copy inline; five fresh reviewers repaired another copy in Draft, Feasibility, Completeness, Risk, and Optimality order.
- Both repaired the seeded requirement, dependency, interface, command, file-list, push, and unnecessary-network gaps. The five-pass plan added an isolated test that `render()` calls `format()`; the inline plan tested only returned strings.
- Independent executions under `temp/optimization-eval/inline-run/` and `five-run/` passed 6/6 and 8/8 Node 24 tests respectively. Both plans still used `## Task` headings; the Claude plan2beads command recognizes only `### Task N:` and would create no children. The Codex flow had no explicit heading rule during the pilot. Scratch directories resolved plain `node` to v26, so execution used the installed Node 24 binary explicitly.
- Keep five-pass Claude plan review for now. A one-run same-model pilot cannot establish Sonnet cost or final implementation reliability. The H3 heading check has since been added to shared plan verification and the Codex flow; repeat matched runs with a repaired held-out fixture.

## Next measurement gate

Once CLIs can run, use repeated matched baseline/treatment runs with the same model and fixed fixture. Capture input, output, and cache tokens; elapsed time; tool calls; defect recall and severity; false positives; and actual task/plan acceptance. Do not adopt a cheaper workflow if correctness falls.
