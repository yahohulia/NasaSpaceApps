--!strict
-- Crops for the greenhouse racks: the seed crate in the storage room, planting, growth, care and
-- harvest (server: Crops.luau, client: CropClient.luau, models: CropModels.luau).
-- Only crops NASA really grew in space. RealDays = days from planting to the first harvest in the
-- NASA test, see kb/data/space-crops.md. Everything else here is a GAME VALUE. -- TODO balance
-- Player-facing text lives in i18n (keys "crop.*"), read through Shared.Strings.
local CropConfig = {}

export type Crop = {
	id: string,
	realDays: number, -- NASA: days from planting to the first harvest (kb/data/space-crops.md)
	food: number, -- Food for a healthy harvest -- game value, TODO balance
	carePoints: { number }, -- growth shares (0..1) where the rack asks for care -- game value
	color: Color3, -- seed packet and journal colour
}

-- Order = order in the seed crate, the picker and the journal.
CropConfig.Crops = {
	{ id = "Radish", realDays = 27, food = 8, carePoints = { 0.5 }, color = Color3.fromRGB(214, 46, 78) },
	{ id = "Wheat", realDays = 30, food = 9, carePoints = { 0.5 }, color = Color3.fromRGB(222, 184, 84) },
	{ id = "Lettuce", realDays = 33, food = 11, carePoints = { 0.45 }, color = Color3.fromRGB(150, 40, 70) },
	{ id = "Mizuna", realDays = 35, food = 11, carePoints = { 0.45 }, color = Color3.fromRGB(96, 176, 70) },
	-- tomatoes and peppers are harder in space (NASA): slower and need care more often
	{ id = "Tomato", realDays = 90, food = 30, carePoints = { 0.3, 0.6, 0.85 }, color = Color3.fromRGB(226, 60, 40) },
	{ id = "Pepper", realDays = 109, food = 36, carePoints = { 0.3, 0.6, 0.85 }, color = Color3.fromRGB(196, 30, 30) },
} :: { Crop }

local byId: { [string]: Crop } = {}
for _, crop in CropConfig.Crops do
	byId[crop.id] = crop
end

function CropConfig.get(id: string): Crop?
	return byId[id]
end

-- Seconds of play for one real NASA day. The same speed-up for every crop, so the order of who grows
-- faster stays real. Radish: 27 * 4 = 108 s, pepper: 109 * 4 = 436 s. -- game value, TODO balance
CropConfig.SecondsPerRealDay = 4

-- Every action costs something (game rule 2). -- game values, TODO balance
CropConfig.PlantWaterCost = 5 -- player Water spent to plant a rack
CropConfig.CareSlowdown = 0.25 -- growth speed while the rack waits for care
CropConfig.HealthLossPerSecond = 0.01 -- health lost per second while the rack waits for care
CropConfig.HealthMin = 0.3 -- a neglected crop still gives this share of its food
CropConfig.CareHealthBonus = 0.15 -- health back after a care mini game

-- Rack geometry (offsets from each rack's Rack_Frame CFrame; LookVector = the front of the rack).
-- Tray tops of the 5 shelves are at Y +2.30, +1.05, -0.20, -1.45, -2.72; the top one sits under the
-- LED panel, so plants go on the lower four, three per shelf.
CropConfig.RackFolder = "Greenhouse_PlantRacks"
CropConfig.RackFramePart = "Rack_Frame"
CropConfig.ShelfY = { 1.05, -0.2, -1.45, -2.72 }
CropConfig.SlotX = { -0.95, 0, 0.95 }
CropConfig.PlantZ = -0.1 -- a little toward the front
CropConfig.PlantHeight = 1 -- studs, height of a fully grown plant on the shelf
CropConfig.PromptOffset = Vector3.new(0, 0.4, -1.3) -- in front of the rack, at chest height
CropConfig.InfoOffset = Vector3.new(0, 4.3, -0.6) -- above the rack, for the progress label

CropConfig.SeedCrateTag = "SeedCrate" -- the part with the "Take seeds" prompt
CropConfig.CrateSlotPrefix = "Slot" -- Attachments Slot1..SlotN inside the crate model
CropConfig.JournalTag = "CropJournal" -- a part whose front face shows the greenhouse journal
CropConfig.PromptDistance = 8
CropConfig.CrateDistance = 12 -- how close to the crate a player must be to take seeds

-- The rack mini games (Studio script FarmMinigameServer, by a teammate) light up only racks with
-- NeedsCare = true and set it back to false after a won game.
CropConfig.CareAttribute = "NeedsCare"

return CropConfig
