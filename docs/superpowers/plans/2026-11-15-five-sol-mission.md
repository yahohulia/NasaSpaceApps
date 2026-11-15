# Five-Sol Mission Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing activities into one 5-sol mission: a briefing and 2–3 crew objectives per sol, real trade-offs, an end-of-sol debrief, and a soft "mission stopped" screen.

**Architecture:** A pure module `MissionPlan` (data + rules, tested with lune) describes the sols, objectives and failure rule. A server module `MissionDirector` watches game state (attributes, one new BindableEvent `ServerStorage.MB_ObjectiveDone`), publishes mission state to clients as JSON in `ReplicatedStorage.MissionState@Payload`, and handles the failure choice. A client module `MissionBoardClient` draws the board, the debrief and the failure screen. Existing scripts in git get small additive hooks only.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, lune for headless tests, selene, stylua.

**Spec:** `docs/superpowers/specs/2026-11-15-five-sol-mission-design.md`

## Global Constraints

- Exactly three resources: Water, Food, Oxygen. Power and dose stay mechanics (AGENTS.md rule 1).
- Every balance number lives in a config / module constant marked `-- game value, TODO balance`.
- Never invent NASA facts or numbers; debrief facts reuse `MB_Events` facts or kb-sourced lines (sol 1: `kb/data/ice-map.md`).
- All player-facing text through `Strings` with keys in both `src/shared/i18n/en.luau` and `uk.luau` (kid-copy: ≤ 12 words a sentence, no "death", "lethal", "HP").
- At most 3 objectives on the board; failure screen is calm ("Mission stopped"), never "game over".
- One file = one owner: new files are Yaroslav's; edits in `Crops` (Gods4y), `WaterPump` (upyrov), `MB_ResourceServer` (Systems), `EventDirector` (Маша/Yaroslav) are additive hooks only and are announced in the team chat.
- `selene src`, `stylua --check src`, `rojo build -o build.rbxl` pass after every task; `git pull` before `rojo serve`.

## Review Focus

1. Two players, one at zero water, the other not → no failure (only the whole crew counts).
2. Mission reset ("Start over" / Play again) mid-sol → objectives, debrief and failure state clear; sol 1 board shows again.
3. A player joins mid-mission → gets the current board and objective ticks at once (Payload is state, not a stream of events).
4. Clock jumps forward (emergency supplies) across a sol boundary → the skipped sol still gets a debrief and the next sol's board appears once.
5. An objective's signal fires twice (e.g. two `MB_ResourceServer` copies, or plant twice) → objective counted once, no double debrief lines.

---

### Task 0: Remove duplicate scripts in the place (manual, with owners' OK)

**Files:** none (Studio place).

- [ ] **Step 1:** Ask in the team chat; after OK, delete `ServerScriptService.MB_ResourceServer` (Studio copy), the extra `Server.Crops`, `Shared.CropConfig`, `Shared.CropModels` and the extra `Shared.Config` that are not from Rojo (Rojo-managed ones have a `RojoId`/are recreated on sync).
- [ ] **Step 2:** Play Solo; console shows `[MB_ResourceServer] started` and `[crops] … racks` exactly once.

### Task 1: `MissionPlan` – sols, objectives, failure rule (pure)

**Files:**
- Create: `src/shared/MissionPlan.luau`
- Test: `tests/mission-plan.luau`

**Interfaces:**
- Produces:
  - `export type Objective = { id: string, text: string, kind: "do" | "keep" }` — `text` is an i18n key `mission.obj.<id>`; "keep" objectives are judged at the end of the sol (done unless broken).
  - `export type Sol = { sol: number, title: string, brief: string, fact: string, factEvent: string?, objectives: { Objective } }` — `title`/`brief`/`fact` are i18n keys `mission.solN.title|brief|fact`; `factEvent` = an `MB_Events` id whose `fact` text is shown instead of `fact` when set.
  - `MissionPlan.sols: { Sol }` (5 entries, in order).
  - `MissionPlan.failureReason(baseAir: number, crew: { { water: number, food: number } }): ("air" | "water" | "food")?`
  - `MissionPlan.jitteredHour(hour: number, roll: number): number` — `roll` in [0, 1); result = `hour + (roll * 2 - 1) * JITTER_HOURS`, clamped to [0.5, 23.5].
  - Constants: `JITTER_HOURS = 1`, `EMERGENCY_HOURS = 4`, `EMERGENCY_REFILL = 50`, `SOL3_SAMPLES = 3` (all `-- game value, TODO balance`).

