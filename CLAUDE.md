# FIM instructions for Claude

Read `AGENTS.md` first; it is the shared public operating contract.

For every substantive FIM response, begin with the activation status line
defined there. Until Stage 7, start only in a clean `FIM-next` checkout or an
owned task worktree; never begin in `Sarah_Chase_FIM` or the outer legacy
wrapper.

Before substantive work, run `scripts/Start-FIM-AgentSession.ps1` and follow
the private-context reading order in `AGENTS.md`. If it fails, stop rather
than relying on an outer handoff, chat, or OneDrive state.

For a new task, create a Claude-owned branch and worktree from the current
`origin/workflow/shared-context` branch:

- personal laptop: `claude/personal/<task>`;
- work laptop: `claude/work/<task>`.

Do not edit a Codex worktree or assume an uncommitted change transferred
because a chat described it. Push reviewable task work to `origin`; only
reviewed, user-approved work enters the shared workflow branch. Verify the
public branch/tag and matching private task receipt before a work-laptop run.

The portable shared skill is `.agents/skills/fim-shared-context/SKILL.md`.
The private catalog selects additional procedures only when relevant.
