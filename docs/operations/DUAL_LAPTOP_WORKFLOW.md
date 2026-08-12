# FIM dual-laptop workflow

## Purpose

This procedure makes the personal laptop and the Brookings/Haver work laptop
one auditable workflow without pretending that they share local instructions,
chat history, or a safe synchronized working folder.

Use GitHub `origin` to transfer reviewed task state. Keep raw Haver material,
credentials, and machine-specific settings off GitHub.

## One-time workstation setup

Each laptop needs a normal clone of the user's fork and these remotes:

```powershell
git remote -v
git remote set-url origin https://github.com/zixuntonytan-new/FIM.git
git remote set-url upstream https://github.com/Hutchins-RAs/FIM.git
git remote set-url --push upstream DISABLED
git fetch origin --prune --tags
```

If `upstream` does not yet exist, add it before setting its URLs. Do not use a
OneDrive-synced clone for long R runs when a permitted local non-sync location
is available: the August 2026 `saveRDS` failure is consistent with a sync or
file-handle conflict. A non-sync clone is an execution safeguard, not a second
source of truth; it still pulls and pushes through `origin`.

## Send a task to the work laptop

From the personal-laptop task branch:

1. Read the relevant FIM instructions and make a bounded change.
2. Update `CROSS_LAPTOP_HANDOFF.md`. Give it a new transfer tag such as
   `handoff/2026-08-12/obbba-erratum-v1`.
3. Check the intended diff and ensure the worktree is clean after committing.
4. Create the tag and push both branch and tag:

```powershell
git add <intended files>
git commit -m "Add <task> work-laptop handoff"
git tag -a handoff/YYYY-MM-DD/<task>-vN -m "Work-laptop handoff for <task>"
git push -u origin <branch>
git push origin handoff/YYYY-MM-DD/<task>-vN
```

## Receive and validate on the work laptop

Use the exact branch and tag recorded in `CROSS_LAPTOP_HANDOFF.md`:

```powershell
git fetch origin --prune --tags
git switch <branch>
git pull --ff-only origin <branch>
powershell -ExecutionPolicy Bypass -File scripts/verify_laptop_transition.ps1 `
  -ExpectedBranch <branch> `
  -ExpectedRef handoff/YYYY-MM-DD/<task>-vN `
  -RequireClean -RequireRscript
```

If the local branch does not exist yet, create it with:

```powershell
git switch --track origin/<branch>
```

The checker verifies repository identity, `origin`, the exact branch/tag commit,
and a clean working tree. It does not run FIM or change the workbook.

Before a run that can change `data/forecast.xlsx`, make a dated backup in the
approved work location. Then run only the command and acceptance checks written
in the handoff. If a Haver series, workbook sheet, or output is missing, stop
and report that evidence; do not fill a gap with a guess.

## Return results to the personal laptop

On the work laptop, update the handoff's **return record** with the actual
command, exact inputs, outputs, validation, and any failure. Commit only the
intended reviewable changes, tag the return, and push it:

```powershell
git add <intended files>
git commit -m "Record <task> work-laptop result"
git tag -a handoff/YYYY-MM-DD/<task>-v2 -m "Personal-laptop return for <task>"
git push origin <branch>
git push origin handoff/YYYY-MM-DD/<task>-v2
```

On the personal laptop, fetch tags and the branch, run the checker without
`-RequireRscript` if R is not installed there, then inspect the exact diff
before any merge or official release action.

## Boundaries

- GitHub is the bridge for code, versioned instructions, handoff records, and
  approved small release artifacts—not raw Haver downloads, secrets, or caches.
- A branch name alone is insufficient. Verify the pushed handoff tag.
- A personal-laptop and work-laptop clone are allowed to differ locally while a
  run is in progress; do not reconcile them through OneDrive or manual copying.
- The official Hutchins remote is never a routine transport channel. `origin`
  is the bridge until the user approves an official pull request or push.
