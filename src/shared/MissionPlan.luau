--!strict
-- The five-sol mission: one real constraint per sol, 2-3 crew objectives, and the rule for when the
-- mission stops. Pure data and rules (no Instances), tested with lune (tests/mission-plan.luau).
-- Design: docs/superpowers/specs/2026-11-15-five-sol-mission-design.md.
-- Text fields are i18n keys (Shared.Strings). Objectives are game design, not NASA data.
-- kind "do": done when the crew does it. kind "keep": judged at the end of the sol (done unless broken).

export type Objective = { id: string, text: string, kind: "do" | "keep" }
export type Sol = {
	sol: number,
	title: string,
	brief: string,
	fact: string,
	factEvent: string?, -- an MB_Events id: its real fact is shown in the debrief instead of `fact`
	objectives: { Objective },
}

local function obj(id: string, kind: "do" | "keep"): Objective
	return { id = id, text = "mission.obj." .. id, kind = kind }
end

local function sol(n: number, factEvent: string?, objectives: { Objective }): Sol
	local key = "mission.sol" .. n
	return {
		sol = n,
		title = key .. ".title",
		brief = key .. ".brief",
		fact = key .. ".fact",
		factEvent = factEvent,
		objectives = objectives,
	}
end

local MissionPlan = {}

MissionPlan.JITTER_HOURS = 1 -- game value, TODO balance: scheduled events move by up to this many game hours
MissionPlan.EMERGENCY_HOURS = 4 -- game value, TODO balance: emergency supplies cost this many game hours
MissionPlan.EMERGENCY_REFILL = 50 -- game value, TODO balance: air / water / food are raised to at least this
MissionPlan.SOL1_SAMPLES = 5 -- game value, TODO balance: samples to collect on sol 1
MissionPlan.START_ICE = 3 -- game value, TODO balance: ice each crew member lands with (a drink = 1 ice = +35 water),
-- enough to last until the drill works on sol 3
MissionPlan.MISSION_SAMPLES = 10 -- game value, TODO balance: samples for the whole mission (sol 5); one full bag

MissionPlan.sols = {
	-- Sols 1-3 lead to the ice drill step by step (the board also shows the drill's recipe progress).
	sol(1, nil, { obj("outside", "do"), obj("samples", "do"), obj("sort", "do") }),
	sol(2, "DustStorm", { obj("panels", "do"), obj("pump", "do"), obj("plant", "do") }),
	sol(3, nil, { obj("drill", "do"), obj("ice", "do"), obj("storm", "keep") }),
	sol(4, "O2Failure", { obj("radar", "do"), obj("oxygen", "do"), obj("harvest", "do") }),
	sol(5, "LaunchWindow", { obj("earth", "do"), obj("allSamples", "do"), obj("launch", "do") }),
}

-- Why the mission stops, or nil. Base air at zero, or the whole crew with no water / no food.
-- One player at zero is only slowed (as before). No crew -> no failure.
function MissionPlan.failureReason(
	baseAir: number,
	crew: { { water: number, food: number } }
): ("air" | "water" | "food")?
	if baseAir <= 0 then
		return "air"
	end
	if #crew == 0 then
		return nil
	end
	local allDry, allHungry = true, true
	for _, member in crew do
		allDry = allDry and member.water <= 0
		allHungry = allHungry and member.food <= 0
	end
	if allDry then
		return "water"
	end
	if allHungry then
		return "food"
	end
	return nil
end

-- A scheduled hour moved by roll (0..1): roll 0.5 keeps it, 0 / 1 move it by -/+ JITTER_HOURS.
function MissionPlan.jitteredHour(hour: number, roll: number): number
	return math.clamp(hour + (roll * 2 - 1) * MissionPlan.JITTER_HOURS, 0.5, 23.5)
end

return MissionPlan
