---
name: setup
description: One-time setup of a teammate's machine for this project (Windows) — basic-memory knowledge graph, Roblox Studio, Rokit/Rojo/Wally toolchain, VS Code extensions, and the Roblox Studio MCP server for agents. Use when someone is setting up the repo, a tool is missing (rojo, wally, selene, stylua, lune, basic-memory), the Studio MCP or basic-memory MCP fails to connect, or HTTPS downloads fail with certificate errors.
---

# One-time setup for each teammate (Windows, Python 3.12+, Node 20+)

## Knowledge graph

```
python -m pip install --user uv
python -m uv tool install basic-memory
python -m uv tool run basic-memory project add sol-sandbox "<path-to-repo>/kb" --local
```
Then open the repo in your agent (Claude Code: approve the project plugins and the `basic-memory` MCP server when asked; other agents: add the same server from `.mcp.json` to your agent's MCP config, or use `node scripts/kb.mjs`). The project name must be exactly `sol-sandbox` (it is referenced in `.mcp.json`).

## Roblox toolchain

1. Install **Roblox Studio** (https://create.roblox.com/) and sign in with your own account.
2. Install **Rokit** (toolchain manager): download `rokit-<ver>-windows-x86_64.zip` from https://github.com/rojo-rbx/rokit/releases, unzip, run `rokit.exe self-install`, reopen the terminal.
3. In the repo: `rokit install` (installs the pinned rojo, wally, selene, stylua, lune from `rokit.toml`), then `wally install`.
4. Install the Rojo plugin into Studio: `rojo plugin install`. If it fails with "Couldn't find registry keys", download `Rojo.rbxm` from the same Rojo release (https://github.com/rojo-rbx/rojo/releases) into `%LOCALAPPDATA%\Roblox\Plugins\` and restart Studio.
5. VS Code: accept the recommended extensions (`.vscode/extensions.json`: Rojo, Luau Language Server, Selene, StyLua).
6. Agents ↔ Studio: in Studio open **Assistant → … → Manage MCP Servers → Enable Studio as MCP server**. Claude Code picks up the `Roblox_Studio` server from `.mcp.json` (Windows: `cmd.exe /c cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat`, the command Studio shows). Studio must be open; tools take a `studio_id` from `list_roblox_studios`.

If HTTPS downloads fail with certificate errors (antivirus/proxy re-signing traffic), run Node scripts with `node --use-system-ca`.
