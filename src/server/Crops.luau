--!strict
-- Greenhouse crops: seeds from the crate in the storage room, planting on the plant racks, growth,
-- care, harvest and eating. The server owns all of it; CropClient and CraftClient only show it.
--
-- Built in Studio (Workspace, not Rojo): the seed crate (a part tagged SeedCrate inside a Model with
-- Attachments Slot1..SlotN), the racks (Workspace.Greenhouse_PlantRacks.PlantRack_*), and the
-- journal board (a part tagged CropJournal).
--
-- Inventory: Player.CropBag (Folder) holds the crop items, each a StringValue (they share the
-- bag places with the rock samples and ice, see Shared.BagSpace):
--   Name "Seed" or "Produce", Value = crop id, attributes Order (pickup order) and Food (produce).
-- CraftClient shows them in the inventory bar next to the samples.
--
-- Care: at the crop's care points a rack gets NeedsCare = true. The teammate's Studio script
-- FarmMinigameServer lights up only those racks and sets NeedsCare = false after a won mini game.
-- While a rack waits for care its crop grows slower and loses health; health scales the harvest.
-- Without FarmMinigameServer (no ReplicatedStorage.FarmMinigameRemote) racks never ask for care.
--
-- Rack attributes (replicated, CropClient reads them): Crop, Growth, Health, Ready, NeedsCare.
-- Shared stats: ReplicatedStorage.CropStats attributes <id>_Harvests, _Seconds, _Food, _Best.
-- Remote CropPick: server -> client "open" (crate picker), "plant" {rack, kinds} (which seed?);
-- client -> server "take" id, "plant" rack id, "eat".
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BagSpace = require(ReplicatedStorage.Shared.BagSpace)
local CropConfig = require(ReplicatedStorage.Shared.CropConfig)
local CropModels = require(ReplicatedStorage.Shared.CropModels)
local Strings = require(ReplicatedStorage.Shared.Strings)

local Crops = {}

type Rack = {
	model: Model,
	frame: BasePart,
	prompt: ProximityPrompt,
	plants: Folder,
	crop: string?,
	growth: number,
	health: number,
	plantedAt: number,
	careIndex: number, -- next care point of the crop
	waitingCare: boolean,
	planter: Player?,
	seed: number,
	shownStep: number, -- growth step the plant models were last built for
}

local racks: { Rack } = {}
local byModel: { [Model]: Rack } = {}
local notify: RemoteEvent -- CraftNotify (toasts; CraftClient translates crop ids in vars)
local pickRemote: RemoteEvent -- CropPick
local stats: Folder
local crates: { BasePart } = {}
local rng = Random.new()
local order = 0

local function num(inst: Instance, key: string): number
	local v = inst:GetAttribute(key)
	return if typeof(v) == "number" then v else 0
end

-- Prompts are made on the server in English; CropClient re-labels them in the player's language.
local function text(key: string, vars: { [string]: string | number }?): string
	return Strings.get(key, "en", vars)
end

local function careAvailable(): boolean
	return ReplicatedStorage:FindFirstChild("FarmMinigameRemote") ~= nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Crop bag -------------------------------------------------------------------------------------------

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

-- Items of one kind ("Seed" / "Produce"), oldest first.
local function items(player: Player, kind: string?): { StringValue }
	local list = {}
	for _, item in bagOf(player):GetChildren() do
		if item:IsA("StringValue") and (kind == nil or item.Name == kind) then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		return num(a, "Order") < num(b, "Order")
	end)
	return list
end

local function addItem(player: Player, kind: string, id: string, food: number?): boolean
	-- one bag for everything: rock samples, crop items and ice (Shared.BagSpace)
	if BagSpace.free(player) <= 0 then
		return false
	end
	order += 1
	local item = Instance.new("StringValue")
	item.Name = kind
	item.Value = id
	item:SetAttribute("Order", order)
	if food then
		item:SetAttribute("Food", food)
	end
	item.Parent = bagOf(player)
	return true
end

-- Plant models --------------------------------------------------------------------------------------

local VISUAL_STEPS = 10 -- rebuild the plant models every 10 % of growth (each rebuild is ~300 parts)

local function plantSpots(rack: Rack): { CFrame }
	local spots = {}
	for _, y in CropConfig.ShelfY do
		for _, x in CropConfig.SlotX do
			table.insert(spots, rack.frame.CFrame * CFrame.new(x, y, CropConfig.PlantZ))
		end
	end
	return spots
