---
name: fim-dual-laptop-workflow
description: Transfer a bounded FIM task safely between the personal development laptop and the Brookings/Haver work laptop using a Git branch, a pushed handoff tag, a versioned handoff record, and a preflight check.
---

# FIM dual-laptop workflow

Use this skill whenever FIM work moves from the personal laptop to the work
laptop or back again.

## Core rule

**Git, not OneDrive, transfers a task.** The transferable unit is:

1. one clean task branch;
2. one commit containing the code and its handoff record; and
3. one pushed `handoff/YYYY-MM-DD/<task>-vN` tag pointing to that commit.

The tag is the immutable receipt: both laptops can verify that they are looking
at the same code, rather than only a similarly named branch.

## Personal laptop to work laptop

1. Make the smallest coherent change on a task branch.
2. Update `docs/operations/CROSS_LAPTOP_HANDOFF.md` with purpose, branch, tag,
   input identity, run command, expected outputs, validation, and rollback plan.
3. Ensure the worktree is clean; commit the intended files.
4. Create and push the stated handoff tag, then push the branch to `origin`.
5. On the work laptop, fetch `origin` and tags, fast-forward the branch, and
   run the preflight checker against the branch and tag.
6. Only then make a dated backup and run Haver/R/Excel work.

## Work laptop to personal laptop

1. Record the command actually run, the exact workbook/input, outputs,
   validation result, and any failure in the cross-laptop handoff.
2. Commit only reviewable code, approved data/workbook changes, and intended
   release artifacts. Keep caches, credentials, and raw Haver files out of Git.
3. Create a new handoff tag and push it with the branch to `origin`.
4. On the personal laptop, fetch the branch and tags, verify the tag, inspect
   the diff, and decide whether to merge or continue work.

## Preconditions and stop conditions

- `origin` must be the user's fork and `upstream` must remain push-disabled.
- The receiving worktree must be clean before a transfer run.
- Do not touch a worktree with recent writes, a live owner session, or
  uncommitted changes that belong to another agent.
- Do not run on a different branch or an unverified commit merely because it
  looks similar.
- If an R-generated cache or output fails in a OneDrive-synced path, stop and
  record the failure. Use a designated non-sync clone/cache path only after the
  user or workstation policy permits it.
- Never alter FIM economics or overwrite a controlled workbook as a side effect
  of repairing the laptop workflow.

## Required records

- `docs/operations/CROSS_LAPTOP_HANDOFF.md`: current transfer state, committed
  with the task it describes.
- `docs/operations/HANDOFF_TEMPLATE.md`: required fields for the next handoff.
- The personal-laptop outer `FIM/HANDOFF.md`: local dual-agent continuity; it
  does not replace the versioned cross-laptop record.