Objective ids by sol (copy exactly):
1. `outside` (do), `ice` (do), `plant` (do)
2. `panels` (do), `power` (keep), `pump` (do)
3. `storm` (keep), `earth` (do), `samples` (do)
4. `radar` (do), `oxygen` (do), `harvest` (do)
5. `allSamples` (do), `launch` (do)

`factEvent`: sol 2 `DustStorm`, sol 3 `SolarStorm`, sol 4 `O2Failure`, sol 5 `LaunchWindow`; sol 1 uses `mission.sol1.fact`.

- [ ] **Step 1: Write the failing test** `tests/mission-plan.luau` (load the module with `@lune/luau` like `tests/solder-joint.luau`):

```lua
assert(#plan.sols == 5)
for i, s in plan.sols do
	assert(s.sol == i and #s.objectives >= 2 and #s.objectives <= 3)
end
assert(plan.sols[2].objectives[2].id == "power" and plan.sols[2].objectives[2].kind == "keep")
assert(plan.failureReason(10, { { water = 0, food = 5 }, { water = 3, food = 5 } }) == nil)
assert(plan.failureReason(10, { { water = 0, food = 5 }, { water = 0, food = 5 } }) == "water")
assert(plan.failureReason(0, { { water = 5, food = 5 } }) == "air")
assert(plan.failureReason(10, { { water = 5, food = 0 } }) == "food")
assert(plan.failureReason(10, {}) == nil) -- no crew, no failure
assert(plan.jitteredHour(9, 0.5) == 9)
assert(plan.jitteredHour(9, 0) == 8 and plan.jitteredHour(23.4, 0.99) <= 23.5)
assert(plan.jitteredHour(0.2, 0) == 0.5)
print("mission-plan ok")
```

- [ ] **Step 2:** `lune run tests/mission-plan.luau` → FAIL (file missing).
- [ ] **Step 3:** Implement `src/shared/MissionPlan.luau` (`--!strict`, no Instances). Air is checked first, then water, then food.
- [ ] **Step 4:** `lune run tests/mission-plan.luau` → `mission-plan ok`; `selene src`, `stylua --check src` clean.
- [ ] **Step 5:** Commit `Add MissionPlan: sols, objectives and the failure rule`.

### Task 2: Lights cost power

**Files:**
- Modify: `src/shared/LightsConfig.luau` (add `PowerPerLitRoom = 0.05 -- game value, TODO balance`, power units per real second per lit room)
- Modify: `src/server/BaseLights.luau` (`setRoom` and start: set `MB_BaseState@LitRooms: number`)
- Modify: `src/server/MB_ResourceServer.server.luau:290-291` (subtract `LightsConfig.PowerPerLitRoom * (baseState:GetAttribute("LitRooms") or 0) * dt` from power)

**Interfaces:**
- Produces: `MB_BaseState@LitRooms` (integer ≥ 0), kept current by BaseLights.

- [ ] **Step 1:** Implement; BaseLights counts rooms with `LightsOn == true` after every change.
- [ ] **Step 2:** Play Solo: switch all rooms off on the light panel → `LitRooms` = 0 and power drains slower than with all on (watch `MB_BaseState@Power` over 30 s each).
- [ ] **Step 3:** Commit `Lit rooms cost base power`.

### Task 3: Objective hooks in existing scripts

