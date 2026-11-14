# Junior Astronaut Mission Trainer — NASA Space Apps 2026

A Roblox game for kids 7–12: keep a stranded Mars crew alive until rescue arrives, using real NASA data (DONKI space weather, Curiosity RAD radiation, OSDR).

## Quick start (Windows)

1. Install [Roblox Studio](https://create.roblox.com/) and sign in.
2. Install [Rokit](https://github.com/rojo-rbx/rokit/releases) (`rokit.exe self-install`), then in this folder:
   ```sh
   rokit install      # rojo, wally, selene, stylua, lune (pinned in rokit.toml)
   wally install      # Luau packages
   rojo plugin install
   rojo serve         # then press Connect in the Rojo plugin in Studio
   ```
3. Before committing: `selene src`, `stylua --check src`, `rojo build -o build.rbxl`.

Code lives in `src/` (`server`, `client`, `shared`). Project rules for people and AI agents: [`AGENTS.md`](AGENTS.md). Team knowledge base: [`kb/index.md`](kb/index.md).

## Codex + Roblox Studio (Windows)

1. In the Codex app, open this repository as a local project and trust it when prompted. Codex uses `AGENTS.md` for project instructions; it does not use the Claude `.mcp.json` configuration. Project MCP settings live in [`.codex/config.toml`](.codex/config.toml).
2. In Studio, open **Assistant → … → Manage MCP Servers**, enable **Studio as MCP server**, and turn on **ChatGPT (codex)** under **Quick connect**. This registers `Roblox_Studio` in your user-level Codex configuration; keep Studio open with the intended place loaded.
3. Install and register the shared knowledge base (requires `uv` on PATH; the first command downloads dependencies):
   ```powershell
   uv tool install basic-memory
   uv tool run basic-memory project add sol-sandbox "X:\Projects\NasaSpaceApps\kb" --local
   ```
   Replace the path with your checkout's absolute `kb` path. The project name must stay `sol-sandbox`. The repository's Codex configuration runs this server through `uv` directly, so `python -m uv` is not required.
4. Restart Codex or start a fresh session after configuration changes. Ask it: **“Read AGENTS.md and kb/index.md, then call list_roblox_studios. Do not change the place yet.”** A successful Studio tool call verifies the connection; the Quick connect toggle alone does not.

If a Basic Memory install was interrupted, repair it with `uv tool install --force basic-memory` before registering the project. Without Basic Memory, Codex can still read `kb/` directly and use `node scripts/kb.mjs`.

If Studio reports no clients, confirm the server is enabled in Codex's MCP settings and start a new session. If tools report authorization errors, restart Studio and Codex and re-enable Quick connect. Studio MCP shares requested game data with your AI provider; review Roblox's notice before enabling it.
