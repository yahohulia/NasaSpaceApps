--!strict
-- Numbers for sample pickup, satellite salvage, sorting and the craftable ice drill.
-- All numbers here are GAME VALUES, not NASA data. -- game value, TODO balance
-- Player-facing text lives in i18n (keys "craft.*"), read through Shared.Strings.
local CraftConfig = {}

CraftConfig.BagSize = 10 -- samples a player can carry before sorting -- game value, TODO balance

-- Iron you get from one sample of each kind when it is sorted. -- game value, TODO balance
CraftConfig.IronYield = {
	Rock = 0,
	Hematite = 1,
	IronMeteorite = 2,
	Large = 5, -- the big meteorite in Workspace.MeteoriteSite
} :: { [string]: number }

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
