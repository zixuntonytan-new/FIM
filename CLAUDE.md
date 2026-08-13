# FIM instructions for Claude

Read AGENTS.md first; it is the shared public operating contract. This file
adds the Claude-specific boundary.

Before substantive FIM work, run scripts/Start-FIM-AgentSession.ps1 and follow
its required private-context reading. If it fails, stop rather than relying on
an outer local handoff, a chat, or OneDrive state.

Use a Claude-named task branch and worktree. Do not edit a Codex worktree or
assume an uncommitted change transferred just because a chat described it.
Verify the public branch/tag and matching private task receipt before any
work-laptop run.

The portable shared skill is .agents/skills/fim-shared-context/SKILL.md. The
private skills catalog selects additional procedures only when relevant.
