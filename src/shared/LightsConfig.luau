--!strict
-- Base lights: rooms, the light panel and the look of the lamps (all game values, not NASA data).
-- Rooms are the parts in Workspace.Base.Zones (built in Studio); a room id is the part name
-- without "Zone" (EnergyGeneratorZone -> EnergyGenerator).

export type LampLook = {
	color: Color3,
	spotBrightness: number, -- warm cone from the ceiling, casts shadows (the "cinema" pool of light)
	spotRange: number,
	fillBrightness: number, -- the lamp's own PointLight, soft and shadowless
	fillRange: number,
	glassColor: Color3, -- colour of the lamp's own part (the glowing disc)
}

local LightsConfig = {}

-- Where the rooms and lamps are in the place.
LightsConfig.ZonesFolder = { "Base", "Zones" }
LightsConfig.LampFolders = { "MarsBaseFixes", "MB_CorridorRebuild" }
LightsConfig.SkipZones = { MedBay = true } -- tiny marker inside the bedroom, not a room

-- Order of rooms on the panel. Rooms without lamps are left out automatically.
LightsConfig.Rooms = {
	"CentralCorridor",
	"Airlock",
	"EnergyGenerator",
	"AirGenerator",
	"WaterStation",
	"ScienceStation",
	"Bedroom",
	"Storage",
	"Farm",
}

LightsConfig.PanelTag = "LightPanel" -- part with the panel screen (in the power room)
LightsConfig.PanelDistance = 9 -- studs: prompt distance; the server allows a bit more
LightsConfig.ToggleCooldown = 0.25 -- seconds between two clicks of one player
-- Every lit room uses base power (MB_ResourceServer reads MB_BaseState@LitRooms), so switching rooms
-- off on the panel saves power after a dust storm. Base power is 0..100; the sun gives 0.35/s.
LightsConfig.PowerPerLitRoom = 0.01 -- game value, TODO balance: power per second per lit room

-- Lights on: warm, a bit dramatic. Lights off: a faint cold night glow so you still see the way.
LightsConfig.On = {
	color = Color3.fromRGB(255, 212, 166),
	spotBrightness = 1.6,
	spotRange = 15,
	fillBrightness = 0.12,
	fillRange = 9,
	glassColor = Color3.fromRGB(255, 236, 205),
} :: LampLook
LightsConfig.Off = {
	color = Color3.fromRGB(80, 130, 255),
	spotBrightness = 0,
	spotRange = 15,
	fillBrightness = 0.1,
	fillRange = 11,
	glassColor = Color3.fromRGB(38, 52, 82),
} :: LampLook
LightsConfig.SpotAngle = 70 -- degrees, cone of the ceiling spot

LightsConfig.FadeSeconds = 0.6 -- lights going off
LightsConfig.RippleSeconds = 0.06 -- delay between lamps of one room when they start (a wave)

-- Client look while inside the base. Roblox lets the sky light (OutdoorAmbient, environment
-- light) leak under the thin base roof, so inside we turn those down too.
LightsConfig.InteriorAmbientOn = 0.35 -- Lighting.Ambient scale, room lights on
LightsConfig.InteriorAmbientOff = 0.1 -- room lights off: almost dark
LightsConfig.InteriorOutdoorAmbient = 0.2 -- Lighting.OutdoorAmbient scale inside
LightsConfig.InteriorOutdoorAmbientOff = 0.08
LightsConfig.InteriorEnvDiffuse = 0.25 -- Lighting.EnvironmentDiffuseScale inside
LightsConfig.InteriorEnvSpecular = 0.5 -- Lighting.EnvironmentSpecularScale inside
LightsConfig.InteriorBlendSeconds = 1.2
LightsConfig.InteriorGrade = {
	contrast = 0.12,
	saturation = -0.04,
	tint = Color3.fromRGB(255, 244, 232),
}

return LightsConfig
