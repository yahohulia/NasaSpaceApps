--!strict
-- Sample pickup, satellite salvage, sorting, and the craftable, movable ice drill.
-- The server owns this state; CraftClient only shows it.
--
-- Built in Studio (Workspace, not Rojo): Workspace.Samples and Workspace.MeteoriteSite
-- (parts/models with SampleKind), Workspace.CrashedSatellite (parts with Salvage), a part tagged
-- Craft_SortStation, ice spots tagged MB_Drill, and ServerStorage.CraftDrillTemplate (Model with
-- a GroundOffset attribute: studs from the bounding-box bottom up to its feet).
--
-- It does not edit the MB_ scripts. MB_ResourceServer puts a "Dig ice" prompt (MB_Prompt) on
-- every MB_Drill part; we only switch it on where the drill stands, and off everywhere else.
--
-- Player attributes: BagSamples, CarryParts (numbers), CarryingDrill (boolean).
-- Shared store, attributes on ReplicatedStorage.MB_BaseState: Iron, Rocks, Parts, DrillBuilt.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CraftConfig = require(ReplicatedStorage.Shared.CraftConfig)
local Strings = require(ReplicatedStorage.Shared.Strings)

local Crafting = {}

type Bag = { [string]: number }

local notify: RemoteEvent
local store: Instance
local bags: { [Player]: Bag } = {}

local drillFolder: Folder
local drillModel: Model? = nil
local drillSite: BasePart? = nil -- where the drill stands now
local lastSite: BasePart? = nil
local carrier: Player? = nil

local sites: { BasePart } = {}
local craftPrompts: { [BasePart]: ProximityPrompt } = {}
local packPrompts: { [BasePart]: ProximityPrompt } = {}

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local function num(inst: Instance, key: string): number
	local v = inst:GetAttribute(key)
	return if typeof(v) == "number" then v else 0
end

-- Prompts are made on the server, so they use English; toasts are translated on the client.
local function text(key: string, vars: { [string]: string | number }?): string
	return Strings.get(key, "en", vars)
end

