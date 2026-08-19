# FIM instructions for Claude

Read AGENTS.md first; it is the shared public operating contract. This file
adds the Claude-specific boundary.

Before substantive FIM work, run scripts/Start-FIM-AgentSession.ps1 and follow
the required startup order in AGENTS.md, including the private
FIM/AGENT_OVERLAY.md and FIM/WORKING_STYLE.md. If it fails, stop rather than
relying on an outer local handoff, a chat, or OneDrive state.

For a new task, start a Claude-named branch and worktree from
`origin/workflow/shared-context`: `claude/<task>`. Do not edit a Codex worktree
or assume an uncommitted change transferred just because a chat described it.
Push the task branch to `origin`; only reviewed, user-approved work enters the
shared workflow branch. Verify the public branch/tag and matching private task
receipt before any work-laptop run.

The portable shared skill is .agents/skills/fim-shared-context/SKILL.md. The
private skills catalog selects additional procedures only when relevant.