end

local function redraw(rack: Rack)
	rack.plants:ClearAllChildren()
	local crop = rack.crop
	if not crop then
		return
	end
	for i, cf in plantSpots(rack) do
		local model = CropModels.build(crop, rack.growth, rack.seed + i * 7, CropConfig.PlantHeight)
		model:PivotTo(cf * CFrame.Angles(0, (i * 1.37) % (math.pi * 2), 0))
		model.Parent = rack.plants
	end
	rack.shownStep = math.floor(rack.growth * VISUAL_STEPS)
end

local function publish(rack: Rack)
	local m = rack.model
	m:SetAttribute("Crop", rack.crop)
	m:SetAttribute("Growth", if rack.crop then math.floor(rack.growth * 100 + 0.5) / 100 else nil)
	m:SetAttribute("Health", if rack.crop then math.floor(rack.health * 100 + 0.5) / 100 else nil)
	m:SetAttribute("Ready", if rack.crop then rack.growth >= 1 else nil)
	local mode = if not rack.crop then "plant" elseif rack.growth >= 1 then "harvest" else "none"
	rack.prompt:SetAttribute("CropMode", mode)
	rack.prompt.Enabled = mode ~= "none"
	if mode == "plant" then
		rack.prompt.ActionText = text("crop.prompt.plantAny")
	elseif mode == "harvest" then
		rack.prompt.ActionText = text("crop.prompt.harvest")
	end
end

-- Stats ---------------------------------------------------------------------------------------------

local function addStats(crop: string, seconds: number, food: number)
	stats:SetAttribute(crop .. "_Harvests", num(stats, crop .. "_Harvests") + 1)
	stats:SetAttribute(crop .. "_Seconds", num(stats, crop .. "_Seconds") + math.floor(seconds + 0.5))
	stats:SetAttribute(crop .. "_Food", num(stats, crop .. "_Food") + food)
	stats:SetAttribute(crop .. "_Best", math.max(num(stats, crop .. "_Best"), food))
end

-- Planting, harvest, eating ---------------------------------------------------------------------------

-- Tells the mission director (MissionDirector) that a crew objective happened.
local function objectiveDone(player: Player?, id: string)
	local event = game:GetService("ServerStorage"):FindFirstChild("MB_ObjectiveDone")
	if event and event:IsA("BindableEvent") then
		event:Fire(player, id)
	end
end

-- Plants seed `id` (or, without `id`, the only kind of seed the player carries). With several kinds
-- the client is asked which one, and plants through the remote.
local function plant(rack: Rack, player: Player, id: string?)
	if rack.crop ~= nil then
		return
	end
	local seeds = items(player, "Seed")
	if #seeds == 0 then
		notify:FireClient(player, "crop.toast.no_seeds")
		return
	end
	if not id then
		local kinds: { string } = {}
		local seen: { [string]: boolean } = {}
		for _, item in seeds do
			if not seen[item.Value] then
				seen[item.Value] = true
				table.insert(kinds, item.Value)
			end
		end
		if #kinds > 1 then
			pickRemote:FireClient(player, "plant", { rack = rack.model, kinds = kinds })
			return
		end
		id = kinds[1]
	end
	local packet: StringValue? = nil
	for _, item in seeds do
		if item.Value == id then
			packet = item
			break
		end
	end
	local crop = if id then CropConfig.get(id) else nil
	if not (packet and crop) then
		return
	end
	local water = player:GetAttribute("Water")
	local cost = CropConfig.PlantWaterCost
	if typeof(water) == "number" then
		if water < cost then
			notify:FireClient(player, "crop.toast.no_water", { n = cost })
			return
		end
		player:SetAttribute("Water", water - cost)
	end
	packet:Destroy()
	rack.crop = crop.id
	rack.growth = 0
	rack.health = 1
	rack.plantedAt = os.clock()
	rack.careIndex = 1
	rack.waitingCare = false
	rack.planter = player
	rack.seed = rng:NextInteger(1, 1e6)
	rack.model:SetAttribute(CropConfig.CareAttribute, false)
	redraw(rack)
	publish(rack)
	notify:FireClient(player, "crop.toast.planted", { crop = crop.id, n = cost })
	objectiveDone(player, "plant")
	task.delay(3.8, function()
		notify:FireClient(player, "crop.fact." .. crop.id)
	end)
end

