---
title: 'Handoff: Space suit and visor 2026-11-15 10:53'
type: handoff
status: in-progress
branch: chore/roblox-env
date: 2026-11-15
permalink: sol-sandbox/handoffs/2026-11-15-1053-space-suit-visor
---

# Handoff: Space suit and visor 2026-11-15 10:53

Скафандр (шафка `SuitLocker`, шолом + рюкзак) і візор шолома (пил, запотівання, рамка). Код написаний і перевірений у Play Solo, але **ще не закомічений**.
Space suit (locker, helmet, backpack) and helmet visor (dust, fog, frame). Code works in Play Solo; **not committed yet**.

## Done
- `selene src`: 0 errors (2 warnings in `IceMapClient`). `rojo build`: OK.
- Play Solo (2026-11-15): server and client start with no errors from our scripts; `Suit.set(player, true/false)` dresses and undresses the player (`SpaceSuit` + `SuitStash`, attribute `SuitOn`); the visor frame shows and the HUD stays on top.

## Next
1. Commit the suit/visor work (only when the human asks). Decide what to do with `image.png` (modified), `542.png` and `NASA_Space_Apps_Kyiv_2026_Mentor_Slots.xlsx`; they probably should not be committed.
2. `stylua --check src` fails on `src/client/IceMapClient.luau` and `src/server/Crafting.luau` (from PR #3, owner Mechanics). Run `stylua` on them after agreeing with the owner, otherwise `main` stays red.
3. Not tested yet: the real locker prompt, the airlock refusing a player without the suit (`suit.need`), the rescue after `RESCUE_SECONDS` outside, the R key that wipes dust, fog when `SuitO2` is low.
4. Strings are in `src/shared/i18n/en.luau` / `uk.luau` (keys `suit.*`, visor). Check them with `kid-copy`.

## Files touched
- `src/server/Suit.luau` (new): locker prompt, dress/undress, rescue back to the airlock.
- `src/client/SuitClient.luau`, `src/client/VisorClient.luau` (new): client side, visor layers.
- `scripts/visor-texture.mjs` (new): generates the visor textures.
- `src/server/Airlock.luau`: `LeadsOutside` pads need `SuitOn`.
- `src/server/Radiation.luau`: uses MB `IsInside` when present; sets `Indoors`.
- `src/client/FirstPersonClient.luau`: hides parts with `HideInFirstPerson` (helmet).
- `src/client/SparkyClient.luau`, `src/shared/Assets.luau`, `src/server/init.server.luau`, `src/client/init.client.luau`, i18n.

## Observations
- [risk] `SparkyClient` comes from the superseded [[Game concept]]; AGENTS.md says not to build Sparky. Ask the team whether it stays.
- [risk] Helmet/backpack models live in `ServerStorage.SuitParts` (Studio only, not in git).
- [question] Console noise from Studio-only scripts (not ours): `MarsBaseMeshFixClient` (no permission for mesh assets), `ServerScriptService.ьфтфпук` waits for `Workspace.Spawns`, `Сheckpoint Script` (Cyrillic С) waits for `Workspace.Checkpoints`, `rbxassetid://203785492` wrong type. The World owner should check.
- [question] Suit oxygen is MB_ResourceServer's `SuitO2`; that is a fourth "oxygen-like" value next to Oxygen. Check it against the fixed rule of 3 resources.

- [decision] 2026-11-15: no running on Mars missions. In Studio (not in git): `StarterPlayerScripts.MB_Sprint` set to `Enabled = false` (Shift, stamina bar and Run button are gone); `ReplicatedStorage.MB_Config` `NormalWalkSpeed` 10→6, `SlowWalkSpeed` 6→4 (game values). To bring running back, enable `MB_Sprint` again. Tell the MB owner.
- [decision] 2026-11-15: base air only inside the base, not on its roof. `MB_InsideZone` boxes reach above the roof (zone tops 16–25, roof 10.5–15.6). In Studio (not in git) `ServerScriptService.MB_ResourceServer` `playersInside()` now also needs `isUnderRoof`: not inside when the player stands on `MB_RoofColliders`; when nothing is above the head, inside only within `MAX_UNCOVERED_HEIGHT` = 7 (game value) of the zone floor. Tested: roof → `IsInside=false`, SuitO2 drops; floor and roof gaps → inside.
- [question] `Zone22` and `Zone43` sit on terrain with no roof above; they may be outdoor areas counted as base by mistake. `MB_Footsteps` has its own `isInside` (sound only).
- [decision] 2026-11-15 (team): running is allowed inside the base only, through `StarterPlayerScripts.MB_BaseSprint` (Shift, stamina, RUN_SPEED 14). Outside there is no running. Do not touch `MB_BaseSprint`; the old `MB_Sprint` stays disabled.
- [decision] 2026-11-15: cinematic base lights + light panel. Code in git: `src/shared/LightsConfig.luau` (all look values, game values), `src/server/BaseLights.luau` (71 lamps from `MarsBaseFixes` + `MB_CorridorRebuild` get a downward `CineSpot` SpotLight with shadows; room state = zone attribute `LightsOn` on `Workspace.Base.Zones.*Zone`; RemoteEvent `BaseLightsToggle(roomId|"all", on)`, server checks distance to the panel), `src/client/BaseLightsClient.luau` (prompt → window with On/Off per room, the panel's own screen, interior colour grade, and inside the base it turns down Ambient, OutdoorAmbient and environment light), `SkyClient` reads Lighting attributes `AmbientScale` / `OutdoorAmbientScale`. Studio only: `Workspace.MB_LightPanel` (Screen part tagged `LightPanel`) on the south wall of the power room. Lights off = faint blue night glow, never pitch black.
- [risk] Roblox lets OutdoorAmbient leak under the thin base roof; that is why the interior look turns it down on the client while the player is inside. Windows look darker from inside as a result.
- [question] `IceMapClient` close button uses "✕", which renders as a box in GothamBold (same bug fixed in BaseLightsClient by using "X").

## Relations
- part_of [[Co-op campaign concept]]
- follows [[Handoff: Roblox environment 2026-11-14 12:00]]
- see_also [[Decision: Roblox asset conventions]]