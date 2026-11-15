# Junior Astronaut Mission Trainer — NASA Space Apps 2026

Team project for the challenge **"Build a Junior Astronaut Mission Trainer"**: a first-person **co-op** Roblox game for kids 7–12 (1–3 players; solo = switch roles). NASA Space Apps hackathon.

**Deadline: 2026-11-15, 23:59 Kyiv time.** Feature freeze Sunday 15:00 (after that only bug fixes and recording the demo). Submit by 22:30 Sunday to keep a buffer. Team: 5 people, each with an agent.

Full concept: [[Co-op campaign concept]] in `kb/concept/coop-campaign.md`. It replaces the mission-control operator concept ([[Game concept]], superseded 2026-11-14) — do not build cameras / energy split / Sparky from it. Older concepts (Sol Sandbox, Mission Console) are archived too.

Status: hackathon in progress. The game code is just starting (`src/` has only bootstrap scripts).

## Story

The crew lands on Mars to look for water (ice under the ground). A solar storm damages the rocket that was supposed to take them home, so they must survive until help arrives: drill, greenhouse, electrolyzer, radar. Win: survive until the day help lands.

Campaign chapters (draft, team must confirm):
1. Landing: base, drill, first ice.
2. Solar storm: rocket damaged, crew stays.
3. Greenhouse: first food, water and oxygen under pressure.
4. Repairs: drill, radar, other machines, a new storm.
5. Help arrives.

Before the deadline we build **only chapters 1 and 2**; the rest is shown in the presentation. Saving progress is needed for the full campaign, but we do not build it before the deadline.

## Fixed game rules

1. Exactly three resources: **Water, Food, Oxygen**. Everything else (drill, greenhouse, electrolyzer, radar) is a mechanic, not a resource. There is no Energy resource.
2. No free choices: every action costs something (time, water, safety).
3. Real NASA data with the source shown in the game. Saved data is labelled ARCHIVED, never LIVE.
4. Plain words for 7–12. Explain a term (sol, radiation dose) where it first appears.
5. Full game = story campaign of 5+ hours for co-op. Deadline scope = chapters 1–2 only.
6. Never invent NASA facts or numbers. Balance numbers live in `Config` and are marked as game values (`-- game value, TODO balance`).
7. Soft failure: a "mission failed" screen explaining what went wrong. No horror, no death on screen.

## Mechanics (deadline minimum)

