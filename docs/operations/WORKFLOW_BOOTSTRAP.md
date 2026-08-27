# FIM workflow bootstrap

## Purpose

During activation, the legacy outer `FIM` folder and `Sarah_Chase_FIM` are
reference material only. They must not be used as a task base, a preflight
location, or a substitute for private context.

## Clean bootstrap

On each laptop, create a clean temporary checkout named `FIM-next` from
`origin/workflow/shared-context`. Configure `origin`, fetch-only `upstream`,
and `upstream.pushurl=DISABLED`. Set `HUTCHINS_AGENT_OPS` to the local private
`hutchins-agent-ops` clone, then run:

```powershell
./scripts/Start-FIM-AgentSession.ps1
```

Record the public commit, private-context commit, machine role, command, and
result in a private bootstrap receipt. A failed preflight is a stop condition;
do not fall back to Sarah, a workbench, or a OneDrive copy.

## New work

Keep `FIM-next` clean. Create a temporary owned worktree and branch for each
task using `codex/personal/<task>`, `claude/personal/<task>`,
`codex/work/<task>`, or `claude/work/<task>`. There are no permanent agent
workbenches.

This bootstrap proves Git and private-context transfer only. It does not
authorize a FIM calculation, Haver pull, workbook edit, or official release.
