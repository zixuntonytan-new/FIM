# FIM portable Claude instructions

This is the work-laptop-safe companion to `AGENTS.md`. Claude must read it
before changing FIM code or running a FIM workflow in any clone.

## Mandatory read order

1. `CLAUDE.md`;
2. `docs/operations/CROSS_LAPTOP_HANDOFF.md`;
3. `docs/operations/DUAL_LAPTOP_WORKFLOW.md`; and
4. the relevant FIM input, methodology, or release notes.

## Shared operating model

The personal laptop is for development and Git review. The work laptop is for
Haver-connected and Excel/RStudio execution. A laptop handoff is not complete
until the sender has committed and pushed the task branch, pushed its handoff
tag, and the receiver has verified that exact ref before running.

Use `origin` (the user's fork) for normal task branches. `upstream` is official
Hutchins and must remain push-disabled unless the user explicitly authorizes a
particular official push. Never force-push without an explicit user request.

## Claude boundary

Use a Claude-named task branch/worktree for implementation. Do not edit a
Codex worktree, and do not assume an uncommitted change exists on the other
laptop merely because a chat described it. Git branch + handoff tag + clean
preflight are the evidence that it transferred.

Before a work-laptop run, follow the preflight in
`docs/operations/DUAL_LAPTOP_WORKFLOW.md`. Record the command, input-workbook
identity, outputs, validation, and any failure in the cross-laptop handoff
before returning work to the personal laptop.

The canonical reusable procedure is
`.agents/skills/fim-dual-laptop-workflow/SKILL.md`.
