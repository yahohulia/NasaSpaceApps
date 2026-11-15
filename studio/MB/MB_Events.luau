-- MB_Events (ModuleScript) -> ReplicatedStorage
-- Все данные событий: тексты, тайминг, расписание, настройки. Меняйте числа здесь, а не в коде.

local Events = {}

-- Цвет рамки по типу события
Events.Colors = {
	danger = Color3.fromRGB(226, 75, 74),
	good = Color3.fromRGB(99, 153, 34),
	info = Color3.fromRGB(55, 138, 221),
	finale = Color3.fromRGB(239, 159, 39),
	done = Color3.fromRGB(29, 158, 117),
}

-- warning  = секунды предупреждения до начала опасной фазы (0 = сразу)
-- duration = длительность активной фазы в секундах (nil = пока не починят / не улетят)
Events.Defs = {
	DustStorm = {
		debugKey = Enum.KeyCode.F1,
		type = "danger",
		icon = "🌪",
		title = "Dust storm!",
		short = "Clean the solar panels",
		sparky = "Dust storm coming! Clean the solar panels!",
		description = "Dust is covering the solar panels. Power is dropping.",
		todo = { "🧹 Go outside and clean every panel", "💡 Save power: stay inside when you can" },
		role = "Engineer cleans faster",
		warning = 0,
		duration = 120,
		achievement = "Storm Survivor",
		fact = "Real event, June 2018: a global dust storm covered Mars. Opportunity's solar panels were buried in dust. Its last signal came on June 10, 2018. (NASA/JPL)",
	},
	SolarStorm = {
		debugKey = Enum.KeyCode.F2,
		type = "danger",
		icon = "☢",
		title = "Solar storm!",
		short = "Get inside the base NOW",
		sparky = "Solar flare! Get inside the base now!",
		description = "Radiation from a solar flare is coming. Outside, your radiation dose will grow fast.",
		todo = { "🏠 Run inside before the timer ends", "🩺 Med bay is the safest place" },
		role = "Medic scans the crew after the storm",
		warning = 60,
		duration = 45,
		achievement = "Shelter in Time",
		fact = "Real event, May 20, 2024: a huge solar storm hit Mars. Curiosity's RAD measured a dose equal to 30 chest X-rays — the biggest since landing in 2012. (NASA)",
	},
	Marsquake = {
		debugKey = Enum.KeyCode.F3,
		type = "danger",
		icon = "🌋",
		title = "Marsquake!",
		short = "Find and fix the damage",
		sparky = "Marsquake! Check the base for damage!",
		description = "The ground shook and some equipment broke. Broken things glow red and show on the radar.",
		todo = { "🧰 Take a repair kit from storage", "🔧 Fix everything that glows red" },
		role = "Engineer repairs",
		silentStart = true, -- без баннера-предупреждения: сразу тряска
		warning = 0,
		duration = nil,
		achievement = "Quake Engineer",
		fact = "Real event, May 4, 2022: NASA's InSight lander recorded the biggest marsquake ever — magnitude 4.7. (NASA InSight team)",
	},
	DustDevil = {
		debugKey = Enum.KeyCode.F4,
		type = "good",
		icon = "🌀",
		title = "Dust devil!",
		short = "It cleans the panels — look outside",
		sparky = "Look outside! A dust devil!",
		description = "A spinning column of wind is crossing the plain. It blows the dust off the solar panels.",
		todo = { "😎 Nothing dangerous — enjoy the show", "👀 Go outside to see it up close" },
		role = "Anyone",
		warning = 0,
		duration = 20,
		achievement = "Storm Chaser",
		fact = "Real fact: Martian dust devils cleaned the solar panels of NASA's Spirit and Opportunity rovers. (NASA/JPL)",
	},
	Conjunction = {
		debugKey = Enum.KeyCode.F5,
		type = "info",
		icon = "📡",
		title = "No signal from Earth",
		short = "The Sun is between Earth and Mars",
		sparky = "No contact with Earth. We work on our own now!",
		description = "The Sun blocks the radio link. Radar and the mission board are offline.",
		todo = { "🚩 Use the flags to find your way", "💬 Talk to your crew" },
		role = "Everyone",
		warning = 0,
		duration = 150,
		achievement = "Independent Crew",
		fact = "Real fact: about every 2 years the Sun moves between Earth and Mars, and NASA pauses commands to Mars missions for about two weeks. (NASA)",
	},
	O2Failure = {
		debugKey = Enum.KeyCode.F6,
		type = "danger",
		icon = "💨",
		title = "Oxygen generator broken!",
		short = "Fix it before the base air runs out",
		sparky = "The oxygen generator is broken! Engineer, fix it!",
		description = "Base air is dropping. If it reaches zero, everyone breathes from their suits.",
		todo = { "🧰 Take a repair kit from storage", "🔧 Hold E on the generator" },
		role = "Engineer repairs",
		warning = 0,
		duration = nil,
		achievement = "Oxygen Hero",
		fact = "Real fact: MOXIE on NASA's Perseverance made oxygen from Mars air — 122 g in total, up to 12 g per hour. (NASA/JPL)",
	},
	LaunchWindow = {
		debugKey = Enum.KeyCode.F7,
		type = "finale",
		icon = "🚀",
		title = "Launch window open!",
		short = "Collect all samples and launch before 18:00",
		sparky = "Today we fly home! Bring all samples to the rocket!",
		description = "The rocket is ready. Launch with all 6 samples for 3 stars.",
		todo = { "🪨 Finish analyzing samples", "🚀 Press Launch at the rocket" },
		role = "Whole crew",
		warning = 0,
		duration = nil,
		achievement = "Mission Complete",
		fact = "Real fact: launch windows between Earth and Mars open only about every 26 months. (NASA)",
	},
}