local function makePrompt(parent: Instance, name: string, action: string, object: string, hold: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = CraftConfig.PromptDistance
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

-- Samples -----------------------------------------------------------------------------------

-- A visual copy of each picked sample goes to Player.SampleBag, so the client can show it in
-- the inventory (no text, the kid sorts by look). The server's bag table stays the truth.
local function bagFolder(player: Player): Folder
	local f = player:FindFirstChild("SampleBag")
	if f and f:IsA("Folder") then
		return f
	end
	local folder = Instance.new("Folder")
	folder.Name = "SampleBag"
	folder.Parent = player
	return folder
end

local function putInBagView(player: Player, sample: Instance)
	local copy = sample:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("ProximityPrompt") or d:IsA("ParticleEmitter") or d:IsA("Attachment") or d:IsA("Light") then
			d:Destroy()
		end
	end
	copy.Parent = bagFolder(player)
end

local function bindSample(sample: Instance)
	local kind = sample:GetAttribute("SampleKind")
	if typeof(kind) ~= "string" or sample:GetAttribute("Collected") == true then
		return
	end
	local part: BasePart? = nil
	if sample:IsA("Model") then
		part = sample.PrimaryPart
	elseif sample:IsA("BasePart") then
		part = sample
	end
	if not part or part:FindFirstChild("CraftPrompt") then
		return
	end
	local key = if sample:GetAttribute("Large") == true then "Large" else kind
	local prompt = makePrompt(
		part,
		"CraftPrompt",
		text("craft.prompt.pickup"),
		text("craft.object.sample"),
		CraftConfig.Hold.Pickup
	)
	prompt.Triggered:Connect(function(player)
		if sample:GetAttribute("Collected") == true then
			return
		end
		local bag = bags[player]
		local n = num(player, "BagSamples")
		if not bag or n >= CraftConfig.BagSize then
			notify:FireClient(player, "craft.toast.bag_full")
			return
		end
		bag[key] = (bag[key] or 0) + 1
		player:SetAttribute("BagSamples", n + 1)
		sample:SetAttribute("Collected", true)
		putInBagView(player, sample)
		sample:Destroy()
		notify:FireClient(player, "craft.toast.picked", { n = n + 1, max = CraftConfig.BagSize })
	end)
end

local function bindSampleFolder(name: string)
	local root = workspace:FindFirstChild(name)
	if not root then
		return
	end
	for _, child in root:GetChildren() do
		bindSample(child)
	end
	root.ChildAdded:Connect(bindSample)
end

-- Satellite salvage -------------------------------------------------------------------------

local function bindSalvage()
	local satellite = workspace:FindFirstChild("CrashedSatellite")
	if not satellite then
		return
	end
	for _, point in satellite:GetChildren() do
		if
			point:IsA("BasePart")
			and typeof(point:GetAttribute("Salvage")) == "string"
			and point:GetAttribute("Salvaged") ~= true
		then
			local prompt = makePrompt(
				point,
				"CraftPrompt",
				text("craft.prompt.salvage"),
				text("craft.object.satellite"),
				CraftConfig.Hold.Salvage
			)
			prompt.Triggered:Connect(function(player)
				if point:GetAttribute("Salvaged") == true then
					return
				end
				point:SetAttribute("Salvaged", true)
				prompt:Destroy()
				player:SetAttribute("CarryParts", num(player, "CarryParts") + 1)
				notify:FireClient(player, "craft.toast.part_got")
			end)
		end
	end
end

-- Sorting table -----------------------------------------------------------------------------

local function sortFor(player: Player)
	local bag = bags[player] or {}
	local parts = num(player, "CarryParts")
	if num(player, "BagSamples") <= 0 and parts <= 0 then
		notify:FireClient(player, "craft.toast.nothing")
		return
	end
	local got: { [string]: number } = {}
	for _, metal in CraftConfig.Metals do
		got[metal] = 0
	end
	local rocks = 0
	for kind, count in bag do
		for metal, amount in CraftConfig.Yield[kind] or {} do
			got[metal] = (got[metal] or 0) + amount * count
		end
		if kind == "Rock" then
			rocks += count
		end
	end
	for metal, amount in got do
		store:SetAttribute(metal, num(store, metal) + amount)
	end
	store:SetAttribute("Rocks", num(store, "Rocks") + rocks)
	store:SetAttribute("Parts", num(store, "Parts") + parts)
	bags[player] = {}
	bagFolder(player):ClearAllChildren()
	player:SetAttribute("BagSamples", 0)
	player:SetAttribute("CarryParts", 0)
	notify:FireClient(player, "craft.toast.sorted", {
		iron = got.Iron or 0,
		nickel = got.Nickel or 0,
		manganese = got.Manganese or 0,
		rocks = rocks,
		parts = parts,
	})
end

local function bindSortStation(inst: Instance)
	if not inst:IsA("BasePart") or inst:FindFirstChild("CraftPrompt") then
		return
	end
	local prompt = makePrompt(
		inst,
		"CraftPrompt",
		text("craft.prompt.sort"),
		text("craft.object.sortTable"),
		CraftConfig.Hold.Sort
	)
	prompt.Triggered:Connect(sortFor)
end

-- Ice drill ---------------------------------------------------------------------------------

local function placeDrill(at: BasePart)
	local template = ServerStorage:FindFirstChild("CraftDrillTemplate")
	if not (template and template:IsA("Model")) then
		warn("[Crafting] ServerStorage.CraftDrillTemplate is missing")
		return
	end
	local model = template:Clone()
	model.Name = "IceDrill"
	local centre = at.Position + CraftConfig.DrillOffset
	local hit = workspace:Raycast(centre + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), groundParams)
	local groundY = if hit then hit.Position.Y else at.Position.Y
	-- same rotation everywhere (control unit faces -Z); the borehole ends up over the ice patch
	model:PivotTo(CFrame.new(centre))
	-- then stand the feet on the ground (the drill string goes below them)
	local cf, size = model:GetBoundingBox()
	local below = model:GetAttribute("GroundOffset")
	local bottom = groundY - (if typeof(below) == "number" then below else 0)
	model:PivotTo(model:GetPivot() + Vector3.new(centre.X - cf.X, bottom - (cf.Y - size.Y / 2), centre.Z - cf.Z))
	model.Parent = drillFolder
	drillModel = model
	drillSite = at
	lastSite = at
end

local function removeDrill()
	if drillModel then
		drillModel:Destroy()
	end
	drillModel = nil
	drillSite = nil
end

local function refresh()
	local built = store:GetAttribute("DrillBuilt") == true
	for _, site in sites do
		local dig = site:FindFirstChild(CraftConfig.DigPromptName)
		if dig and dig:IsA("ProximityPrompt") then
			dig.Enabled = drillSite == site
		end
		local craft = craftPrompts[site]
		if not built then
			craft.Enabled = true
			craft.ActionText = text("craft.prompt.build")
			craft.ObjectText =
				text("craft.object.buildCost", { iron = CraftConfig.Recipe.Iron, parts = CraftConfig.Recipe.Parts })
			craft.HoldDuration = CraftConfig.Hold.Build
		elseif carrier then
			craft.Enabled = true
			craft.ActionText = text("craft.prompt.setup")
			craft.ObjectText = text("craft.object.iceSite")
			craft.HoldDuration = CraftConfig.Hold.Setup
		else
			craft.Enabled = false
		end
		packPrompts[site].Enabled = drillSite == site and carrier == nil
	end
end