local function harvest(rack: Rack, player: Player)
	local id = rack.crop
	local crop = if id then CropConfig.get(id) else nil
	if not crop or rack.growth < 1 then
		return
	end
	local food = math.max(1, math.floor(crop.food * rack.health + 0.5))
	if not addItem(player, "Produce", crop.id, food) then
		notify:FireClient(player, "crop.toast.bag_full_harvest")
		return
	end
	addStats(crop.id, os.clock() - rack.plantedAt, food)
	rack.crop = nil
	rack.growth = 0
	rack.health = 1
	rack.waitingCare = false
	rack.planter = nil
	rack.model:SetAttribute(CropConfig.CareAttribute, false)
	redraw(rack)
	publish(rack)
	notify:FireClient(player, "crop.toast.harvested", { crop = crop.id, food = food })
	objectiveDone(player, "harvest")
end

local function eat(player: Player)
	local item = items(player, "Produce")[1]
	if not item then
		return
	end
	local food = num(item, "Food")
	local have = player:GetAttribute("Food")
	if typeof(have) == "number" then
		player:SetAttribute("Food", math.clamp(have + food, 0, 100))
	end
	local id = item.Value
	item:Destroy()
	notify:FireClient(player, "crop.toast.ate", { crop = id, food = food })
end

-- Growth --------------------------------------------------------------------------------------------

local function tell(rack: Rack, key: string, vars: { [string]: string | number })
	local who = rack.planter
	if who and who.Parent then
		notify:FireClient(who, key, vars)
	end
end

local function grow(rack: Rack, dt: number)
	local id = rack.crop
	local crop = if id then CropConfig.get(id) else nil
	if not crop or rack.growth >= 1 then
		return
	end
	local speed = 1
	if rack.waitingCare then
		speed = CropConfig.CareSlowdown
		rack.health = math.max(CropConfig.HealthMin, rack.health - CropConfig.HealthLossPerSecond * dt)
	end
	rack.growth = math.min(1, rack.growth + dt * speed / (crop.realDays * CropConfig.SecondsPerRealDay))

	local point = crop.carePoints[rack.careIndex]
	if point and rack.growth >= point and not rack.waitingCare then
		rack.careIndex += 1
		if careAvailable() then
			rack.waitingCare = true
			rack.model:SetAttribute(CropConfig.CareAttribute, true)
			tell(rack, "crop.toast.care", { crop = crop.id })
		end
	end
	if rack.growth >= 1 then
		rack.waitingCare = false
		rack.model:SetAttribute(CropConfig.CareAttribute, false)
		tell(rack, "crop.toast.ready", { crop = crop.id })
	end
	if math.floor(rack.growth * VISUAL_STEPS) ~= rack.shownStep or rack.growth >= 1 then
		redraw(rack)
	end
	publish(rack)
end

-- Setup ---------------------------------------------------------------------------------------------

local function bindRack(model: Model)
	local frame = model:FindFirstChild(CropConfig.RackFramePart)
	if not (frame and frame:IsA("BasePart")) or model:FindFirstChild("CropPlants") then
		return
	end
	local at = Instance.new("Attachment")
	at.Name = "CropPromptAt"
	at.Position = CropConfig.PromptOffset
	at.Parent = frame
	local info = Instance.new("Attachment")
	info.Name = "CropInfoAt"
	info.Position = CropConfig.InfoOffset
	info.Parent = frame

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CropPrompt"
	prompt.ActionText = text("crop.prompt.plantAny")
	prompt.ObjectText = text("crop.object.rack")
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = CropConfig.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = at

	local plants = Instance.new("Folder")
	plants.Name = "CropPlants"
	plants.Parent = model

	local rack: Rack = {
		model = model,
		frame = frame,
		prompt = prompt,
		plants = plants,
		crop = nil,
		growth = 0,
		health = 1,
		plantedAt = 0,
		careIndex = 1,
		waitingCare = false,
		planter = nil,
		seed = 0,
		shownStep = -1,
	}
	table.insert(racks, rack)
	byModel[model] = rack
	model:SetAttribute(CropConfig.CareAttribute, false)

	prompt.Triggered:Connect(function(player)
		if rack.crop == nil then
			plant(rack, player, nil)
		elseif rack.growth >= 1 then
			harvest(rack, player)
		end
	end)
	-- FarmMinigameServer sets NeedsCare back to false after a won care game
	model:GetAttributeChangedSignal(CropConfig.CareAttribute):Connect(function()
		if model:GetAttribute(CropConfig.CareAttribute) ~= true and rack.waitingCare then
			rack.waitingCare = false
			rack.health = math.min(1, rack.health + CropConfig.CareHealthBonus)
			publish(rack)
		end
	end)
	publish(rack)
