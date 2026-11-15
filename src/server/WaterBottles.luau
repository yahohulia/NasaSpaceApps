--!strict
-- The ice melter at the water station (part tagged MB_WaterStation, prompt made by MB_ResourceServer's
-- "Drink" action): each use melts one piece of ice (Player@Ice) into a bottle of water that goes into the
-- shared bag (Player.CropBag, StringValue named WaterBottle.KIND, CraftConfig.BagSize places together with
-- the rock samples and the crop items). The player drinks a bottle later with WaterBottleClient
-- (RemoteEvent WaterDrink). The water pump must work for the melter, as before (MB_ResourceServer).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CraftConfig = require(ReplicatedStorage.Shared.CraftConfig)
local Notice = require(script.Parent.Notice)
local Strings = require(ReplicatedStorage.Shared.Strings)
local WaterBottle = require(ReplicatedStorage.Shared.WaterBottle)

local WaterBottles = {}

local function bagOf(player: Player): Folder
	local existing = player:FindFirstChild("CropBag")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "CropBag"
	folder.Parent = player
	return folder
end

local function bottles(player: Player): { StringValue }
	local list = {}
	for _, item in bagOf(player):GetChildren() do
		if item:IsA("StringValue") and item.Name == WaterBottle.KIND then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)
	return list
end

-- Melts one piece of ice into a bottle (called by MB_ResourceServer's water station prompt).
function WaterBottles.melt(player: Player)
	local ice = player:GetAttribute("Ice")
	if typeof(ice) ~= "number" or ice < 1 then
		Notice.send(player, "water.toast.no_ice", "warn")
		return
	end
	local samples = player:GetAttribute("BagSamples")
	local used = #bagOf(player):GetChildren() + (if typeof(samples) == "number" then samples else 0)
	if used >= CraftConfig.BagSize then
		Notice.send(player, "water.toast.bag_full", "warn")
		return
	end
	player:SetAttribute("Ice", ice - 1)
	local item = Instance.new("StringValue")
	item.Name = WaterBottle.KIND
	item.Value = "Bottle"
	item:SetAttribute("Order", os.clock()) -- after the crop items already in the bag
	item:SetAttribute("Water", WaterBottle.WATER)
	item.Parent = bagOf(player)
	Notice.send(player, "water.toast.bottle", "info", { key = WaterBottle.KEY.Name })
end

local function drink(player: Player)
	local item = bottles(player)[1]
	if not item then
		return
	end
	local water = player:GetAttribute("Water")
	if typeof(water) == "number" then
		local gain = item:GetAttribute("Water")
		player:SetAttribute("Water", math.clamp(water + (if typeof(gain) == "number" then gain else 0), 0, 100))
	end
	item:Destroy()
end

function WaterBottles.start()
	local remote = ReplicatedStorage:FindFirstChild("WaterDrink")
	if not (remote and remote:IsA("RemoteEvent")) then
		local r = Instance.new("RemoteEvent")
		r.Name = "WaterDrink"
		r.Parent = ReplicatedStorage
		remote = r
	end
	(remote :: RemoteEvent).OnServerEvent:Connect(drink)

	-- The melter's prompt says what it does now (MB_ResourceServer makes it with the old text).
	local function relabel(station: Instance)
		task.spawn(function()
			local prompt = station:WaitForChild("MB_Prompt", 30)
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.ActionText = Strings.get("water.prompt.melt", "en")
				prompt.ObjectText = Strings.get("water.object.melter", "en")
			end
		end)
	end
	for _, station in CollectionService:GetTagged("MB_WaterStation") do
		relabel(station)
	end
	CollectionService:GetInstanceAddedSignal("MB_WaterStation"):Connect(relabel)
end

return WaterBottles
