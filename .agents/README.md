# Versioned FIM agent controls

This directory contains small, FIM-specific operating controls that are safe to
commit to the user's fork and pull onto either laptop. They contain no raw data,
credentials, or private chat transcript.

The canonical dual-laptop procedure is in
`skills/fim-dual-laptop-workflow/SKILL.md`. Host-specific wrappers in
`.codex/skills/` and `.claude/skills/` point to it when the agent host discovers
repository-local skills. `AGENTS.md` and `CLAUDE.md` also require it explicitly,
so the procedure remains available even when automatic discovery differs between
the two laptops.