local function onCraft(site: BasePart, player: Player)
	if store:GetAttribute("DrillBuilt") ~= true then
		local iron, parts = num(store, "Iron"), num(store, "Parts")
		if iron < CraftConfig.Recipe.Iron or parts < CraftConfig.Recipe.Parts then
			notify:FireClient(player, "craft.toast.need", {
				iron = iron,
				needIron = CraftConfig.Recipe.Iron,
				parts = parts,
				needParts = CraftConfig.Recipe.Parts,
			})
			return
		end
		store:SetAttribute("Iron", iron - CraftConfig.Recipe.Iron)
		store:SetAttribute("Parts", parts - CraftConfig.Recipe.Parts)
		store:SetAttribute("DrillBuilt", true)
		placeDrill(site)
		notify:FireAllClients("craft.toast.built")
	elseif carrier == player then
		placeDrill(site)
		carrier = nil
		player:SetAttribute("CarryingDrill", false)
		notify:FireClient(player, "craft.toast.setup")
	elseif carrier then
		notify:FireClient(player, "craft.toast.not_carrying")
	end
	refresh()
end

local function onPack(site: BasePart, player: Player)
	if drillSite ~= site or carrier then
		return
	end
	removeDrill()
	carrier = player
	player:SetAttribute("CarryingDrill", true)
	notify:FireClient(player, "craft.toast.packed")
	refresh()
end

local function bindSite(inst: Instance)
	if not inst:IsA("BasePart") or craftPrompts[inst] then
		return
	end
	local site = inst
	table.insert(sites, site)
	local craft = makePrompt(site, "CraftPrompt", "", "", CraftConfig.Hold.Build)
	craft.Triggered:Connect(function(player)
		onCraft(site, player)
	end)
	craftPrompts[site] = craft
	local pack = makePrompt(
		site,
		"CraftPackPrompt",
		text("craft.prompt.pack"),
		text("craft.object.drill"),
		CraftConfig.Hold.Pack
	)
	pack.KeyboardKeyCode = Enum.KeyCode.F
	pack.UIOffset = Vector2.new(0, 70)
	pack.Triggered:Connect(function(player)
		onPack(site, player)
	end)
	packPrompts[site] = pack
	-- MB_ResourceServer may add its "Dig ice" prompt before or after us
	site.ChildAdded:Connect(function(child)
		if child.Name == CraftConfig.DigPromptName then
			task.defer(refresh)
		end
	end)
	refresh()
end

-- Start ---------------------------------------------------------------------------------------

local function setupPlayer(player: Player)
	bags[player] = {}
	bagFolder(player):ClearAllChildren()
	player:SetAttribute("BagSamples", 0)
	player:SetAttribute("CarryParts", 0)
	player:SetAttribute("CarryingDrill", false)
end

function Crafting.start()
	local existing = ReplicatedStorage:FindFirstChild("CraftNotify")
	if existing and existing:IsA("RemoteEvent") then
		notify = existing
	else
		notify = Instance.new("RemoteEvent")
		notify.Name = "CraftNotify"
		notify.Parent = ReplicatedStorage
	end

	-- shared with MB_ResourceServer, which may create it first
	local state = ReplicatedStorage:FindFirstChild("MB_BaseState")
	if not state then
		state = Instance.new("Folder")
		state.Name = "MB_BaseState"
		state.Parent = ReplicatedStorage
	end
	store = state :: Instance
	for _, key in { "Iron", "Nickel", "Manganese", "Rocks", "Parts" } do
		if store:GetAttribute(key) == nil then
			store:SetAttribute(key, 0)
		end
	end
	store:SetAttribute("DrillBuilt", false)

	local folder = workspace:FindFirstChild("CraftDrills")
	if not (folder and folder:IsA("Folder")) then
		folder = Instance.new("Folder")
		folder.Name = "CraftDrills"
		folder.Parent = workspace
	end
	drillFolder = folder :: Folder
	groundParams.FilterDescendantsInstances = { workspace.Terrain }

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		bags[player] = nil
		if carrier == player then
			-- the drill goes back to where it last stood
			carrier = nil
			if lastSite then
				placeDrill(lastSite)
			end
			refresh()
		end
	end)

	bindSampleFolder("Samples")
	bindSampleFolder("MeteoriteSite")
	bindSalvage()

	for _, inst in CollectionService:GetTagged(CraftConfig.SortStationTag) do
		bindSortStation(inst)
	end
	CollectionService:GetInstanceAddedSignal(CraftConfig.SortStationTag):Connect(bindSortStation)

	for _, inst in CollectionService:GetTagged(CraftConfig.IceSiteTag) do
		bindSite(inst)
	end
	CollectionService:GetInstanceAddedSignal(CraftConfig.IceSiteTag):Connect(bindSite)
end

return Crafting