-- Расписание: hour — игровое время (ClockTime). condition = "panelsDirty": только если панели грязные.
Events.Schedule = {
	{ sol = 1, hour = 15, id = "DustDevil" },
	{ sol = 2, hour = 9, id = "DustStorm" },
	{ sol = 2, hour = 16, id = "DustDevil", condition = "panelsDirty" },
	{ sol = 3, hour = 9, id = "SolarStorm" },
	{ sol = 3, hour = 14, id = "Conjunction" },
	{ sol = 4, hour = 8.5, id = "Marsquake" },
	{ sol = 4, hour = 16, id = "O2Failure" },
	{ sol = 5, hour = 6, id = "LaunchWindow" },
}

Events.Config = {
	-- интерфейс
	BANNER_TIME = 5,
	AUTO_COLLAPSE = 8,
	FACT_TIME = 5,
	DONE_FLASH = 2,
	TOGGLE_KEY = Enum.KeyCode.G,
	UI_TOP = 0.27, -- где по высоте экрана начинается блок событий (под баблом Sol и шкалой воздуха)
	UI_WIDTH = 0.36, -- ширина блока (доля экрана)
	UI_HEIGHT = 0.28, -- высота блока; UI_TOP + UI_HEIGHT должно быть <= 0.55 (низ экрана — для пальцев)

	-- механики
	PANEL_DUST_PER_SEC = 1 / 60, -- в бурю панель полностью пылится за 60 с
	POWER_DRAIN_STORM = 100 / 90, -- Power/с при полностью грязных панелях
	DUST_DEVIL_POWER_BONUS = 20,
	RADIATION_PER_SEC = 4, -- доза/с снаружи во время активной бури
	RADIATION_SLOW_AT = 30, -- выше этой дозы игрок замедлен до Scan в медотсеке
	SLOW_FACTOR = 0.7,
	BASEAIR_DRAIN = 100 / 90, -- BaseAir/с при сломанном генераторе
	QUAKE_BREAK_MIN = 2,
	QUAKE_BREAK_MAX = 3,
	CLEAN_HOLD = 2,
	REPAIR_HOLD = 4,
	RESTART_HOLD = 5,
	LAUNCH_COUNTDOWN = 10,
	LAUNCH_DEADLINE_HOUR = 18,
	SAMPLES_NEEDED = 6,

	-- звуки: rbxassetid (число). 0 = выключено
	SOUNDS = { alarm = 0, good = 0, info = 0, sparky = 0, quake = 0, done = 0, launch = 0 },
}

return Events