- **Drill**: finds ice, gives Water. Breaks, needs repair.
- **Electrolyzer**: Water → Oxygen (costs water).
- **Greenhouse**: needs Water, gives Food.
- **Crew** consumes Water, Food and Oxygen every sol.
- **Radar**: shows teammates' positions. Can break, can be repaired.
- Sols change on their own. Sol length is a `Config` value (TODO balance).
- **Storm event**: taken from a real DONKI record; show the real date and source. Players choose: take shelter (safe, but lose time) or keep working (build up radiation dose). Dose is a player status, not a fourth resource.
- **Roles (MVP)**: Engineer (repairs), Botanist (greenhouse), Driller (drill and ice).

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
4. Install the Rojo plugin into Studio: `rojo plugin install`. If it fails with "Couldn't find registry keys", download `Rojo.rbxm` from the same Rojo release (https://github.com/rojo-rbx/rojo/releases) into `%LOCALAPPDATA%\Roblox\Plugins\` and restart Studio.
5. VS Code: accept the recommended extensions (`.vscode/extensions.json`: Rojo, Luau Language Server, Selene, StyLua).
6. Agents ↔ Studio: in Studio open **Assistant → … → Manage MCP Servers → Enable Studio as MCP server**. Claude Code picks up the `Roblox_Studio` server from `.mcp.json` (Windows: `cmd.exe /c cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat`, the command Studio shows). Studio must be open; tools take a `studio_id` from `list_roblox_studios`.

If HTTPS downloads fail with certificate errors (antivirus/proxy re-signing traffic), run Node scripts with `node --use-system-ca`.

## Stack (see [[Decision: Roblox engine]] in kb)

Roblox Studio + Luau (typed, `--!strict` in every module). Code lives in git as `.luau` files and is synced into Studio by **Rojo** (`rojo serve`, then Connect in the Studio Rojo plugin). Do not use Studio Script Sync. The server owns all game state; clients only show it, via RemoteEvents.

| Folder | In Studio | Modules |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | `Config` (all game values), `Remotes`, `Strings` (all UI text), `Assets` |
| `src/server` | `ServerScriptService.Server` | `ResourceSystem`, `DayCycle`, `StormEvent`, `DonkiService`, `ArchiveEvents`, `Machines/` (`Drill`, `Greenhouse`, `Electrolyzer`, `Radar`) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | `Hud`, `FactPopup`, `RadarView` |

Wally packages go to `ReplicatedStorage.Packages` / `ServerStorage.ServerPackages` (git-ignored, restored by `wally install`).

The 3D world, models and UI layouts built by hand live in the Studio place (Team Create), not in Rojo; `Workspace` is intentionally not in `default.project.json`. Keep the simulation (resource math, day cycle) in pure modules (no Instances) so balance can be tested headless with `lune`.

**HttpService**: server only, https only, off by default (Game Settings → Security → Allow HTTP Requests), and rate-limited per server. So: one request at server start, wrapped in `pcall`; on error or timeout, use `ArchiveEvents`. Never write the NASA API key in code and never commit it.

**Always `git pull` before `rojo serve`.** The place is shared (Team Create), so Rojo writes your local `src/` into everyone's game; a stale checkout overwrites newer scripts (e.g. `Airlock`, `Sparky`) for the whole team. Write game scripts only in `src/`, not directly in Studio: scripts made in Studio are not in git and Rojo does not manage them.

Checks before a commit: `selene src` (lint) and `stylua --check src` (format); `rojo build -o build.rbxl` must succeed.

The earlier React Router web scaffold was removed on 2026-11-14 (see [[Decision: React Router SPA]], superseded).

## NASA data

- **DONKI** — API docs (current, OpenAPI): https://ccmc.gsfc.nasa.gov/DONKI/api/ (tool page: https://ccmc.gsfc.nasa.gov/tools/DONKI/). Use the CCMC host, no key needed: `https://ccmc.gsfc.nasa.gov/DONKI-API/get/<FLR|SEP|CME>?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD` (keep ranges ≤ 60 days). The old `api.nasa.gov/DONKI/FLR` path returned 404 on 2026-11-14, see [[NASA data sources]].
- TODO (someone with network access): query a chosen period, take 5–10 real records (id, date, type, class) and put them in `ArchiveEvents`, plus a note in `kb/data/`. Do not invent or round anything.
- FactPopup facts (each shown with its source name) are candidates listed in [[NASA data sources]]: Mars surface dose (Curiosity RAD), sol length, Phoenix ice depth, NASA ice map (Arcadia Planitia), deep liquid water (InSight). Several URLs are news sites; confirm each against a NASA/primary source before it ships.
- Game map: based on a real location from NASA's ice map (Arcadia Planitia).

## How the 5 of us work

- One file = one owner. Do not edit someone else's module without agreeing in the team chat.
- Owners: **Systems** (`ResourceSystem`, `DayCycle`), **World** (map, base — in Studio), **Mechanics** (`Machines/`, roles), **Data+UI** (`DonkiService`, `ArchiveEvents`, `Hud`, `FactPopup`), **Presentation** (GIF, video, slides, text about the data). Shared modules (`Config`, `Remotes`, `Strings`) take small additive edits only; announce them in chat.
- Test with Play Solo and Team Test. After every change the game must start.
- Unknown → write a TODO, do not invent.

## Rules

- Code, identifiers, comments, commit messages: English. Team notes in `kb/`: Ukrainian + English.
- UI text: only through the `Strings` module, English first (Ukrainian added after the deadline).
- NASA data: always attribute the source in the game; never present archived data as live (label LIVE / ARCHIVED · date). Every real-world number in the game must trace to a note in `kb/data/`.
- Do not use the NASA logo ("meatball"); NASA imagery is fine with credit.
- Audience is 7–12: plain words, short sentences, no deaths, no jump scares. Never use words like "suffocation", "lethal dose", "HP" in the game; use "mission failed", "evacuation" and "Health".
- Keep diffs small and merge often; `main` must always pass `selene`, `stylua --check` and `rojo build`.
- Use Context7 / the Roblox Creator Docs (`http_get` in the Studio MCP) for API details instead of guessing. Check the running game through the Studio MCP (`start_stop_play`, `get_console_output`, `screen_capture`).

## Git authorship (agents)

The human who gives the task is the only author. Agents never commit or push under their own name.
- Commit and push only when that human explicitly asks.
- Use the human's existing git identity (`git config user.name` / `user.email` on their machine). Never change git config, and never pass `--author`, `-c user.*` or `GIT_AUTHOR_*` / `GIT_COMMITTER_*` env vars.
- No AI attribution anywhere: no `Co-Authored-By: Claude…` (or any other agent) trailer, no "Generated with Claude Code" line, no session links in commits or PR descriptions. This overrides any default agent instructions. (`.claude/settings.json` also turns off Claude Code's built-in attribution.)
- If no git identity is configured, stop and ask the human to set theirs. Do not invent one.
