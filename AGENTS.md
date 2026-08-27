# FIM agent instructions

## FIM activation status

Every substantive FIM response begins with:

`FIM activation — Stage X/7. Completed: … Remaining: … Next hard gate: …`

Until Stage 7 completes, begin work only in a clean `FIM-next` checkout or an
owned task worktree created from it. Do not begin work in `Sarah_Chase_FIM`,
the outer legacy `FIM` wrapper, an old workbench, `main`, or a historical
branch. Those locations are evidence or migration material, not task bases.

## Required session start

Before substantive analysis, debugging, code editing, workbook work, or a FIM
run:

1. Run `scripts/Start-FIM-AgentSession.ps1` from the actual Git checkout.
2. Read private `FIM/AGENT_OVERLAY.md`, `FIM/WORKING_STYLE.md`, and
   `governance/HUTCHINS_AGENT_BYLAW.md`, then private `FIM/HANDOFF.md`, recent
   `PROJECT_LOG.md` entries, and the latest official-update event.
3. Read the task-relevant public runbook and private technical reference.
4. Select the relevant shared skill from the private catalog. Do not load every
   skill.
5. State the public FIM branch or tag, private-context commit, and next action
   before editing.

If private context is missing, dirty, cannot fast-forward, or fails preflight,
stop before substantive work. Do not substitute an outer local handoff, a chat
summary, OneDrive state, or remembered context.

## Safe Git model

- `upstream/refactor/clean-data-pipeline` is the read-only official source.
- `origin/workflow/shared-context` is the canonical shared internal branch.
  It is not personal scratch space.
- Start each bounded task from the current shared branch in an owned temporary
  worktree. Use one of:
  - `codex/personal/<task>` or `claude/personal/<task>`;
  - `codex/work/<task>` or `claude/work/<task>`;
  - `integration/<task>` only to combine reviewed task branches.
- Push task and integration branches to `origin`. Only reviewed,
  user-approved work enters `workflow/shared-context`.
- For an official release, create `release/<date>-<purpose>` from the exact
  current upstream ref and select only approved commits. `upstream` remains
  push-disabled; only a task-specific user instruction authorizes an official
  PR or one-shot push.
- A cross-laptop task needs a clean public branch, an annotated handoff tag,
  and a matching immutable private task receipt. Git transfers the task;
  OneDrive does not.
- Never edit another agent's active worktree. Check recent writes, the other
  agent's session activity, and Git status first.

## FIM guardrails

- Preserve published economics, definitions, classifications, and policy
  assumptions unless the user clearly approves a change.
- Treat `data/forecast.xlsx` as a controlled workbook. Preserve formulas,
  charts, links, hidden sheets, and manual-review structure. Do not use an
  artifact-tool round trip to edit it.
- Before a Haver or Excel-changing run, record the exact workbook/input,
  command, expected outputs, acceptance checks, and rollback location in the
  private handoff and task receipt.
- Record commands actually run and outputs actually inspected. A partial run
  or earlier-stage completion is not proof of an accepted FIM result.
- Before requesting review of code or automation, run
  `scripts/Test-HutchinsPolicy.ps1` against its task base and record the
  actual validation commands and results. The policy checker does not replace
  workbook or release safeguards.

## Task routing

- Bootstrap and temporary-checkout procedure:
  `docs/operations/WORKFLOW_BOOTSTRAP.md`.
- Public cross-laptop procedure: `docs/operations/DUAL_LAPTOP_WORKFLOW.md`.
- Public code/release map: `docs/operations/FIM_MAINTAINER_GUIDE.md`.
- Public controlled-workbook safeguards:
  `docs/operations/FORECAST_WORKBOOK_BRIEFING.md`.
- Private deep references and evidence: private `FIM/README.md` after
  preflight.
