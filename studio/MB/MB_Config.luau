-- MB_Config (ReplicatedStorage): every number of the Mars base survival loop lives here.
-- These are GAME VALUES (balance), not NASA data. Tune freely; the server and HUD read only this.
-- Copy of the script that lives in the team place (studio/MB in the repo).
local Config = {}

Config.TickSeconds = 0.5 -- server simulation step

-- Time ------------------------------------------------------------------------------------------
Config.SolSeconds = 480 -- real seconds for one sol (a Mars day) in the game
Config.StartSol = 1
Config.StartClockTime = 7 -- 07:00
Config.DayStartHour = 6 -- solar panels work between these hours
Config.DayEndHour = 18
Config.SyncLighting = false -- true: Lighting.ClockTime follows the game clock

-- Personal resources (Player attributes, 0..100) -----------------------------------------------------
Config.Player = {
	StartFood = 80,
	StartWater = 80,
	StartFatigue = 0,
	StartSuitO2 = 100,
	MaxIce = 5,

	FoodDrain = 0.12, -- per second
	WaterDrain = 0.18,
	FatigueGainInside = 0.05,
	FatigueGainOutside = 0.15,

	SuitO2DrainOutside = 0.8, -- full suit lasts ~2 minutes outside
	SuitO2DrainNoBaseAir = 0.4, -- inside, when the base has no air left
	SuitO2Refill = 10, -- inside with base air

	NormalWalkSpeed = 10, -- slower, heavier steps (was 16)
	SlowWalkSpeed = 6, -- when hungry, thirsty or too tired (was 9)
	TiredAt = 90, -- fatigue at which the player slows down

	-- Suit empty: the crew helps the player back inside (no death).
	RescueSuitO2 = 30,
	RescueFatigue = 20,
}

-- Shared base resources (attributes on ReplicatedStorage.MB_BaseState, 0..100) ---------------------
Config.Base = {
	StartPower = 80,
	StartBaseAir = 100,

	AirPerPersonInside = 0.3, -- per second for each player inside
	AirGenerator = 0.5, -- per second while Power > 0 and air < 100
	GeneratorPower = 0.12, -- power per second the oxygen generator uses while running
	BaseLoadPower = 0.04, -- lights, heaters
	SolarPower = 0.35, -- per second in daytime, no storm
}

-- Solar flare (storm) ------------------------------------------------------------------------------
Config.Storm = {
	-- A radiation storm based on a real NASA DONKI flare (MB_SolarEvents) every 1-2 sols.
	FirstAfterSeconds = 90, -- the first storm comes early so new players meet it
	MinSols = 1,
	MaxSols = 2,
	WarningSeconds = 30, -- red bubble counts down to the storm
	DurationSeconds = 60, -- red bubble counts down the storm itself
	SolarFactor = 0, -- panels give this share of power during a flare
	OutsideSuitDrainMultiplier = 2, -- go inside!
	DoseOutsidePerSecond = 15, -- game value: μGy added to Player.Dose per second outside (inside = safe)
}

-- Interactions (ProximityPrompt on parts with these tags) ------------------------------------------
Config.Actions = {
	DigIce = { Tag = "MB_Drill", Text = "Dig ice", Object = "Drill", Hold = 2, Ice = 1, Fatigue = 4 },
	Drink = { Tag = "MB_WaterStation", Text = "Melt ice and drink", Object = "Water", Hold = 1, Water = 35 },
	Harvest = {
		Tag = "MB_Greenhouse",
		Text = "Pick vegetables",
		Object = "Greenhouse",
		Hold = 1.5,
		Food = 35,
		Cooldown = 45, -- plants need time to grow back (shared by the crew)
	},
	-- Sleep in a bed: the player lies down for SleepSeconds and wakes up fully rested (MB_ResourceServer).
	Rest = { Tag = "MB_Bed", Text = "Sleep", Object = "Bed", Hold = 1, SleepSeconds = 10 }, -- game values
}
Config.PromptDistance = 10

Config.InsideZoneTag = "MB_InsideZone" -- invisible parts that mark "inside the base"

-- Footsteps (MB_Footsteps): inside the base a random sample per step; outside the normal Roblox steps.
-- Sounds uploaded by the game owner (Maria_Strawberi) as "untitled - Track N" (copies: assets/audio/footsteps).
Config.Footsteps = {
	SoundIds = {
		"rbxassetid://102066529165665", -- Track 1
		"rbxassetid://117089051905862", -- Track 2
		"rbxassetid://73300293134096", -- Track 3
		"rbxassetid://120720473758534", -- Track 6
		"rbxassetid://119999972186908", -- Track 7
		"rbxassetid://106395123873283", -- Track 8
	},
	StrideStuds = 5, -- one step every 5 studs walked (~3 steps per second at normal speed)
	PitchMin = 0.9,
	PitchMax = 1.1,
	VolumeMin = 1.6, -- the source files are quiet
	VolumeMax = 2.2,
	LoudWithin = 12, -- studs; full volume this close
	HearDistance = 70, -- studs; other players hear your steps up to this far
	-- Outside on sand: a looping walk recording ("mars_walk_soft_x1.7", uploaded by Maria) replaces
	-- the Roblox steps while walking. Other outdoor surfaces keep the normal Roblox steps.
	SandId = "rbxassetid://130948620356531", -- asset "7" = mars_walk_soft_x1.7.ogg = "ходьба по песку.ogg" (3.49 s)
	SandMaterials = { "Sand" }, -- Enum.Material names that count as sand
	SandVolume = 0.9,
	SandSpeedMin = 0.8, -- PlaybackSpeed follows walking speed (16 studs/s = 1.0)
	SandSpeedMax = 1.25,
	-- Inside the base: a looping walk-on-metal recording ("звук по железу", uploaded by Maria) replaces
	-- the single-step samples above. Empty = use SoundIds steps instead.
	MetalId = "rbxassetid://101444322623946", -- "звук по железу" (5.32 s)
	MetalVolume = 1.2,
	MetalSpeedMin = 0.8,
	MetalSpeedMax = 1.25,
}

