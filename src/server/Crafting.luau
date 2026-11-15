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
-- Remotes: CraftNotify (toasts), CraftSort (the sorting mini game, see "Sorting table").
-- Shared store, attributes on ReplicatedStorage.MB_BaseState: Iron, Rocks, Parts, DrillBuilt.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CraftConfig = require(ReplicatedStorage.Shared.CraftConfig)
local Strings = require(ReplicatedStorage.Shared.Strings)

local Crafting = {}

-- One entry per picked sample, in pickup order. key = SampleKind (or "Large"), view = its copy
-- in Player.SampleBag that the client shows.
type BagItem = { key: string, view: Instance }
type Bag = { BagItem }

-- An open sorting mini game: the player puts samples one by one into a box.
type SortSession = {
	station: BasePart,
	lockUntil: number, -- after a wrong box the player waits a little (costs time)
	got: { [string]: number }, -- metals sorted in this session, for the summary
	rocks: number,
	parts: number,
}

local notify: RemoteEvent
local sortRemote: RemoteEvent
local store: Instance
local bags: { [Player]: Bag } = {}
local sessions: { [Player]: SortSession } = {}
local pickedOnce: { [Player]: boolean } = {}

-- The first sample a player picks up counts for the Studio scripts too: MB_Tutorial step
-- "Collect a rock sample" waits for MB_Notify "sample_got", MB_Achievements gives "FirstSample".
-- (Their own science rocks, Workspace.MB_Samples, were removed on 2026-11-15.)
local function firstPickup(player: Player)
	if pickedOnce[player] then
		return
	end
	pickedOnce[player] = true
	local mbNotify = ReplicatedStorage:FindFirstChild("MB_Notify")
	if mbNotify and mbNotify:IsA("RemoteEvent") then
		mbNotify:FireClient(player, "sample_got")
	end
	local award = ServerStorage:FindFirstChild("MB_AwardAchievement")
	if award and award:IsA("BindableEvent") then
		award:Fire(player, "FirstSample")
	end
end

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

local function putInBagView(player: Player, sample: Instance): Instance
	local copy = sample:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("ProximityPrompt") or d:IsA("ParticleEmitter") or d:IsA("Attachment") or d:IsA("Light") then
			d:Destroy()
		end
	end
	copy.Parent = bagFolder(player)
	return copy
end

-- Tells the mission director (MissionDirector) that a rock sample was picked up (any rock or meteorite).
local function sampleCollected(player: Player)
	local event = ServerStorage:FindFirstChild("MB_ObjectiveDone")
	if event and event:IsA("BindableEvent") then
		event:Fire(player, "sample")
	end
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
		local n = if bag then #bag else 0
		-- seed packets and harvest (Player.CropBag, Crops.luau) share the same bag places
		local cropBag = player:FindFirstChild("CropBag")
		local crops = if cropBag then #cropBag:GetChildren() else 0
		if not bag or n + crops >= CraftConfig.BagSize then
			notify:FireClient(player, "craft.toast.bag_full")
			return
		end
		sample:SetAttribute("Collected", true)
		table.insert(bag, { key = key, view = putInBagView(player, sample) })
		player:SetAttribute("BagSamples", n + 1)
		sample:Destroy()
		sampleCollected(player)
		notify:FireClient(player, "craft.toast.picked", { n = n + 1 + crops, max = CraftConfig.BagSize })
		firstPickup(player)
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

-- Sorting table: a mini game ----------------------------------------------------------------
-- Using the table puts carried spare parts into the store, then opens the mini game on the
-- client: it shows the first sample in the bag, the player picks a box. Right box: its metals
-- go to the store. Wrong box: a hint, a short wait, and the sample stays to try again.
-- Server -> client (CraftSort): "show" {item, left, kind?} · "wrong" {kind, wait} · "close" {kind?}
-- Client -> server: "box", boxId · "stop".

local boxOf: { [string]: string } = {}
for _, boxId in CraftConfig.SortBoxOrder do
	for _, kind in CraftConfig.SortBoxes[boxId] do
		boxOf[kind] = boxId
	end
end

