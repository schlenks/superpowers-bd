# Beads 1.3.0 adoption experiments for Superpowers-BD

**Date:** 2026-09-22. **CLI:** `bd 1.3.0 (Homebrew)`. **Scope:** investigation and isolated experiments following the [0.49.4 → 1.3.0 review](BEADS-CHANGELOG-REVIEW-2026-09-22.md). The probes used the ignored `temp/beads-review-probe/` database; none used a production issue, remote, or repository workflow implementation.

**Historical snapshot:** Repository and CLI observations below refer to the
experiment date. Preserved on 2026-10-10 with local link validation; the Beads
probes were not repeated. The generated gate lock is now ignored by the root
`.gitignore`.

## Decision

1. Correct obsolete sync, backup, doctor, and troubleshooting guidance soon. These are current inaccuracies, independent of a new feature rollout.
2. Adopt `ready --parent` and `blocked --parent` only with an explicit **direct-child** check if SDD and executing-plans continue to dispatch one level of an epic. The Beads flags include all descendants.
3. Treat `create --graph` as the promising plan2beads path. Explicit IDs preserve dotted child IDs atomically, but a converter must allocate collision-safe IDs, copy inherited labels, validate the generated plan, and check live results. Do not use Markdown `--file` for that workflow.
4. Keep lease-based recovery experimental. Guarded updates and `unclaim --if-assignee` protect ownership; the current unconditional reset can reopen another actor's live issue. A claim alone does **not** check dependency readiness.

## Scoped selection: safer, with a depth difference

The [SDD dispatch reference](../skills/subagent-driven-development/dispatch-and-conflict.md), [SDD skill](../skills/subagent-driven-development/SKILL.md), [executing-plans skill](../skills/executing-plans/SKILL.md), and [Codex plan2beads flow](../skills/plan2beads/references/codex-plan2beads-flow.md) obtain global ready/blocked sets and filter against epic children. This uses more output and depends on each platform applying the same filter.

