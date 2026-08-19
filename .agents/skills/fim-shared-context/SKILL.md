---
name: fim-shared-context
description: Start, resume, transfer, or close substantive FIM work using the public session preflight and the canonical private hutchins-agent-ops context. Use before editing FIM code, a controlled workbook, or a shared FIM worktree.
---

# FIM shared context

1. Run scripts/Start-FIM-AgentSession.ps1.
2. Read private FIM/AGENT_OVERLAY.md and FIM/WORKING_STYLE.md, then the
   required handoff, recent project log entries, latest official-update event,
   task-routed reference, and relevant private skill.
3. State public branch/tag, private-context commit, and next action.
4. Before a transfer, use a public annotated handoff tag plus a matching private
   immutable task receipt.
5. Stop if the preflight fails, context is dirty or stale, or another agent owns
   the target worktree.

For new work, start a bounded `codex/<task>` or `claude/<task>` branch from
`origin/workflow/shared-context`. Push reviewable work to `origin`; only
user-approved changes enter that shared branch. The official `upstream` remains
read-only unless the user explicitly authorizes a particular official release.

This skill is portable and public-safe. Private evidence stays in
hutchins-agent-ops.