**Files:**
- Modify: `src/server/Crops.luau` (after `crop.toast.planted` → `fire(player, "plant")`; after `crop.toast.harvested` → `fire(player, "harvest")`)
- Modify: `src/server/WaterPump.luau` (add `WaterPump.breakNow()`: sets `PumpBroken = true` on every station; when `PumpWorking` turns true after being broken → `fire(nil, "pump")`)
- Modify: `src/server/Sparky.luau` (in `deliver` when an answer reaches the player → `fire(player, "earth")`)

**Interfaces:**
- Produces: `ServerStorage.MB_ObjectiveDone: BindableEvent`, fired as `:Fire(player: Player?, id: string)`. Each script gets it with `ServerStorage:FindFirstChild("MB_ObjectiveDone")` and fires only if it exists (the director creates it).
- Produces: `WaterPump.breakNow(): ()`.

- [ ] **Step 1:** Add a local `fire(player, id)` helper in each file; no other behaviour change.
- [ ] **Step 2:** Play Solo with a temporary `BindableEvent` listener in the command bar printing `(player, id)`: plant → `plant`, harvest → `harvest`, `WaterPump.breakNow()` then repair → `pump`, Sparky answer → `earth`.
- [ ] **Step 3:** Commit `Fire MB_ObjectiveDone from crops, pump and Sparky`.

### Task 4: Emergency supplies command

**Files:**
- Modify: `src/server/MB_ResourceServer.server.luau:107-` (new command `"emergencySupplies"`)

**Interfaces:**
- Consumes: `MissionPlan.EMERGENCY_HOURS`, `MissionPlan.EMERGENCY_REFILL`.
- Produces: `ServerStorage.MB_EventCommand:Fire("emergencySupplies")` → base air and every player's `Water`/`Food` raised to at least `EMERGENCY_REFILL`, and `startedAt -= EMERGENCY_HOURS * SOL / 24` (the clock jumps forward; `MissionStartedAt` attribute updated).

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Play Solo: command bar `game.ServerStorage.MB_EventCommand:Fire("emergencySupplies")` → `ClockTime` jumps ~4 h, BaseAir/Water/Food ≥ 50.
- [ ] **Step 3:** Commit `Add the emergency supplies command`.

### Task 5: `MissionDirector` (server)

**Files:**
- Create: `src/server/MissionDirector.luau`
- Modify: `src/server/init.server.luau` (require and `task.spawn(MissionDirector.start)`)
- Modify: `src/server/EventDirector.luau:305` (use `MissionPlan.jitteredHour(entry.hour, roll[i])`, `roll` filled once per mission and refilled on reset)

**Interfaces:**
- Consumes: `MissionPlan` (Task 1), `MB_ObjectiveDone` (Task 3), `WaterPump.breakNow` (Task 3), `"emergencySupplies"` (Task 4), `Horizons.get()` (one-way delay, for the briefing delay), attributes `MB_BaseState@Sol, ClockTime, BaseAir, Power, PanelEfficiency, RadarOK, O2Broken, StormActive, SamplesCollected`, `Player@SuitOn, IsInside, Ice, Water, Food, OutsideBlocked`, remote `ReplicatedStorage.MB_Mission` ("launch").
- Produces:
  - `ReplicatedStorage.MissionState` (Folder) `@Payload: string` JSON:
    `{ sol, briefAt, done = { [objectiveId] = true }, debrief = { sol, done, missed, fact, factSource, emergencies, doseMax }?, failed = "air"|"water"|"food"|nil }`
  - `ReplicatedStorage.MissionChoice: RemoteEvent` — client fires `"supplies"` or `"restart"` while `failed` is set.
  - Pump breaks once on sol 2 at `13:00` game time via `WaterPump.breakNow()`.

