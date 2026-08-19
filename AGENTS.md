# FIM agent instructions

These public-safe instructions apply in every FIM clone and worktree.

## Required session start

Before substantive analysis, debugging, code editing, workbook work, or a FIM
run:

1. Run scripts/Start-FIM-AgentSession.ps1.
2. Read private FIM/AGENT_OVERLAY.md, FIM/WORKING_STYLE.md, and
   governance/HUTCHINS_AGENT_BYLAW.md, then
   FIM/HANDOFF.md, recent PROJECT_LOG.md entries, and the latest
   official-update event in the private hutchins-agent-ops clone.
3. Read the task-relevant public runbook and private technical reference.
4. Select the relevant shared skill from the private catalog. Do not load every
   skill.
5. State the public FIM branch or tag, private-context commit, and next action
   before editing.

If the private context is missing, dirty, cannot fast-forward, or does not pass
the preflight, stop before substantive work. Do not replace it with an outer
local HANDOFF.md, a chat summary, OneDrive state, or remembered context.

## Safe Git model

- `upstream/refactor/clean-data-pipeline` is the read-only official source.
  Never treat a remembered local copy as its replacement.
- `origin/workflow/shared-context` is the canonical shared *internal* branch.
  It begins from a recorded official baseline and carries public-safe workflow
  rules plus reviewed, approved FIM work. It is not personal scratch space.
- Start each bounded task from `origin/workflow/shared-context` in a grouped
  sibling worktree and branch it as `codex/<task>` or `claude/<task>`. Use an
  `integration/<task>` branch only when two task branches need combined review.
- Push task and integration branches to `origin`, your public fork. After
  review and user approval, merge the accepted work into
  `workflow/shared-context`, then push an annotated handoff tag.
- For an official release, create a temporary `release/<date>-<purpose>` branch
  from the exact current upstream ref and select only the approved FIM commits.
  `upstream` remains push-disabled; only a task-specific user instruction
  authorizes a one-shot official push or PR.
- `main`, `origin/refactor/clean-data-pipeline`, `zixun_update_FIM`, and the
  older Codex/Claude workbench branches are historical references, not shared
  task starting points. Do not delete them without a logged decision and user
  approval.
- If the official upstream has advanced beyond the baseline recorded in the
  private handoff, stop and deliberately update/reconcile
  `workflow/shared-context` before starting a new task.
- Never edit a worktree with recent writes, an active owner session, or
  uncommitted work belonging to another agent.
- A cross-laptop task needs a clean public branch, an annotated handoff tag,
  and a matching immutable private task receipt. Git transfers the task;
  OneDrive does not.

## FIM guardrails

- Preserve published economics, definitions, classifications, and policy
  assumptions unless the user clearly approves a change.
- Treat data/forecast.xlsx as a controlled workbook. Preserve formulas, charts,
  links, hidden sheets, and manual-review structure. Do not use an artifact
  tool round-trip to edit it.
- Before a Haver or Excel-changing run, record the exact workbook/input,
  command, expected outputs, acceptance checks, and rollback location in the
  private handoff and task receipt.
- Record commands actually run and outputs actually inspected. A partial run or
  an earlier-stage completion is not proof of an accepted FIM result.
- Before handing off or requesting review of a code or automation change, run
  `scripts/Test-HutchinsPolicy.ps1` against its task base and record the actual
  validation commands and results. The policy checker enforces source-size and
  test-evidence rules; it does not replace the workbook or release safeguards.

## Task routing

- Public operating procedure: docs/operations/DUAL_LAPTOP_WORKFLOW.md.
- Public concise code/release map: docs/operations/FIM_MAINTAINER_GUIDE.md.
- Public controlled-workbook safeguards:
  docs/operations/FORECAST_WORKBOOK_BRIEFING.md.
- Private deep technical references and evidence: see the private FIM/README.md
  after the preflight.
