--!strict
-- Mission events: what happens on which sol (all game values, TODO balance; no NASA numbers here).
-- EventDirector (server) reads Schedule and sends commands through ServerStorage.MB_EventCommand:
--   MB_Missions:        dustStorm (seconds), dustDevil (seconds), quake (panels), launchWindow (true)
--   MB_ResourceServer:  solarStorm (warning, seconds), o2Failure (true/false)
-- The MB scripts look for ReplicatedStorage.MB_Events, a one-line Studio module that returns this one.

export type Entry = {
	sol: number, -- mission sol (MB_Config.StartSol is the first)
	hour: number, -- hour of that sol, 0..24 (MB_BaseState.ClockTime)
	event: string, -- "DustStorm" | "DustDevil" | "Quake" | "SolarStorm" | "LaunchWindow"
	seconds: number?, -- how long it lasts (dust storm, dust devil, solar storm)
	panels: number?, -- Quake: how many solar panels break
}

local MB_Events = {}

MB_Events.Config = table.freeze({
	REPAIR_HOLD = 2, -- seconds to hold "Repair panel" after a marsquake
	PANEL_DUST_PER_SEC = 0.01, -- dust on each panel per second during a dust storm (clean -> full in 100 s)
	BASEAIR_DRAIN = 0.25, -- base air lost per second while the oxygen generator is broken
})

-- Sol 1 starts at 07:00 (MB_Config.StartClockTime). The first dust storm comes early so the
-- tutorial step "Clean a solar panel" has dust to clean. The launch window opens on sol 5
-- (MB_Config.Victory.SolsToSurvive), which makes the rocket ready.
-- O2Failure is not scheduled yet: nothing repairs the oxygen generator so far.
MB_Events.Schedule = table.freeze({
	{ sol = 1, hour = 7.3, event = "DustStorm", seconds = 90 },
	{ sol = 1, hour = 15, event = "SolarStorm" },
	{ sol = 2, hour = 9, event = "Quake", panels = 2 },
	{ sol = 2, hour = 14, event = "DustDevil", seconds = 20 },
	{ sol = 3, hour = 10, event = "DustStorm", seconds = 120 },
	{ sol = 3, hour = 16, event = "SolarStorm" },
	{ sol = 4, hour = 11, event = "Quake", panels = 3 },
	{ sol = 4, hour = 15, event = "DustStorm", seconds = 90 },
	{ sol = 5, hour = 8, event = "LaunchWindow" },
} :: { Entry })

-- Studio test keys (EventDirector accepts them only in Studio): F1..F6.
MB_Events.DebugKeys = table.freeze({
	F1 = "DustStorm",
	F2 = "SolarStorm",
	F3 = "Quake",
	F4 = "DustDevil",
	F5 = "O2Failure",
	F6 = "LaunchWindow",
})

return MB_Events
