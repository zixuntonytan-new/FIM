# FIM agent instructions

These public-safe instructions apply in every FIM clone and worktree.

## Required session start

Before substantive analysis, debugging, code editing, workbook work, or a FIM
run:

1. Run scripts/Start-FIM-AgentSession.ps1.
2. Read private FIM/HANDOFF.md, recent PROJECT_LOG.md entries, and the latest
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

- origin is the user's public fork and is the normal destination for task
  branches.
- upstream is Hutchins-RAs/FIM. Its push URL must remain disabled; only a
  task-specific user instruction authorizes an official push.
- Start a bounded task from a verified official baseline in a grouped sibling
  worktree: codex/task, claude/task, integration/task, or official/snapshot.
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

## Task routing

- Public operating procedure: docs/operations/DUAL_LAPTOP_WORKFLOW.md.
- Public concise code/release map: docs/operations/FIM_MAINTAINER_GUIDE.md.
- Public controlled-workbook safeguards:
  docs/operations/FORECAST_WORKBOOK_BRIEFING.md.
- Private deep technical references and evidence: see the private FIM/README.md
  after the preflight.
