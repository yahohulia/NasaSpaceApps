# Morning report: night build, 2026-11-15

Place: team game (Team Create) "Untitled Game", placeId 99201616522797, owner Maria_Strawberi.
All new objects have the `MB_` prefix. Other people's objects and scripts were not deleted or renamed.
Rojo-managed scripts were not touched. Copies of every MB script are in `studio/MB/` (selene + stylua: 0 errors).

## ⚠️ Read first

1. **No git commits were made.** `git config user.name / user.email` is empty on this Mac, and the project
   rules (AGENTS.md) forbid agents from setting or inventing an identity. Every file is ready in the worktree
   `.claude/worktrees/hud` (branch `worktree-hud`). Once you set your name:
   `git config --global user.name "…"` and `git config --global user.email "…"`, then ask me to commit.
2. **Not every step could be checked with 2 players.** The Studio MCP can only start Play Solo
   (`start_stop_play`); "Test → Clients and Servers" and "Test → Device" can't be started from the tools.
   Everything below was checked in Play Solo and in your own live playtest (Output: 0 errors from MB scripts).
3. **Studio reconnected 4 times overnight, and you were playtesting at the same time.** Two client scripts
   (`MB_Music` new version, `MB_MissionClient`) may still be waiting to be installed. See the table.
4. **Someone else is also making `MB_` objects** (`MB_SolarPanels`, `MB_RoofColliders`, `MB_CorridorRebuild`)
   and changed `MB_Config` (`NormalWalkSpeed` 10). The **MB_AirlockLamp script disappeared**, so its job is now done by
   `MB_Atmosphere`. I did not touch the other people's MB objects.
5. `DEBUG_FAST = false` (in `MB_Config`).

## Tasks