end

local function nearCrate(player: Player): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	for _, crate in crates do
		if (crate.Position - root.Position).Magnitude <= CropConfig.CrateDistance then
			return true
		end
	end
	return false
end

-- A seed packet and a little grown plant in each crate slot, so kids see what each seed becomes.
local function fillCrate(crate: BasePart)
	local model = crate:FindFirstAncestorOfClass("Model")
	if not model or model:FindFirstChild("CrateDisplay") then
		return
	end
	local display = Instance.new("Folder")
	display.Name = "CrateDisplay"
	display.Parent = model
	for i, crop in CropConfig.Crops do
		local slot = model:FindFirstChild(CropConfig.CrateSlotPrefix .. i, true)
		if slot and slot:IsA("Attachment") then
			local base = slot.WorldCFrame
			local plantModel = CropModels.build(crop.id, 1, i * 31, 0.62)
			plantModel:PivotTo(base * CFrame.new(0.18, 0, 0))
			plantModel.Parent = display
			local packet = CropModels.packet(crop.id)
			packet:PivotTo(base * CFrame.new(-0.28, 0.02, 0) * CFrame.Angles(math.rad(-12), math.rad(90), 0))
			packet.Parent = display
		end
	end
end

local function bindCrate(inst: Instance)
	if not inst:IsA("BasePart") or inst:FindFirstChild("CropCratePrompt") then
		return
	end
	table.insert(crates, inst)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CropCratePrompt"
	prompt.ActionText = text("crop.prompt.take")
	prompt.ObjectText = text("crop.object.crate")
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = CropConfig.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("CropMode", "crate")
	prompt.Parent = inst
	prompt.Triggered:Connect(function(player)
		pickRemote:FireClient(player, "open")
	end)
	fillCrate(inst)
end

local function remoteEvent(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = ReplicatedStorage
	return r
end

local function onPick(player: Player, action: unknown, a: unknown, b: unknown)
	if action == "take" then
		if typeof(a) ~= "string" or not CropConfig.get(a) or not nearCrate(player) then
			return
		end
		if addItem(player, "Seed", a) then
			notify:FireClient(player, "crop.toast.took", { crop = a })
		else
			notify:FireClient(player, "crop.toast.bag_full")
		end
	elseif action == "plant" then
		if typeof(a) ~= "Instance" or not a:IsA("Model") or typeof(b) ~= "string" then
			return
		end
		local rack = byModel[a]
		local root = rootOf(player)
		if rack and root and (rack.frame.Position - root.Position).Magnitude <= CropConfig.PromptDistance + 4 then
			plant(rack, player, b)
		end
	elseif action == "eat" then
		eat(player)
	end
end

function Crops.start()
	notify = remoteEvent("CraftNotify")
	pickRemote = remoteEvent("CropPick")

	local existing = ReplicatedStorage:FindFirstChild("CropStats")
	if existing and existing:IsA("Folder") then
		stats = existing
	else
		stats = Instance.new("Folder")
		stats.Name = "CropStats"
		stats.Parent = ReplicatedStorage
	end
	for _, crop in CropConfig.Crops do
		for _, key in { "_Harvests", "_Seconds", "_Food", "_Best" } do
			if stats:GetAttribute(crop.id .. key) == nil then
				stats:SetAttribute(crop.id .. key, 0)
			end
		end
	end

	pickRemote.OnServerEvent:Connect(onPick)
	Players.PlayerAdded:Connect(bagOf)
	for _, player in Players:GetPlayers() do
		bagOf(player)
	end

	for _, inst in CollectionService:GetTagged(CropConfig.SeedCrateTag) do
		bindCrate(inst)
	end
	CollectionService:GetInstanceAddedSignal(CropConfig.SeedCrateTag):Connect(bindCrate)

	local folder = workspace:WaitForChild(CropConfig.RackFolder, 30)
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				bindRack(child)
			end
		end
	else
		warn("[Crops] Workspace." .. CropConfig.RackFolder .. " is missing")
	end

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, rack in racks do
				if rack.crop then
					grow(rack, dt)
				end
			end
		end
	end)
	print(`[crops] {#racks} racks, {#crates} seed crates`)
end

return Crops