-- Background music (MB_Music): one track by day, another by night (DayStartHour..DayEndHour).
-- Uploaded by Maria_Strawberi. Day: "monume - retro arcade game music 2" (Pixabay).
-- Night: "Night Sky Travel" by Static Glow Sounds (Epidemic Sound; needs Maria's Epidemic licence).
Config.Music = {
	DayId = "rbxassetid://130094065357950",
	NightId = "rbxassetid://129043173046268",
	Volume = 0.35,
	FadeSeconds = 3,
}

-- Night build (2026-11-15) ---------------------------------------------------------------------------
Config.DEBUG_FAST = false -- true: 1 sol = 60 s and quick storms, for testing only. Keep false for players.

Config.Radar = {
	BreakAfterSolsMin = 0.6, -- the radar breaks again after this many sols ...
	BreakAfterSolsMax = 1.5, -- ... at most this many
	RepairHold = 3, -- seconds to hold "Repair radar" at the antenna outside
}

Config.Panels = {
	DustPerSecond = 0.0015, -- a clean panel is fully dusty after ~11 minutes
	StormDustMultiplier = 3, -- dust settles faster during a storm
	MinEfficiency = 0.25, -- fully dusty panels still give a quarter of the power
	CleanHold = 2,
}

Config.Samples = {
	CollectHold = 1.5,
}

Config.Victory = {
	SolsToSurvive = 5, -- plus all science samples -> the rocket can launch
}

-- Training steps (MB_Tutorial). Facts are checked: NASA Mars Fact Sheet (nssdc.gsfc.nasa.gov) and
-- NASA Life Support Baseline Values (BVAD, NASA/TP-2015-218570/REV1, Table 3-33).
Config.Tutorial = {
	{
		Id = "outside",
		Text = "Go outside through the airlock.",
		Fact = "A day on Mars is called a sol. It lasts 24 h 39 min.",
	},
	{ Id = "clean", Text = "Clean a solar panel.", Fact = "Mars gets only about 43% of the sunlight Earth gets." },
	{
		Id = "sample",
		Text = "Collect a rock sample.",
		Fact = "Gravity on Mars is about 38% of Earth's. You can jump higher!",
	},
	{
		Id = "eat",
		Text = "Eat or drink inside the base.",
		Fact = "An astronaut drinks about 2.5 kg of water every day.",
	},
	{ Id = "rest", Text = "Rest on the bunk.", Fact = "An astronaut breathes about 0.8 kg of oxygen every day." },
}

Config.Atmosphere = {
	Gravity = 74.5, -- Mars: 0.380 of Earth's (NASA Mars Fact Sheet); Roblox Earth default is 196.2
	LightsOnHour = 18.5,
	LightsOffHour = 5.5,
}

-- Sparky typing sound (MB_SparkyTyping): plays only while Sparky's dialog text is being typed.
-- "ninari - escribir a maquina" (Pixabay), uploaded by Maria_Strawberi.
Config.SparkyTyping = {
	SoundId = "rbxassetid://76146668549542",
	Volume = 0.5,
}

-- Achievements (MB_Achievements + MB_AchievementToast). Given once per player.
-- BadgeId: optional real Roblox badge id (create the badge on the Creator Dashboard); 0 = popup only.
Config.Achievements = {
	WelcomeDelay = 4, -- seconds after joining before the welcome popup
	Welcome = { Title = "Welcome to Mars!", Text = "You joined the Mars base crew.", BadgeId = 0 },
	FirstSample = { Title = "Rock collector", Text = "You picked up your first rock sample.", BadgeId = 0 },
	MissionComplete = { Title = "Mission complete!", Text = "You survived on Mars and flew home.", BadgeId = 0 },
}

-- Sprint (MB_Sprint): hold Shift on PC, tap the Run button on phones.
Config.Sprint = {
	Multiplier = 1.7, -- run speed = walk speed x this (10 -> 17)
	MaxSeconds = 10, -- a full bar lasts 10 s of running
	RefillSeconds = 5, -- an empty bar fills up again in 5 s
	RefillDelay = 0.5, -- seconds after running stops before the bar starts to refill
	MinToStart = 1, -- seconds of bar needed to start running again after it ran out
}

return Config