| # | Task | Status | Notes |
|---|---|---|---|
| 1 | Core check | ✅ done | Zones fixed: the bedroom was missing; copies of the team's 9 `BaseZone` volumes were added to `MB_HabitatZone` (127 zones). E points moved from the old dome to the new base: water → WaterStation, vegetables → Farm, rest → Bedroom (checked: all inside). Power on the HUD now comes from the MB system (dust, storms, generator) instead of the team's EnergyState. No death: an empty suit → the player is brought back inside. Respawn keeps attributes (player-level). |
| 2 | Radiation storm from NASA data | ✅ done | `MB_SolarEvents`: 18 real flares from DONKI. Every 1–2 sols (the first one after 90 s): red ☢ bubble with a timer (30 s warning + 60 s storm). Outside: +15 μGy/s to `Player.Dose` (the team's radiation system reads it), suit air ×2, no solar power. Inside: safe. After the storm, one line for 4 s: "Real event: X8.7 flare, 2024-05-14 (NASA DONKI)". |
| 3 | Radar | ✅ done | Teammate dots relative to the camera direction (already there). New: it breaks every 0.6–1.5 sols → red ring + ✕, no dots; "Repair radar" (3 s) at `MB_RadarAntenna` outside (0, −112), the light on the mast is red/green. |
| 4 | Jobs outside | ✅ done | `MB_SolarField`: 6 panels south-west of the base (−30, −172). Dust settles (~11 min to full, ×3 during a storm) → power down to 25 %; "Clean" (2 s). `MB_Samples`: 6 glowing rocks in a ring at (−70, −60), "Collect sample" (1.5 s), HUD counter (rock icon + "2/6", shared by the crew). |
| 5 | Victory | ✅ done (server) / ⚠️ client | Survive 5 sols AND collect 6/6 → the console button turns green → "Launch" at `MB_LaunchConsole` (75, 4, 12, south edge of the rocket pad). Not ready → a message with what is left. The launch/"Mission complete"/"Play again" screen is in `MB_MissionClient` (written, may still need installing). "Play again" restarts the mission for everyone. Achievement "Mission complete!". |
| 6 | Tutorial | ✅ done | 5 steps (go outside → clean a panel → collect a sample → eat/drink → rest) + a checked fact for each, in a small hint at the top. The team's Checkpoints were not used: their script waits for `Workspace.Checkpoints`, but the part is named `Сheckpoints` (Cyrillic "С"), so it never runs. Steps are detected from game events instead. |
| 7 | Sound | ✅ done / ⚠️ install | `MB_SoundConfig` (installed): day, night, storm, wind, steps; empty id = silence. The new `MB_Music` (volume 0.3, storm music, wind outside) may still need installing; the old version works until then (day/night 6:00/18:00). |
| 8 | Atmosphere | ✅ done | `MB_Atmosphere`: `Workspace.Gravity = 74.5` at start, 9 lamp posts `MB_BaseLights` around the base (on 18:30–5:30), airlock lamp green/red during a storm. |
| 9 | Phone and FPS | ⚠️ partly | Device test can't be started from the tools. Checked: nothing of mine is in the lower half except the touch Run button (a control) and the PC-only Shift hint; the achievement card moved to the upper half (y 0.37). Not checked: FPS on a phone. |
| + | Base distance label | ✅ done | `MB_BaseMarker` (your request): "⌂ Base · 45 m" over the airlock; off-screen it sticks to the edge with an arrow, only in the upper half; hidden inside the base. |

## Created scripts and objects

ReplicatedStorage: `MB_Config` (changed), `MB_SolarEvents` (new), `MB_SoundConfig` (new), `MB_BaseState` (attributes), `MB_Notify`, `MB_Mission`, `MB_Achievement` (RemoteEvents).
ServerScriptService: `MB_ResourceServer` (rewritten), `MB_Missions` (new), `MB_Atmosphere` (new), `MB_Achievements`.
ServerStorage: `MB_ResetMission`, `MB_AwardAchievement` (BindableEvents), `MB_Backup_CorridorRails`.
StarterPlayerScripts: `MB_HUD` (changed), `MB_Footsteps` (changed), `MB_AchievementToast` (moved), `MB_Tutorial` (new), `MB_BaseMarker` (new), `MB_Music` (new version, install), `MB_MissionClient` (new, install), `MB_Sprint`, `MB_SparkyTyping`.
Workspace: `MB_SolarField` (6 panels), `MB_Samples` (6), `MB_RadarAntenna`, `MB_LaunchConsole`, `MB_BaseLights` (9), `MB_HabitatZone` (+9 zone copies), `MB_Interactables` (3 moved), `MB_AirlockPorch`, `MB_CorridorRailCovers`.

## How to check each feature in 1 minute

Tip: set `Config.DEBUG_FAST = true` in `MB_Config` (1 sol = 60 s, storms within ~1 min) → Play. Set it back to `false` after.
- **Inside / outside:** walk out through the airlock → the red suit bar goes down; walk in → it fills up, and the Air bar (left) goes down.
- **Storm:** wait ~2 min (DEBUG_FAST: <1 min) → red ☢ bubble with a timer; the airlock lamp turns red; stand outside → the green radiation bar on the left grows; after the storm → "Real event: …" for 4 s.
- **Radar:** in Command Bar (server): `game.ReplicatedStorage.MB_BaseState:SetAttribute("RadarOK", false)` → red ring and ✕; go to the antenna next to the entrance → "Repair radar".
- **Panels:** go to the field south-west of the base → dusty panels show "Clean" → hold E → the panel is clean, toast message.
- **Samples:** glowing rocks at (−70, −60) → "Collect sample" → the counter on the right goes 1/6 …
- **Victory:** Command Bar (server): `local b = game.ReplicatedStorage.MB_BaseState b:SetAttribute("Sol", 6) b:SetAttribute("SamplesCollected", 6)` → the console button turns green → "Launch" at the rocket.
- **Tutorial:** start the game → hint "1/5 Go outside…"; do each step.
- **Lamps:** DEBUG_FAST, wait for 18:30 → the posts around the base light up.
- **Base label:** go outside → "⌂ Base · N m"; turn away → it moves to the screen edge with an arrow.

## NASA data used (for "NASA Data")

- **NASA DONKI** (CCMC Space Weather Database of Notifications, Knowledge, Information), solar flares, API
  `https://ccmc.gsfc.nasa.gov/DONKI-API/get/FLR` (fetched 2026-11-15). 18 events in `MB_SolarEvents`,
  each with its own DONKI link, e.g. X9.0 2024-10-03 (https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/33693/-1),
  X8.7 2024-05-14 (…/30849/-1), X7.1 2024-10-01 (…/33656/-1), X5.8 2024-05-11 (…/30711/-1), M6.7 2026-10-08 (…/49015/-1).
  In the game they are always "Real event" (archived), never "live".
- **NASA Mars Fact Sheet** (https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html): sol = 24.6597 h;
  solar irradiance 0.431 of Earth's; surface gravity 3.73 m/s² = 0.380 of Earth's (→ Gravity 74.5).
- **NASA BVAD** (Life Support Baseline Values and Assumptions, NASA/TP-2015-218570/REV1, Table 3-33,
  https://ntrs.nasa.gov/citations/20180001338): per crew member per day 0.816 kg O₂, 2.5 kg water, 1.51 kg food.
- **Curiosity RAD** (NASA Science, "Radiation Measurements on Mars"): ~210 μGy/day on the surface. The team's
  radiation system uses RadLab/RAD data; the storm dose (+15 μGy/s) is a **game value**, not NASA data.
- The team's own systems also use DONKI live (`[donki] FLR … (live)`) and Curiosity REMS weather (ARCHIVED).
- [CHECK] 0.64 mSv/day (Hassler et al. 2014) has only been confirmed through news sources, so it is not used in the game.

## Use of AI (for "Use of AI")

Claude (Anthropic) via Claude Code, connected to Roblox Studio through the Studio MCP server:
wrote and installed the Luau scripts (HUD, resource simulation, storms, missions, tutorial, sound, sprint,
achievements), built the MB_ objects (panels, samples, antenna, console, lights, airlock porch), fetched and
filtered real NASA DONKI records, checked numbers against NASA pages (Mars Fact Sheet, BVAD), ran playtests through
the MCP and wrote this report. People on the team chose the design (mock-ups, sounds, music, what to build),
recorded and uploaded the audio, and tested the game.

## High-Level Summary (draft)

Junior Astronaut Mission Trainer is a cooperative Roblox survival game for kids 8–12: a small crew lives in a Mars
base, keeps the air, power, water and food going, cleans dusty solar panels, collects rock samples and hides from
radiation storms until the rocket can take them home. The storms come from real solar flares in NASA's DONKI
database, and the numbers for oxygen, water, food, a sol and Mars gravity come from NASA sources, so kids learn
real space science while they play.
