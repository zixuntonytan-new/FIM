# FIM dual-laptop workflow

## Purpose

Move a bounded FIM task safely between the personal development laptop and the
Brookings/Haver work laptop without relying on OneDrive or a mutable local log.

## Branch roles

- `upstream/refactor/clean-data-pipeline`: the read-only official source.
- `origin/workflow/shared-context`: the canonical internal branch for the
  shared workflow and reviewed FIM work. It is the normal base for new tasks.
- `codex/personal/<task>` and `claude/personal/<task>`: bounded work branches
  on the personal laptop.
- `codex/work/<task>` and `claude/work/<task>`: bounded work branches on the
  work laptop.
- `integration/<task>`: optional temporary branch for combining two reviewed
  agent branches before accepting them into `workflow/shared-context`.
- `release/<date>-<purpose>`: temporary, explicit official-release candidate
  created from the exact official ref. It receives only selected, approved FIM
  commits; do not merge the internal workflow branch wholesale into upstream.

Normal sharing means push a task, integration, or release candidate to
`origin`. A user-approved merge puts reviewed work on
`workflow/shared-context`. An official push remains separately gated and uses
the specific target and release branch the user authorizes.

## Unit of transfer

Every transfer has four linked records:

1. a clean public task branch;
2. a public commit with reviewable code or approved artifacts;
3. an annotated handoff date-task-vN tag pointing at that commit; and
4. a private hutchins-agent-ops task receipt with the same transfer ID.

The public tag proves exact code. The private receipt proves input identity,
run plan or result, validation, and risk. Both are required.

## Send

1. Run the private-context preflight and read the current handoff.
2. Start from `origin/workflow/shared-context`; work only in an owned,
   bounded branch whose name includes both agent and laptop.
3. Update the private HANDOFF.md and create a new task receipt containing the
   branch, tag, input/workbook identity, command, expected outputs, validation,
   rollback, and unresolved risks.
4. Commit and push the private context.
5. Commit public FIM work, create and push the annotated handoff tag, then push
   the task branch to origin.

## Receive and run

1. Fetch the public task branch and its tags.
2. Run scripts/Start-FIM-AgentSession.ps1, which fast-forwards and checks the
   private context.
3. Verify that branch/tag, private commit, and transfer ID match the receipt.
4. Check worktree ownership, recent writes, and clean Git status.
5. Before any Haver or workbook-changing run, make the required dated backup
   and use only the stated workbook, command, acceptance checks, and rollback.

## Return

1. Create a new private return receipt with actual commands, inputs, outputs,
   validation, failures, and unresolved risks.
2. Update the private handoff and concise project log when a material decision
   or risk changed, then commit and push the private repository.
3. Commit only reviewable public code and approved artifacts. Keep Haver caches,
   credentials, and private context out of the public fork.
4. Tag and push the return branch. The receiving laptop verifies both the tag
   and private context before continuing.

## Stop conditions

Stop and record the problem if private context is unavailable or dirty, branch
and tag do not match, another agent owns a worktree, the workbook identity is
unclear, or a run would silently change FIM economics.
