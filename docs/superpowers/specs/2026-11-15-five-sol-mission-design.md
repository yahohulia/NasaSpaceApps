# Design: a playable five-sol mission

Date: 2026-11-15. Author of the request: Yaroslav. Status: draft, waiting for approval.

## Intent (why)

The NASA Space Apps challenge "Build a Junior Astronaut Mission Trainer" asks for a game after which a
player aged 7–12 "walks away understanding a real constraint of deep space survival, not just having
played a fun game". Every choice must cost something, the mission must play out over time, and real
NASA data (DONKI first) should drive it. Judges reward: the link between a choice and real current
space weather, replayability without punishing failure, and a clear list of the datasets used.

Today the game has many working pieces (events by sol, solar panels, soldering, CO2 filter, greenhouse
crops and rack mini-games, samples and crafting, radar, ice map, Sparky's link to Earth with the real
signal delay), but nothing leads the player from sol to sol: after the 5-step tutorial on sol 1 the
player is on their own, and most breakdowns happen at random. A full run of 5 sols (~30 real minutes,
`Config.SolSeconds = 360`) has no shape and teaches no clear lesson.

Goal: tie the existing activities into one 5-sol mission where **each sol teaches one real constraint**
and ends with a short debrief, so a kid can play from landing to launch and Yaroslav also enjoys it.

## Lessons (approved by Yaroslav)

| Sol | Real constraint the player feels | Existing pieces used |
|---|---|---|
| 1 | Water doesn't come from nowhere: ice -> water -> food (planting costs water) | suit + airlock, drill / ice, water station, crops, tutorial |
| 2 | Power depends on the Sun and dust | dust storm, dirty panels + wipe mini-game, light panel (rooms on/off), water pump breakdown + soldering |
| 3 | Radiation: shelter or keep working; Earth is far away | solar storm (real DONKI flare), dose + medic, Sparky with real delay, conjunction (no signal) |
| 4 | Machines break and repairs cost time | marsquake -> radar repair, O2 failure -> CO2 filter swap |
| 5 | The launch window does not wait | all samples collected, launch before the window closes |

## Approach (picked: hybrid)

Considered:
1. **Fixed script** – fixed objectives and event times every run. Easiest to tune, boring the second time.
2. **Sandbox director** – events react to the base state, objectives appear from needs. Most replayable,
   too hard to balance in the time left.
3. **Hybrid (picked by Yaroslav)** – a fixed backbone "one sol = one lesson" with fixed objectives, while
   event times shift a little, the real DONKI record changes, and which machine breaks first varies.

## Goals

- A **mission board**: each sol starts with a short briefing from Mission Control (delivered through
  Sparky, so it arrives with the real Mars–Earth delay) and 2–3 objectives for the crew. Objectives
  are shared by the crew (co-op) and tick off from real game state.
- **Explicit trade-offs** at the key moments, each with a visible cost:
  - solar storm: go to the shelter (dose stays, but outside objectives wait) or keep working (dose grows);
  - low power after the dust storm: which rooms to switch off on the light panel (comfort / greenhouse
    vs. power for the oxygen generator). Needs a new link (decided by Yaroslav): every lit room adds a
    small load to base power in `MB_ResourceServer` (`-- game value, TODO balance`); `BaseLights`
    publishes how many rooms are lit;
  - water: drink it or spend it to plant a crop (food later).
- **End-of-sol debrief** card: what the crew did, what it cost (dose, water, power), and one real fact
  with its source (LIVE / ARCHIVED label as everywhere else).
- **Soft failure** (AGENTS.md rule 7, decided by Yaroslav): the mission stops only when base air is
  at zero, or when the *whole* crew has no water or no food (one player at zero is only slowed, as
  today). A calm "Mission stopped" screen says what went wrong and offers two buttons:
  - "Earth sends emergency supplies": the run goes on, air / water / food are topped up, but it costs
    game hours of the sol (the clock jumps forward) and the debrief shows it;
  - "Start over": the existing full reset (`ServerStorage.MB_ResetMission`).
  No state is saved or restored. No death, no scary words.
- **Missed objectives never block**: sols advance on the clock; the launch needs only what it needs
  today (all samples, sol-5 window). A missed objective shows in the debrief.
- **Victory** stays as in the game today: all samples collected and the rocket launched in the sol-5
  window -> "Mission complete" (MB_Missions / MB_MissionClient).
