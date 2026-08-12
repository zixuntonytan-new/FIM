# Cross-laptop handoff: portable workflow bootstrap

- Status: outbound to work laptop
- Direction: personal -> work
- Branch: `codex/portable-dual-laptop-workflow`
- Transfer tag: `handoff/2026-08-12/portable-dual-laptop-v1`
- Prepared by: Codex on the personal laptop, 2026-08-12

## Objective

Make the FIM's existing personal-laptop/work-laptop split portable. The work
laptop should receive the same FIM-only instructions, handoff format, and
transition checks through GitHub `origin` as it receives code.

## Exact transfer contents

- New repository-root `AGENTS.md` and `CLAUDE.md` with shared portable rules.
- Canonical FIM-only local skill in `.agents/skills/`, with Codex and Claude
  discovery wrappers.
- This versioned handoff, the reusable template, the full workflow guide, and
  `scripts/verify_laptop_transition.ps1`.
- No FIM calculation logic, workbook, raw Haver data, cache, credential, or
  publication artifact changed.

## Receiving-laptop preflight

```powershell
git fetch origin --prune --tags
git switch codex/portable-dual-laptop-workflow
git pull --ff-only origin codex/portable-dual-laptop-workflow
powershell -ExecutionPolicy Bypass -File scripts/verify_laptop_transition.ps1 `
  -ExpectedBranch codex/portable-dual-laptop-workflow `
  -ExpectedRef handoff/2026-08-12/portable-dual-laptop-v1 `
  -RequireClean
```

## Run plan and acceptance checks

- Exact command: run the preflight above; do not run FIM or Haver for this
  documentation-only bootstrap.
- Expected outputs: a passing preflight and the portable instructions visible
  inside the work-laptop clone.
- Checks that must pass: `origin` points to the user's fork; the branch head
  equals the transfer tag; worktree is clean.
- Backup or rollback: none needed; this branch is documentation and a small
  verification script only.

## Return record

- Command actually run: pending work-laptop receipt.
- Output locations: none.
- Validation result: pending.
- Failures or deviations: pending.
- Return tag: to be created by the receiving laptop if it records a result.
- Next owner and next action: work-laptop user/Codex verifies this bootstrap,
  then uses the template for the next real Haver task.
