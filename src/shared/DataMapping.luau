-- How real data turns into what the player sees. Everything in this file is
-- game feel (visual strength, timings), NOT a real-world value; real values come
-- from the snapshots in src/server/data (see kb/data/nasa-sources.md).

export type Look = {
	atmosphereDensity: number, -- Lighting.Atmosphere.Density
	atmosphereHaze: number, -- Lighting.Atmosphere.Haze
	atmosphereColor: Color3,
	brightnessScale: number, -- multiplies Lighting.Brightness
	fadeSeconds: number,
	clockTime: number?, -- Lighting.ClockTime while the event is on (nil = keep)
}

local DataMapping = {}

-- Visual look per event id (client side). Events without a look only show the card.
DataMapping.looks = table.freeze({
	-- Dust storm: thick orange-brown haze, sunlight dimmed.
	dust = table.freeze({
		atmosphereDensity = 0.62,
		atmosphereHaze = 3,
		atmosphereColor = Color3.fromRGB(190, 120, 70),
		brightnessScale = 0.45,
		fadeSeconds = 4,
	}),
	-- Cold night: the sun sets and the sky goes dark blue.
	cold = table.freeze({
		atmosphereDensity = 0.3,
		atmosphereHaze = 1,
		atmosphereColor = Color3.fromRGB(70, 90, 130),
		brightnessScale = 0.6,
		fadeSeconds = 6,
		clockTime = 21.5,
	}),
	-- Radiation storm: radiation is invisible, so only a faint green tint marks it.
	radiation = table.freeze({
		atmosphereDensity = 0.4,
		atmosphereHaze = 1.5,
		atmosphereColor = Color3.fromRGB(150, 200, 120),
		brightnessScale = 0.85,
		fadeSeconds = 2,
	}),
	-- Solar flare: a quick, slightly brighter and whiter sky.
	flare = table.freeze({
		atmosphereDensity = 0.3,
		atmosphereHaze = 0.8,
		atmosphereColor = Color3.fromRGB(255, 240, 210),
		brightnessScale = 1.35,
		fadeSeconds = 1,
	}),
} :: { [string]: Look })

-- How long an event stays on in the demo loop, and the calm gap between events.
DataMapping.demoEventSeconds = 45
DataMapping.demoCalmSeconds = 30

return table.freeze(DataMapping)