local function nearStation(player: Player, station: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil
		and root:IsA("BasePart")
		and (root.Position - station.Position).Magnitude <= CraftConfig.SortCloseDistance
end

local function showNext(player: Player, rightKind: string?)
	local first = (bags[player] or {})[1]
	sortRemote:FireClient(player, "show", {
		item = if first then first.view else nil,
		left = #(bags[player] or {}),
		kind = rightKind, -- the sample just sorted right, for the "Right!" line
	})
end

-- Closes the mini game and shows what this visit to the table gave.
local function endSession(player: Player, closeKind: string?)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	sortRemote:FireClient(player, "close", { kind = closeKind })
	notify:FireClient(player, "craft.toast.sorted", {
		iron = session.got.Iron or 0,
		nickel = session.got.Nickel or 0,
		manganese = session.got.Manganese or 0,
		rocks = session.rocks,
		parts = session.parts,
	})
end

local function openSort(player: Player, station: BasePart)
	local bag = bags[player] or {}
	local parts = num(player, "CarryParts")
	if #bag == 0 and parts <= 0 then
		notify:FireClient(player, "craft.toast.nothing")
		return
	end
	local session = sessions[player]
	if not session then
		local got: { [string]: number } = {}
		for _, metal in CraftConfig.Metals do
			got[metal] = 0
		end
		local fresh: SortSession = { station = station, lockUntil = 0, got = got, rocks = 0, parts = 0 }
		sessions[player] = fresh
		session = fresh
	end
	assert(session, "session")
	session.station = station
	-- spare parts are easy to tell apart: they go straight to the store
	if parts > 0 then
		store:SetAttribute("Parts", num(store, "Parts") + parts)
		player:SetAttribute("CarryParts", 0)
		session.parts += parts
	end
	if #bag == 0 then
		endSession(player, nil)
	else
		showNext(player, nil)
	end
end

local function onSortChoice(player: Player, action: unknown, boxId: unknown)
	local session = sessions[player]
	if not session then
		return
	end
	if action == "stop" or not nearStation(player, session.station) then
		endSession(player, nil)
		return
	end
	if action ~= "box" or typeof(boxId) ~= "string" or CraftConfig.SortBoxes[boxId] == nil then
		return
	end
	if os.clock() < session.lockUntil then
		return
	end
	local bag = bags[player] or {}
	local item = bag[1]
	if not item then
		endSession(player, nil)
		return
	end
	if boxOf[item.key] ~= boxId then
		session.lockUntil = os.clock() + CraftConfig.SortWrongWait
		sortRemote:FireClient(player, "wrong", { kind = item.key, wait = CraftConfig.SortWrongWait })
		return
	end
	-- right box: its metals go to the shared store at once
	for metal, amount in CraftConfig.Yield[item.key] or {} do
		store:SetAttribute(metal, num(store, metal) + amount)
		session.got[metal] = (session.got[metal] or 0) + amount
	end
	if item.key == "Rock" then
		store:SetAttribute("Rocks", num(store, "Rocks") + 1)
		session.rocks += 1
	end
	table.remove(bag, 1)
	item.view:Destroy()
	player:SetAttribute("BagSamples", #bag)
	if #bag == 0 then
		endSession(player, item.key)
	else
		showNext(player, item.key)
	end
end

local function bindSortStation(inst: Instance)
	if not inst:IsA("BasePart") or inst:FindFirstChild("CraftPrompt") then
		return
	end
	local station = inst
	local prompt = makePrompt(
		station,
		"CraftPrompt",
		text("craft.prompt.sort"),
		text("craft.object.sortTable"),
		CraftConfig.Hold.Sort
	)
	prompt.Triggered:Connect(function(player)
		openSort(player, station)
	end)
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
			local cost: { [string]: number } = {}
			for _, key in CraftConfig.RecipeOrder do
				cost[string.lower(key)] = CraftConfig.Recipe[key] or 0
			end
			craft.ObjectText = text("craft.object.buildCost", cost)
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
		-- vars for the message: iron = what we have, needIron = what the recipe asks, etc.
		local vars: { [string]: number } = {}
		local enough = true
		for _, key in CraftConfig.RecipeOrder do
			local have, need = num(store, key), CraftConfig.Recipe[key] or 0
			vars[string.lower(key)] = have
			vars["need" .. key] = need
			if have < need then
				enough = false
			end
		end
		if not enough then
			notify:FireClient(player, "craft.toast.need", vars)
			return
		end
		for _, key in CraftConfig.RecipeOrder do
			store:SetAttribute(key, num(store, key) - (CraftConfig.Recipe[key] or 0))
		end
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
		sessions[player] = nil
		pickedOnce[player] = nil
		if carrier == player then
			-- the drill goes back to where it last stood
			carrier = nil
			if lastSite then
				placeDrill(lastSite)
			end
			refresh()
		end
	end)

	local sortExisting = ReplicatedStorage:FindFirstChild("CraftSort")
	if sortExisting and sortExisting:IsA("RemoteEvent") then
		sortRemote = sortExisting
	else
		sortRemote = Instance.new("RemoteEvent")
		sortRemote.Name = "CraftSort"
		sortRemote.Parent = ReplicatedStorage
	end
	sortRemote.OnServerEvent:Connect(onSortChoice)
	-- the mini game closes when the player walks away from the table
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, session in sessions do
				if not nearStation(player, session.station) then
					endSession(player, nil)
				end
			end
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
