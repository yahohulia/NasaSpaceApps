--!strict
-- One bag for everything a player carries, CraftConfig.BagSize places in all:
--   rock samples   - Player attribute BagSamples (server: Crafting)
--   seeds, harvest - Player.CropBag children     (server: Crops)
--   ice            - Player attribute Ice         (server: MB_ResourceServer, dug at the drill)
-- CraftClient shows all of them in the same inventory slots.
local CraftConfig = require(script.Parent.CraftConfig)

local BagSpace = {}

BagSpace.Size = CraftConfig.BagSize

local function num(inst: Instance, key: string): number
	local v = inst:GetAttribute(key)
	return if typeof(v) == "number" then v else 0
end

function BagSpace.ice(player: Player): number
	return math.floor(num(player, "Ice"))
end

function BagSpace.crops(player: Player): number
	local bag = player:FindFirstChild("CropBag")
	return if bag then #bag:GetChildren() else 0
end

function BagSpace.used(player: Player): number
	return num(player, "BagSamples") + BagSpace.crops(player) + BagSpace.ice(player)
end

function BagSpace.free(player: Player): number
	return math.max(0, CraftConfig.BagSize - BagSpace.used(player))
end

return BagSpace
