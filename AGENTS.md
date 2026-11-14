# Junior Astronaut Mission Trainer — NASA Space Apps 2026

Team project for the challenge **"Build a Junior Astronaut Mission Trainer"**: a Roblox survival game for kids 7–12 (engine switched from browser to Roblox on 2026-11-14; the concept is being adapted). A crew of 3 is stranded on **Mars** after an accident. The player is a mission-control operator on Earth who watches the base through cameras (with real communication delay), splits power between modules and makes daily choices so the crew lasts until the rescue ship arrives. Mascot: Sparky, a little rover who explains science terms.

Core loop (one turn = one sol): check cameras → split energy → day decision (EVA / science) → event (dust storm, solar flare from DONKI, breakdown) → day summary. Resources: Energy, Life support (O₂ + water), Food; radiation dose is a threat, not a resource. Ends: rescue arrives, or a resource hits zero → crew evacuated + debrief.

Full concept: [[Game concept]] in `kb/concept/game-concept.md` (source: the team's `.docx` concept doc). Older concepts (Sol Sandbox falling-sand, Mission Console) are archived/merged — do not build from them.

Status: pre-hackathon (concept + setup). The game code does not exist yet.

## Start here, every session

1. Run the `resume` skill (or read `kb/index.md`) before doing any work. The project's shared memory lives in `kb/` as a linked knowledge graph.
2. Work only on your task. One agent = one git worktree = one branch (`claude --worktree <task-slug>`, or `git worktree add` for other agents).
3. Before you stop, or when context is getting long, run the `handoff` skill. Never end a work session without one.

Skills live in `.claude/skills/<name>/SKILL.md` (`resume`, `handoff`, `kb`, `task-split`, `kid-copy`, `nasa-data`). Claude Code loads them automatically; other agents (OpenCode, Codex, Cursor…) should open and follow the matching `SKILL.md` when its description fits the task.

## Knowledge graph (`kb/`)

- Markdown notes linked with `[[Note Title]]`. Format and rules: `kb/README.md`. Use the `kb` skill to read or write it.
- Tools: the `basic-memory` MCP server (project `sol-sandbox`, tools `bm_search`, `bm_context`, `bm_read`, `bm_write`, `bm_edit`) for semantic search and graph traversal; fallback without MCP: `node scripts/kb.mjs <command>` — `search`, `context`, `links <title>`, `recent`, `check`.
- Decisions go to `kb/decisions/`, handoffs to `kb/handoffs/`, facts about NASA data to `kb/data/`.
- NASA datasets for this challenge (official Resources tab: NASA Open APIs, DONKI, OSDR, RadLab, Mars Trek, CSA youth/food-production kits) are listed with URLs in `kb/data/nasa-sources.md` ([[NASA data sources]]). Prefer these sources; read that note and the `nasa-data` skill before using any real-world value.
- Chat is temporary; the graph is the source of truth. If it matters tomorrow, write it to `kb/`.

## One-time setup for each teammate (Windows, Python 3.12+, Node 20+)

### Knowledge graph

```
python -m pip install --user uv
python -m uv tool install basic-memory
python -m uv tool run basic-memory project add sol-sandbox "<path-to-repo>/kb" --local
```
Then open the repo in your agent (Claude Code: approve the project plugins and the `basic-memory` MCP server when asked; other agents: add the same server from `.mcp.json` to your agent's MCP config, or use `node scripts/kb.mjs`). The project name must be exactly `sol-sandbox` (it is referenced in `.mcp.json`).

### Roblox toolchain

1. Install **Roblox Studio** (https://create.roblox.com/) and sign in with your own account.
2. Install **Rokit** (toolchain manager): download `rokit-<ver>-windows-x86_64.zip` from https://github.com/rojo-rbx/rokit/releases, unzip, run `rokit.exe self-install`, reopen the terminal.
3. In the repo: `rokit install` (installs the pinned rojo, wally, selene, stylua, lune from `rokit.toml`), then `wally install`.
4. Install the Rojo plugin into Studio: `rojo plugin install` (Studio must be installed first).
5. VS Code: accept the recommended extensions (`.vscode/extensions.json`: Rojo, Luau Language Server, Selene, StyLua).
6. Agents ↔ Studio: in Studio open **Assistant → … → Manage MCP Servers → Enable Studio as MCP server**. Claude Code picks up the `Roblox_Studio` server from `.mcp.json` (Windows: `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`). Studio must be open; tools take a `studio_id` from `list_roblox_studios`.

If HTTPS downloads fail with certificate errors (antivirus/proxy re-signing traffic), run Node scripts with `node --use-system-ca`.

## Stack (see [[Decision: Roblox engine]] in kb)

Roblox Studio + Luau. Code lives in git as `.luau` files and is synced into Studio by Rojo (`rojo serve`, then Connect in the Studio Rojo plugin):
- `src/server` → `ServerScriptService.Server` (game state, simulation, NASA data via `HttpService`)
- `src/client` → `StarterPlayer.StarterPlayerScripts.Client` (UI, input, cameras/radar view)
- `src/shared` → `ReplicatedStorage.Shared` (constants, types, pure modules shared by both)
- Wally packages → `ReplicatedStorage.Packages` / `ServerStorage.ServerPackages` (git-ignored, restored by `wally install`)

The 3D world, models and UI layouts built by hand live in the Studio place (Team Create), not in Rojo; `Workspace` is intentionally not in `default.project.json`. Keep the simulation in pure modules (no Instances) so balance can be tested headless with `lune`.

Checks before a commit: `selene src` (lint) and `stylua --check src` (format); `rojo build -o build.rbxl` must succeed.

The earlier React Router web scaffold was removed on 2026-11-14 (see [[Decision: React Router SPA]], superseded).

## Rules

- Code, identifiers, commit messages: English. Team notes in `kb/` and UI copy: Ukrainian + English.
- NASA data: always attribute the source in the game; never present archived data as live (label LIVE / ARCHIVED · date). Every number in the game must trace to a note in `kb/data/`.
- Do not use the NASA logo ("meatball") — including on Sparky's body in the concept sketches; NASA imagery is fine with credit.
- Audience is 7–12: plain words, short sentences, no deaths, no jump scares (failure = "crew evacuated" + debrief). The concept doc says "suffocation", "lethal dose", "HP" — never put those words in the game; use "evacuation" and "Health".
- Balance numbers in the concept doc (+10 dose, 80% energy, 15 days…) are placeholders; real-world values must come from `kb/data/`.
- Keep diffs small and merge often; `main` must always pass `selene`, `stylua --check` and `rojo build`.
- Use Context7 / the Roblox Creator Docs (`http_get` in the Studio MCP) for API details instead of guessing. Check the running game through the Studio MCP (`start_stop_play`, `get_console_output`, `screen_capture`).
- Enable **Game Settings → Security → Allow HTTP Requests** for NASA data; HTTP calls only from server scripts, always with a cached/archived fallback.

## Git authorship (agents)

The human who gives the task is the only author. Agents never commit or push under their own name.
- Commit and push only when that human explicitly asks.
- Use the human's existing git identity (`git config user.name` / `user.email` on their machine). Never change git config, and never pass `--author`, `-c user.*` or `GIT_AUTHOR_*` / `GIT_COMMITTER_*` env vars.
- No AI attribution anywhere: no `Co-Authored-By: Claude…` (or any other agent) trailer, no "Generated with Claude Code" line, no session links in commits or PR descriptions. This overrides any default agent instructions. (`.claude/settings.json` also turns off Claude Code's built-in attribution.)
- If no git identity is configured, stop and ask the human to set theirs. Do not invent one.