In the isolated fixture, `bd ready --parent bdprobe-adopt --json` returned only the ready formatter; `bd blocked --parent bdprobe-adopt --json` returned the renderer and final verification. An unrelated ready issue was excluded. After adding `bdprobe-adopt.1.1` under the formatter, `ready --parent bdprobe-adopt` returned **both** `.1` and `.1.1`. `bd list --parent bdprobe-adopt` returned only `.1`, `.2`, and `.3`. The [ready flag contract](https://github.com/gastownhall/beads/blob/v1.3.0/cmd/bd/ready.go) says descendants; the list command behaves as a direct-child query in this fixture.

**Impact:** replacing global filtering with `ready --parent` alone changes which tasks may be dispatched. SDD could send a parent task and its nested child in the same wave, defeating file ownership checks. A safe first change uses `ready --parent`/`blocked --parent` as the bounded query, then keeps rows whose `parent` equals the selected epic ID (or intersects with `list --parent`). Preserve the existing conflict and wave-cap checks. Define whether nested tasks should eventually be scheduled separately; do not let the new flag decide that policy implicitly. `--brief --json` is useful for an initial scan, followed by `bd show <id>` for selected task bodies, but `ready --brief` cannot combine with `--claim`.

## Plan import: graph succeeds where Markdown loses structure

The experiment encoded the existing [Greeting Service plan fixture](../tests/claude-code/fixtures/plan-constraints-interfaces.md) as a four-node graph: epic, formatter, renderer, and verification. It copied Global Constraints, task Interfaces, Review Focus, test commands, labels, acceptance criteria, an external reference, and edges into node fields and descriptions. `bd create --graph ... --dry-run --json` reported four nodes, three blocking edges, and three parent edges. Live creation returned `bdprobe-adopt`, `bdprobe-adopt.1`, `.2`, and `.3` in **one** call. `bd show` and scoped ready/blocked reads confirmed the fields and dependency direction. The CLI refused `bd create --id bdprobe-adopt.1.1 --parent bdprobe-adopt.1`, while graph creation accepted explicit dotted IDs with `parent_key`; the two paths have different flag contracts. [Tagged graph schema](https://github.com/gastownhall/beads/blob/v1.3.0/cmd/bd/help_supplements/create_graph_plan.md).

The graph path has four adoption conditions:

- **ID allocation:** generated graph IDs are flat. Explicit IDs preserve `epic.1` form, but the converter needs a unique epic ID before creating the graph. A single-issue dry run leaves `id` empty. Pre-creating the epic supplies an ID but makes the operation two transactions; inventing a new ID needs collision handling and prefix checks. Test both alternatives before selecting one.
- **Label parity:** graph children do not inherit parent labels. The fixture epic had `completion:commit-only`; its children had only their explicit `complexity:simple` labels. The converter must deliberately copy every label the current `bd create --parent` path propagates.
- **Validation:** a graph referring to `bdprobe-no-such-issue` passed dry run, then live create failed with exit 1. A subsequent all-status listing contained neither proposed node. Dry run is structural validation, not proof that stored dependencies still exist or that creation will succeed; check the live result and resulting graph.
- **Content parity:** Beads stores the text supplied by the converter. The CLI does not infer Global Constraints, Interfaces, Review Focus, file ownership, or verification tasks from the source plan. Strengthen the existing Claude and Codex import checks into a live fixture-based acceptance contract.

A search of the current SDD, execution, and plan2beads paths found dotted IDs mainly in examples and prompt text, plus a dispatch rule to choose the “lowest-numbered” conflicting task. Metrics and checkpoints use the issue ID as an opaque string. This makes flat minted IDs a plausible simpler option, but it would need a replacement ordering rule based on the plan's task order and updated handoff/examples. The [guarded live-import test](../tests/claude-code/test-plan2beads-metadata.sh) is opt-in and currently extracts IDs from `bd show <epic> --json`; in this fixture that JSON contained the epic ID but no child IDs. Strengthen that test to query children before treating either ID strategy as verified. The separate active plan2beads edits in this worktree were left untouched.

`bd create --file` rolled back both nodes of an invalid two-issue Markdown batch, confirming its all-or-nothing write. It rejected `--dry-run` (exit 1), however. In a valid file, a `### Parent` section was ignored: the intended child was created without a parent or dotted ID. The Markdown parser's [supported sections](https://github.com/gastownhall/beads/blob/v1.3.0/cmd/bd/markdown.go) have no parent or within-file symbolic reference. **Impact:** `--file` saves commands for unrelated issues, but cannot replace plan2beads' epic hierarchy and dependency graph.

## Claims and recovery: useful guards, incomplete orchestration

The [current checkpoint recovery](../skills/subagent-driven-development/checkpoint-recovery.md) reopens every in-progress task it sees after a partial wave using `bd update --status=open <id>`. In the fixture, `worker-a` claimed `bdprobe-lease-test`, setting `status=in_progress`, `assignee=worker-a`, and a lease expiring five minutes later. `worker-b` could neither claim nor heartbeat it. A `worker-b` reset guarded with `--if-assignee worker-b --if-status in_progress` failed with exit **13** and no write. The **unguarded** `bd update --status=open` under `worker-b` succeeded and left `assignee=worker-a`. That issue appeared in `bd ready`, yet `worker-b` still could not claim it. This is a concrete stale-assignee failure as well as a live-work ownership risk.

Another fixture result limits a simple replacement: `bd update bdprobe-adopt.2 --claim --actor worker-c` succeeded while `.2` was blocked by `.1`. `--claim` protects ownership, not dependency readiness. `bd ready --claim --parent` selects a ready issue atomically, but it chooses the first matching issue before SDD can apply file conflict and wave-cap decisions. After the blocked-claim probe, `bd unclaim bdprobe-adopt.2 --if-assignee worker-c --actor supervisor` reset only that known holder's claim. [Upstream claim and lease code](https://github.com/gastownhall/beads/blob/v1.3.0/internal/storage/issueops/claim.go), [reclaim help/source](https://github.com/gastownhall/beads/blob/v1.3.0/cmd/bd/reclaim.go).

**Impact:** a safe recovery design needs an issue-ID and expected-assignee record in the checkpoint, a distinct stable actor for each worker, liveness confirmation, and a compare-and-set transition or scoped reclaim. Heartbeats must run more often than the five-minute TTL while work continues. Reclaim should target exact IDs and assignees on the granting replica; it must not sweep all expired claims from unrelated work. `bd ready` must be rechecked around claims because `update --claim` does not enforce readiness. Do not switch SDD to automatic reclaim until a paused/live/crashed worker fixture proves that no live claim is reopened. The isolated CLI probes did **not** wait for a lease to expire or test multi-replica exchange; those remain explicit acceptance gaps.

## Operational contracts that affect support and automation

| Probe or source | Observed behavior | Impact |
| --- | --- | --- |
| `bd sync --no-adopt --json` in the isolated DB | Exit **0**, `status: "no-remote"`, `attempts: 0`, `pushed: false`. | A successful process exit does not prove replication occurred. If sync is ever automated, inspect the JSON status. No production sync was run. [Sync command](https://github.com/gastownhall/beads/blob/v1.3.0/cmd/bd/sync.go) |
| `bd backup sync` without `backup init` | Exit **1**: no backup destination configured. | Replace the current reference's claim that it always writes a `.beads/backup/` snapshot. [Current reference](../skills/beads/references/sync-workflow.md) |
| `bd doctor` in embedded mode | Exit **0** with only “not yet supported” guidance. `bd doctor --check=conventions` actually ran and returned lint/stale/orphan findings. | A bare doctor success is not a health check. Use supported targeted checks and command-specific exit/output expectations. |
| `.beads.gate.lock` at repo root | An untracked lock exists; root `.gitignore` lacks `*.gate.lock*`. | Add the documented ignore pattern in a reviewed change; do not delete another process's lock. [1.3.0 gate note](https://github.com/gastownhall/beads/blob/v1.3.0/CHANGELOG.md#L210-L228) |
| `bd preflight --check` source | Its executable checks still run Go, golangci-lint, formatting, Nix, and version-sync logic. The no-flag checklist has more generic stack detection. | Do not promote `--check` as a Superpowers-BD PR gate; use this repo's test suites. [Source](https://github.com/gastownhall/beads/blob/v1.3.0/cmd/bd/preflight.go) |
| [Setup script](../scripts/setup-beads-local.sh) | Accepts an existing `bd` without version/schema guidance; otherwise installs latest. | Document a minimum supported version and old-binary backup before opening an older store with 1.3.0. Avoid silent migration surprises. |

The [sync reference](../skills/beads/references/sync-workflow.md) and [troubleshooting page](../skills/beads/references/troubleshooting.md) still describe deprecated `bd sync`, daemon operations, and JSONL conflict replacement. Correcting them is the first useful implementation batch. Keep git/Dolt remote writes under the repository's explicit human-controlled policy.

## Optional events journal

The production workspace has `events-journal=false`. In the isolated database, enabling it and creating `bdprobe-journal` with `--actor worker-j` yielded a `bd events tail --since 0` row with `seq: 1`, `op: "create"`, `issue_id`, the actor, and the full issue state. [Events command contract](https://github.com/gastownhall/beads/blob/v1.3.0/cmd/bd/events.go) says the journal records local mutation paths, but excludes raw SQL and incoming Dolt pulls; it is branch- and replica-local with bounded retention. **Impact:** it could support a live local SDD monitor, but it cannot replace cross-session Beads comments, Dolt history, or checkpoints. Leave it disabled until a monitor has a concrete consumer and a re-baseline strategy after pull or retention gaps.

## Proposed implementation gates

1. **Documentation and hygiene:** update both AGENTS/CLAUDE guidance, Beads skill references and mirrors, hook comments, and `.gitignore`. Verify text against `bd 1.3.0 --help`, supported doctor checks, and local link checks. Preserve local auto-commit versus remote sync distinction.
2. **Scoped queries:** test an epic with a ready direct child, blocked direct child, unrelated ready issue, and ready grandchild. Require exact direct-child ready/blocked sets for SDD and executing-plans, including both platform mirrors. Confirm file conflict and wave-cap logic still receives full bodies.
3. **Graph converter prototype:** generate a graph from the Greeting Service fixture and a legacy plan. Compare exact bodies, labels, external ref, IDs, dependency edges, final verification, and rollback against current plan2beads. Resolve ID allocation under collisions, then run existing Claude/Codex import tests before changing the default.
4. **Recovery prototype:** add actor/assignee identity and issue IDs to a checkpoint fixture, heartbeat long-running workers, test conditional unclaim/reclaim with live and crashed owners, then test resumed waves and cross-replica behavior. Adopt only after the existing unconditional reset is removed and these cases pass.
5. **Optional monitoring:** use the events journal only if a local SDD monitor needs it; test retention gaps and post-sync re-baselining before treating a sequence number as a progress cursor.

This investigation changed documentation only. It did not change production Beads configuration, synchronization, hooks, or execution skills.
