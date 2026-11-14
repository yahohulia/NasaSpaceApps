--!strict
-- Numbers for sample pickup, satellite salvage, sorting and the craftable ice drill.
-- All numbers here are GAME VALUES, not NASA data. -- game value, TODO balance
-- Player-facing text lives in i18n (keys "craft.*"), read through Shared.Strings.
local CraftConfig = {}

CraftConfig.BagSize = 10 -- samples a player can carry before sorting -- game value, TODO balance

-- Metals stored in the shared base store (attributes on MB_BaseState).
CraftConfig.Metals = { "Iron", "Nickel", "Manganese" }

-- What one sample of each kind gives when it is sorted. Which metal comes from which sample
-- follows real rover finds (kb/data/mars-metals.md); the amounts are -- game value, TODO balance
CraftConfig.Yield = {
	Rock = {},
	Hematite = { Iron = 1 }, -- hematite spherules, Opportunity
	IronMeteorite = { Iron = 2, Nickel = 1 }, -- iron-nickel meteorites, Opportunity/Curiosity
	Large = { Iron = 5, Nickel = 2 }, -- the big meteorite in Workspace.MeteoriteSite
	Manganese = { Manganese = 1 }, -- sandstone with dark manganese oxide veins, Curiosity
} :: { [string]: { [string]: number } }

-- What the ice drill costs, taken from the shared base store. -- game value, TODO balance
CraftConfig.Recipe = { Iron = 3, Parts = 1 }

CraftConfig.PromptDistance = 8
-- Seconds to hold the prompt key. -- game value, TODO balance
CraftConfig.Hold = {
	Pickup = 0.3,
	Salvage = 2,
	Sort = 2,
	Build = 3,
	Pack = 2,
	Setup = 2,
}

-- Where the centre of the drill model stands relative to the ice spot part (world offset, studs).
-- Zero puts the borehole about 1 stud from the spot, over the ice patch.
CraftConfig.DrillOffset = Vector3.zero

CraftConfig.SortStationTag = "Craft_SortStation"
-- Same tag MB_ResourceServer uses for its "Dig ice" prompt; ice spots are parts with this tag.
CraftConfig.IceSiteTag = "MB_Drill"
-- The prompt MB_ResourceServer creates on ice spots; Crafting only toggles its Enabled.
CraftConfig.DigPromptName = "MB_Prompt"

return CraftConfig