Rules (from the spec):
- `outside`: any player `SuitOn and not IsInside`. `ice`: any player's `Ice` rises. `plant`/`harvest`/`pump`/`earth`: `MB_ObjectiveDone`. `panels`: `PanelEfficiency >= 0.9` after the sol-2 dust storm ended. `power` (keep): `Power` never 0 during sol 2. `storm` (keep): no player turns `OutsideBlocked` while `StormActive` on sol 3. `samples`: `SamplesCollected` grew by `SOL3_SAMPLES` on sol 3. `radar`: `RadarOK` true after it was false. `oxygen`: `O2Broken` false after it was true. `allSamples`: `RocketReady` / all samples (MB_Missions attribute). `launch`: `MB_Mission` "launch".
- On sol change: build the debrief of the finished sol (keep-objectives judged now), then show the new board. A jump over a whole sol still produces its debrief.
- Briefing is shown `2 * Horizons.get().minutes` game minutes after the sol starts (`briefAt` in server time), objectives tick from the sol's start anyway.
- Failure: `MissionPlan.failureReason` each second; once set, keep it until a choice arrives. `"supplies"` → `MB_EventCommand:Fire("emergencySupplies")`, count it for the debrief; `"restart"` → `ServerStorage.MB_ResetMission:Fire()`. On `MB_ResetMission` clear everything.
- Idempotent: an objective already done ignores repeated signals.

- [ ] **Step 1:** Implement; print `[mission] sol N board`, `[mission] done <id>`, `[mission] failed <reason>`.
- [ ] **Step 2:** Play Solo, set `MB_BaseState@ClockTime`/`Sol` via `Lighting@DebugClockTime` or fast-forward (temporarily `Config.SolSeconds = 60`, not committed): console shows the boards of sols 1–5 in order, objectives tick when doing them, a debrief at each rollover.
- [ ] **Step 3:** Review Focus 1, 2, 4, 5 by hand: two-player Team Test with one player at 0 water (no failure); Play again mid-sol (state clears); emergency supplies at 22:00 (debrief of the skipped sol appears once); fire `MB_ObjectiveDone(nil,"plant")` twice (counted once).
- [ ] **Step 4:** Commit `Add MissionDirector: sol boards, objectives, debrief, failure`.

### Task 6: `MissionBoardClient` + strings

**Files:**
- Create: `src/client/MissionBoardClient.luau`
- Modify: `src/client/init.client.luau` (require + `task.spawn(MissionBoardClient.start)`)
- Modify: `src/shared/i18n/en.luau`, `src/shared/i18n/uk.luau` (keys `mission.solN.title|brief`, `mission.sol1.fact`, `mission.obj.<id>` for all 14 ids, `mission.board.incoming` "📡 Message from Earth in {min} min", `mission.debrief.title|done|missed|emergency`, `mission.failed.title`, `mission.failed.air|water|food`, `mission.failed.supplies`, `mission.failed.restart`)

**Interfaces:**
- Consumes: `MissionState@Payload`, `MissionChoice` (Task 5), `MB_Events` (fact text by `factEvent`), `Strings`.
- Produces: none.

UI (builder decides look; reuse the EventUI card style):
- Board: small panel on the left, under the HUD's left column, not overlapping it; sol title + up to 3 lines with ☐/☑; before `briefAt` shows `mission.board.incoming`.
- Debrief: centred card for 12 s or until closed: done / missed objectives, emergencies, fact + source label.
- Failure: full-screen dim card, reason text, two buttons; buttons fire `MissionChoice`.

- [ ] **Step 1:** Implement; mouse cursor free while the debrief or failure card is open (like SparkyClient).
- [ ] **Step 2:** Play Solo: board visible on sol 1 under the tutorial hint, ticks update; force failure (`MB_BaseState` BaseAir → 0 via command bar) → card; "Earth sends supplies" continues; "Start over" resets to sol 1.
- [ ] **Step 3:** Check the Ukrainian locale (Studio: Player → `LocaleId`) fits the board.
- [ ] **Step 4:** `selene`, `stylua --check`, `rojo build`; commit `Add the mission board, debrief and failure screen`.

### Task 7: Playtest the whole 5 sols + handoff

- [ ] **Step 1:** Team Test with 2 players, full 30 minutes: every sol shows its board, the trade-offs cost something, the launch works on sol 5.
- [ ] **Step 2:** Write `kb/handoffs/` note (handoff skill) with what was tuned and what is left.
- [ ] **Step 3:** Commit and, on Yaroslav's yes, push and open the PR to `main`.
