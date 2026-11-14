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
