# Cross-laptop handoff: `<task>`

- Status: `outbound to work laptop` / `returned to personal laptop` / `complete`
- Direction: personal -> work / work -> personal
- Branch:
- Transfer tag: `handoff/YYYY-MM-DD/<task>-vN`
- Prepared by and timestamp:

## Objective

## Exact transfer contents

- Code or document changes:
- Input workbook/data identity:
- Intentionally excluded files:

## Receiving-laptop preflight

```powershell
git fetch origin --prune --tags
git switch <branch>
git pull --ff-only origin <branch>
powershell -ExecutionPolicy Bypass -File scripts/verify_laptop_transition.ps1 `
  -ExpectedBranch <branch> -ExpectedRef handoff/YYYY-MM-DD/<task>-vN -RequireClean
```

## Run plan and acceptance checks

- Exact command:
- Expected outputs:
- Checks that must pass:
- Backup or rollback location:

## Return record

- Command actually run:
- Output locations:
- Validation result:
- Failures or deviations:
- Return tag:
- Next owner and next action:
