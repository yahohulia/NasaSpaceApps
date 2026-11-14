# Agent instructions

All project instructions live in `CLAUDE.md` — read it first. This file exists for agents that look for `AGENTS.md` (OpenCode, Codex, etc.).

Short version:
- Shared memory is the knowledge graph in `kb/` (start with `kb/index.md`, format in `kb/README.md`).
- Skills are in `.claude/skills/*/SKILL.md` — read `resume` at the start and follow `handoff` at the end of every session.
- Graph tool: `node scripts/kb.mjs search|links|recent|check`.
- Git: never commit or push under your own name. Commit/push only when the human who gave the task asks, using their existing git identity. No `Co-Authored-By` agent trailers, no "Generated with …" lines. Details: "Git authorship (agents)" in `CLAUDE.md`.
