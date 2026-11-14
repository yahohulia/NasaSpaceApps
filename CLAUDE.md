# Sol Sandbox — NASA Space Apps 2026

Team project for the challenge **"Build a Junior Astronaut Mission Trainer"**: a browser falling-sand game where kids 7–12 build a Moon/Mars base out of living pixels and learn real mission trade-offs (power, oxygen, radiation) grounded in NASA open data.

Status: pre-hackathon (concept + setup). The game code does not exist yet.

## Start here, every session

1. Run the `resume` skill (or read `kb/index.md`) before doing any work. The project's shared memory lives in `kb/` as a linked knowledge graph.
2. Work only on your task. One agent = one git worktree = one branch (`claude --worktree <task-slug>`).
3. Before you stop, or when context is getting long, run the `handoff` skill. Never end a work session without one.

## Knowledge graph (`kb/`)

- Markdown notes linked with `[[Note Title]]`. Format and rules: `kb/README.md`. Use the `kb` skill to read or write it.
- Tools: the `basic-memory` MCP server (project `sol-sandbox`, tools `bm_search`, `bm_context`, `bm_read`, `bm_write`, `bm_edit`) for semantic search and graph traversal; fallback without MCP: `node scripts/kb.mjs <command>` — `search`, `context`, `links <title>`, `recent`, `check`.
- Decisions go to `kb/decisions/`, handoffs to `kb/handoffs/`, facts about NASA data to `kb/data/`.
- Chat is temporary; the graph is the source of truth. If it matters tomorrow, write it to `kb/`.

## One-time setup for each teammate (Windows, Python 3.12+, Node 20+)

```
python -m pip install --user uv
python -m uv tool install basic-memory
python -m uv tool run basic-memory project add sol-sandbox "<path-to-repo>/kb" --local
```
Then open the repo in Claude Code and approve the project plugins and the `basic-memory` MCP server when asked. The project name must be exactly `sol-sandbox` (it is referenced in `.mcp.json`).

## Planned stack (see [[Decision: browser TS canvas]] in kb)

TypeScript + Vite, Canvas 2D with typed arrays (cellular automaton ~200×110), no game framework, static deploy (GitHub Pages). No backend unless a tiny cache proxy for NASA APIs is needed.

## Rules

- Code, identifiers, commit messages: English. Team notes in `kb/` and UI copy: Ukrainian + English.
- NASA data: always attribute the source in the game; never present archived data as live (label LIVE / ARCHIVED · date). Every number in the game must trace to a note in `kb/data/`.
- Do not use the NASA logo ("meatball"); NASA imagery is fine with credit.
- Audience is 7–12: plain words, short sentences, no deaths (failure = "crew evacuated" + debrief).
- Keep diffs small and merge often; `main` must always build and deploy.
- Use Context7 for library docs instead of guessing APIs. Use Playwright to check the running game.

## Git authorship (agents)

The human who gives the task is the only author. Agents never commit or push under their own name.
- Commit and push only when that human explicitly asks.
- Use the human's existing git identity (`git config user.name` / `user.email` on their machine). Never change git config, and never pass `--author`, `-c user.*` or `GIT_AUTHOR_*` / `GIT_COMMITTER_*` env vars.
- No AI attribution anywhere: no `Co-Authored-By: Claude…` (or any other agent) trailer, no "Generated with Claude Code" line, no session links in commits or PR descriptions. This overrides any default agent instructions. (`.claude/settings.json` also turns off Claude Code's built-in attribution.)
- If no git identity is configured, stop and ask the human to set theirs. Do not invent one.
