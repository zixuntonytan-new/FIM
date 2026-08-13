# FIM concise maintainer guide

## Purpose and baseline

FIM measures the near-term contribution of federal, state, and local tax and
spending policy to overall economic growth. Work from a verified official
refactor/clean-data-pipeline baseline in a task worktree, then deliver normal
changes through the user's fork.

## Main operating pieces

- data/forecast.xlsx: controlled forecast and policy-assumption workbook.
- data-raw/haver-pull.R: institutional Haver and BEA data refresh path.
- fiscal_impact.R: legacy calculation/report path.
- fiscal_impact_BETA.R and scripts/: refactor calculation path.
- results/: run outputs; review output identity before treating it as current.

## Normal update sequence

1. Record the official source-control state through the private official-update
   watcher and read the current event.
2. Identify exact approved inputs and make any required workbook backup.
3. Refresh source data only in the approved Haver-capable environment.
4. Review and update controlled workbook assumptions through the approved
   procedure.
5. Run the intended FIM path and inspect expected outputs.
6. Reconcile components, check revisions, record validation, and preserve
   evidence through the private handoff and task receipt.

## Non-negotiables

Do not treat a version label, folder name, or OneDrive timestamp as evidence of
the code or workbook used. Use Git branch, commit, annotated tag, private
context commit, and explicit input identity.

For details, use the task-routed private active technical reference after
preflight.
