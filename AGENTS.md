# FIM portable agent instructions

These instructions travel with the FIM Git repository. They apply in a clone on
either the personal or work laptop.

## Start here

Before substantive work, read in this order:

1. this file (or `CLAUDE.md` for Claude);
2. `docs/operations/CROSS_LAPTOP_HANDOFF.md` for the active transfer;
3. `docs/operations/DUAL_LAPTOP_WORKFLOW.md` for the full procedure; and
4. the relevant FIM methodology or release documentation.

The outer `FIM/HANDOFF.md` on the personal laptop remains its local, shared
Codex/Claude memory. It is not portable. The Git-tracked cross-laptop handoff
is the source of truth whenever work moves between laptops.

## Laptop roles

- **Personal laptop:** code development, static inspection, review, Git
  organization, and preparation of a reproducible task branch.
- **Work laptop:** Brookings/Haver-connected pulls, Excel/RStudio work, and
  acceptance runs that require the institutional environment.

Do not treat OneDrive synchronization as a code-transfer mechanism. Git is the
transfer mechanism: a committed branch plus a pushed handoff tag is the unit
that moves between laptops.

## Git and safety rules

- `origin` is the user's fork: `https://github.com/zixuntonytan-new/FIM.git`.
  Push normal work there.
- `upstream` is the official Hutchins repository. Keep its push URL disabled.
  Only a clear user instruction authorizes an official push.
- Work on a bounded `codex/<task>` or `claude/<task>` branch. Do not make
  substantive changes directly on a trusted baseline.
- Before handing a task to the other laptop, commit the intended files, push
  the branch to `origin`, create and push a `handoff/YYYY-MM-DD/<task>-vN` tag,
  and update `docs/operations/CROSS_LAPTOP_HANDOFF.md` in that commit.
- Before a run on the receiving laptop, fetch the branch and tags, use only a
  fast-forward pull, and run `scripts/verify_laptop_transition.ps1`.
- Never silently change FIM formulas, economic definitions, classification
  rules, or source assumptions. Flag and obtain approval for such changes.

## Agent concurrency

Separate agents may share the Git history, but never the same live worktree.
Before touching another agent's worktree, check recent writes, their session
activity, and `git status --short`. If it is busy, use a new worktree or wait.

## Work-laptop runs

Before a Haver or Excel-changing run:

1. verify the exact transfer branch/tag and a clean worktree;
2. make a dated backup of the workbook if the run can change it;
3. record the exact command, inputs, outputs, and validation criteria in the
   cross-laptop handoff; and
4. prefer a non-OneDrive working clone or cache location for R-generated
   temporary files. The existing `saveRDS` failure indicates a sync/file-handle
   risk, not an economic result.

After the run, commit only approved code, documented inputs, and intended
release artifacts. Do not commit raw Haver caches, credentials, or confidential
data. Update the cross-laptop handoff, push the branch and a new handoff tag,
then let the personal laptop review the exact returned commit.

## Teaching and reporting

Explain the relevant Git or workflow term in plain English. At handoff, report
what changed, the transfer branch/tag, the commands actually run, validation
results, and any unresolved risk.