- **Replayability**: event hours jitter by up to ±1 game hour and the solar storm uses a real flare picked
  from DONKI (live, or the archived snapshot). Breakdowns stay on their sols so the lessons stay fixed
  (builder's call after the review).

## Non-goals

- No new mini-games, no new resource (still Water, Food, Oxygen; power and dose stay mechanics).
- No saving between sessions, no chapters beyond these 5 sols.
- No rewrite of teammates' Studio-only scripts.

## Anti-goals (would be a failure even if it works)

- Walls of text or a HUD so busy that a 7-year-old stops reading (max 3 objectives, short sentences).
- A "safe" choice with no cost.
- Punishing failure (losing the whole run for one mistake, scary wording).
- Any invented NASA number; every real value must trace to `kb/data/`.

## Constraints

- Deadline: platform deadline 2026-11-15 23:59 Kyiv (the AGENTS.md feature freeze is ignored by
  Yaroslav's decision).
- Ownership: `EventDirector` / `MB_Events` (Маша and Yaroslav), `Crops` / `Crafting` (Gods4y),
  `WaterPump` / `SolderStation` (upyrov), Studio-only `MB_Missions`, `MB_AirFilter`, `MB_PanelCleaning`,
  `FarmMinigameServer`, `MB_Tutorial`, HUD (teammates). New code goes into new modules; existing ones
  get only small additive hooks, announced in the team chat.
- Studio-only systems are steered through what they already expose: `ServerStorage.MB_EventCommand`,
  `ServerStorage.MB_FilterDebug`, `MB_BaseState` attributes, the `MB_Notify` keys.
- UI text only through `Strings` (en + uk), kid-copy rules.
- Prerequisite clean-up in the place: the Studio copy `ServerScriptService.MB_ResourceServer` runs next to
  the git one, and `Server.Crops` / `Shared.CropConfig` / `Shared.CropModels` / `Shared.Config` exist twice.
  Two copies make objectives tick twice or not at all. Ask the owners to remove the extra copies first.

## How objectives are detected (server)

A new server module `MissionDirector` (Yaroslav's) owns the sol plan and objective state; a new client
module `MissionBoardClient` draws the board and the debrief. Objectives are checked from state the game
already has, polled once per second, plus a BindableEvent `ServerStorage.MB_ObjectiveDone` that scripts
in git can fire for one-off actions:

| Objective | Signal |
|---|---|
| Go outside in the suit | Player@SuitOn and Player@IsInside == false |
| Get water from ice | Player@Ice rises (`ice_got`), or Player@Water rises at the water station |
| Plant a crop / harvest | `Crops` fires MB_ObjectiveDone("plant" / "harvest") (one added line each) |
| Clean the solar panels | MB_BaseState@PanelEfficiency >= 0.9 after the dust storm |
| Fix the water pump | WaterPump fires MB_ObjectiveDone("pump") when it runs again. The director breaks the pump on sol 2 through a small new `WaterPump.breakNow()` (ask upyrov); its own random breaks stay |
| Survive the solar storm under the limit | no player reaches the dose limit during the storm (Player@Dose) |
| Ask Earth a question before the conjunction | Sparky fires MB_ObjectiveDone("earth") on an answered question |
| Repair the radar | MB_BaseState@RadarOK back to true |
| Fix the oxygen | MB_BaseState@O2Broken back to false, whatever broke it (the O2Failure event's "Repair generator" prompt, or a clogged CO2 filter swapped in MB_AirFilter) |
| Collect all samples | MB_BaseState@SamplesCollected == total (MB_Missions) |
| Launch | MB_Mission "launch" (MB_Missions) |

## Sol plan (first draft, objectives are game design, not NASA data)

- **Sol 1 – Water from ice.** Briefing: the crew landed to look for ice. Objectives: go outside in the
  suit; get water from ice; plant a first crop (planting costs water, the crop gives food later). Debrief fact: ice under the ground in Arcadia Planitia
  (NASA ice map, kb/data/ice-map.md).
- **Sol 2 – Power from the Sun.** Dust storm in the morning, then the pump breaks. Objectives: clean the
  panels; keep power above zero (switch rooms off if needed); fix the water pump. Fact: Opportunity and
  the 2018 dust storm (already in MB_Events).
- **Sol 3 – Radiation and distance.** Warning, then the solar storm from a real DONKI flare; conjunction
  in the afternoon. Objectives: everyone ends the storm under the dose limit; ask Earth a question before
  the signal is lost; collect samples. Fact: the 20 May 2024 storm measured by Curiosity RAD.
- **Sol 4 – Things break.** Marsquake breaks the radar; the oxygen generator breaks (the existing
  O2Failure event) and base air starts to run out.
  Objectives: repair the radar; fix the oxygen; harvest a crop. Fact: MOXIE / InSight (already in MB_Events).
- **Sol 5 – The launch window.** Objectives: collect all samples; launch before 18:00. Fact: launch
  windows open about every 26 months (already in MB_Events).

Sol 1 keeps the existing 5-step tutorial; the board shows the sol objectives under it.

- **Dose limit (builder's call):** a player at the limit is kept inside (as today); this is not a
  failure. Other crew members can still collect the samples. In solo play the storm objective and the
  debrief warn early so the player shelters before reaching the limit.

## Left to the builder

- Exact objective wording (kid-copy, en + uk), board layout that does not overlap the HUD, debrief card
  look (reuse the EventUI card style), timing jitter values, light load per room and the time cost of
  emergency supplies (all `-- game value, TODO balance`).
- A missed objective only shows in the debrief (no carry-over cost) unless playtests say otherwise.
