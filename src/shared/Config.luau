--!strict
-- Game values shared by server and client. These are game values (balance / UI), not NASA data.
-- Real-world numbers live in kb/data/ and must be cited where they are used.

export type ResourceName = "Oxygen" | "Water" | "Food"
export type RoleName = "Engineer" | "Botanist" | "Driller"

local Config = {
	-- The three shared resources, in HUD order (left to right).
	Resources = { "Oxygen", "Water", "Food" } :: { ResourceName },
	Roles = { "Engineer", "Botanist", "Driller" } :: { RoleName },

	-- Player attributes the server sets and the HUD reads.
	PlayerAttributes = {
		Role = "Role", -- string, one of Roles
		Dose = "RadiationDose", -- number, 0..Dose.Limit (game units)
	},

	Dose = {
		Limit = 100, -- game value, TODO balance: dose at which the HUD bar is full
	},

	Hud = {
		Segments = 10, -- cells in each HUD bar
		LowFraction = 0.3, -- game value: a bar turns to the warning colour at or below this share
		-- Parts or models with this tag get an on-screen marker. Attributes:
		--   Label (string): Strings key, e.g. "hud.marker.farm"
		--   Kind (string, optional): "alert" (broken machine) or "objective" (default)
		MarkerTag = "HudMarker",
		MetersPerStud = 0.28, -- Roblox avatar-scale convention, used only to show distances
	},

	-- Studio-only fake data so the HUD can be tested before ResourceSystem / StormEvent exist.
	DevHudFeed = true,
}

return Config
