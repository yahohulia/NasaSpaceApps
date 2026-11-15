-- How real data turns into what the player sees. Everything in this file is
-- game feel (visual strength, timings), NOT a real-world value; real values come
-- from the snapshots in src/server/data (see kb/data/nasa-sources.md).

-- One sky state for SkyClient. Colours are picked by eye to match photos from
-- Mars rovers (butterscotch day sky, blue sunset glow, dark starry night).
export type SkyPreset = {
	density: number, -- Atmosphere.Density
	offset: number, -- Atmosphere.Offset
	color: Color3, -- Atmosphere.Color (sky near the sun)
	decay: Color3, -- Atmosphere.Decay (sky away from the sun)
	glare: number, -- Atmosphere.Glare
	haze: number, -- Atmosphere.Haze
	brightness: number, -- Lighting.Brightness
	ambient: Color3, -- Lighting.Ambient (indoors / shade)
	outdoorAmbient: Color3, -- Lighting.OutdoorAmbient
}

-- Weather event look, blended over the sky. nil fields leave the sky as it is.
export type Look = {
	atmosphereDensity: number?,
	atmosphereHaze: number?,
	atmosphereColor: Color3?,
	brightnessScale: number?, -- multiplies Lighting.Brightness
	fadeSeconds: number,
}

local DataMapping = {}

DataMapping.sky = table.freeze({
	-- Sun high: pale butterscotch sky, darker toward the zenith.
	day = table.freeze({
		density = 0.34,
		offset = 0.6,
		color = Color3.fromRGB(242, 212, 176),
		decay = Color3.fromRGB(214, 168, 124),
		glare = 1,
		haze = 3,
		brightness = 2.2,
		ambient = Color3.fromRGB(90, 75, 68),
		outdoorAmbient = Color3.fromRGB(135, 116, 102),
	}),
	-- Sun near the horizon: on Mars the glow around the sun is blue.
	sunset = table.freeze({
		density = 0.3,
		offset = 0.4,
		color = Color3.fromRGB(86, 140, 225),
		decay = Color3.fromRGB(96, 62, 46),
		glare = 6,
		haze = 2,
		brightness = 1.4,
		ambient = Color3.fromRGB(60, 52, 54),
		outdoorAmbient = Color3.fromRGB(90, 80, 86),
	}),
	-- Night: thin air, so the sky is nearly black and full of stars.
	night = table.freeze({
		density = 0.25,
		offset = 0,
		color = Color3.fromRGB(12, 12, 16),
		decay = Color3.fromRGB(6, 6, 10),
		glare = 0,
		haze = 0,
		brightness = 0.4,
		ambient = Color3.fromRGB(34, 32, 38),
		outdoorAmbient = Color3.fromRGB(46, 44, 56),
	}),
} :: { [string]: SkyPreset })

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
	-- Solar flare: a quick, slightly brighter and whiter sky.
	flare = table.freeze({
		atmosphereColor = Color3.fromRGB(255, 240, 220),
		brightnessScale = 1.3,
		fadeSeconds = 1,
	}),
	-- Radiation storm and CME: radiation is invisible, so no sky change (card only).
} :: { [string]: Look })

-- Personal radiation dose (see RadiationModel). Real rates come from the radlab snapshot;
-- these two are game feel and must be named as such in the debrief.
DataMapping.radiation = table.freeze({
	speedUp = 600, -- 1 game second outside = 10 Mars minutes of dose
	limitMarsDays = 30, -- mission limit = 30 days of the usual Mars background
	tickSeconds = 1,
})

-- How long an event stays on in the demo loop, and the calm gap between events.
DataMapping.demoEventSeconds = 45
DataMapping.demoCalmSeconds = 30

return table.freeze(DataMapping)
