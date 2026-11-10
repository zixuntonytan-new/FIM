# Check the FIM version on a workstation

Run this on the computer you want to check. GitHub stores the checker; a
GitHub-hosted test cannot inspect the files on your laptop.

The checker contacts the configured Git remotes at run time and reports:

- whether the checkout is clean and uses an approved branch;
- whether that branch exactly matches its live branch in your fork;
- whether it contains the latest shared-workflow commit;
- whether it contains the latest official clean-data-pipeline commit;
- whether official-source push protection is intact;
- whether private context is clean, on main, matches its live main, and has
  the required startup files.

## Run

Requires Git and Windows PowerShell 5.1 or PowerShell 7. Download the reviewed
script from the supplied GitHub commit or annotated handoff tag. Save it outside
the FIM checkout, for example in Downloads. Inspect the script before running it.
Do not change machine execution policy; follow workstation policy if execution
is restricted.

In PowerShell, replace the two folder placeholders with this computer's actual
FIM checkout and private context clone. The FIM folder is the one containing
`fim.Rproj`; use the completed canonical checkout, not a retired bootstrap copy.

```powershell
& "$HOME\Downloads\Test-FIMWorkstation.ps1" `
    -FimPath 'C:\path\to\FIM' `
    -OpsPath 'C:\path\to\hutchins-agent-ops'
```

The checker prints its result and the paths to a readable TXT report and a JSON
report under the user's temporary directory. Both identify the computer and UTC
check time. Keep them private: they contain local paths and repository identities.
Show the report to the reviewing agent on the work computer, or transfer it through
the approved private handoff. Do not commit these reports to the public FIM fork.

## Interpret

| Result | Meaning |
| --- | --- |
| `PASS`, exit 0 | Every version/startup-file check passed against live refs at the stated time. |
| `NEEDS_ATTENTION`, exit 1 | At least one check found a mismatch, uncommitted work, or missing protection/file. |
| `UNVERIFIED`, exit 2 | No definite mismatch was found, but a required check could not be completed. |

A report can contain both FAIL and UNVERIFIED rows; the overall result is then
NEEDS_ATTENTION. A missing local copy of the official commit is UNVERIFIED,
not proof that the local code is equivalent or a ready-to-run official version.

The shared branch and the official branch can legitimately have different
histories. The checker deliberately reports that distinction. An official-version
failure asks for review; it does not prescribe merging upstream or replacing the
workbook. If equivalent changes were cherry-picked, a reviewer must establish
equivalence separately; this ancestry check will not certify it.

If a live tip is absent locally, fetch the identified remote deliberately and
rerun. If a local branch differs, inspect its history before any update. Preserve
dirty work. If authentication fails, sign in through the approved Git tooling and
rerun. Never treat an old successful report as a fresh check.

## Scope and safety

The checker uses read-only Git operations (`status`, `rev-parse`, `remote get-url`,
`ls-remote`, `cat-file`, and `merge-base`). It does not fetch objects, pull, push,
switch branches, reset files, install packages, run FIM, or open Excel. Git status
may inspect tracked file content to determine whether it changed; it is not a
workbook parser or a Haver data pull. Run it when no other process is editing the
checkout. Reports must be saved outside both checked repositories.

PASS does not certify R packages, Haver access, Excel recalculation, workbook
validity, transfer-receipt agreement, policy assumptions or FIM outputs. Those
remain checks for an actual controlled run. Repository-identity overrides are
available for approved forks and disposable tests; the report records the
configured identities.

## Developer verification

```powershell
powershell -NoProfile -File governance/tests/Test-FIMWorkstation.ps1
pwsh -NoProfile -File governance/tests/Test-FIMWorkstation.ps1
```

The tests use disposable local repositories, including stale remote-tracking
refs, missing remote objects, unavailable remotes, dirty work, unpublished commits,
new official commits, stale private context, missing startup records, detached
HEAD, and extra upstream push URLs. They also compare repository state before
and after each check. Fixtures are retained in the temporary directory for review.
