-- Space suit. A player puts the suit on (or takes it off) at a suit locker: any
-- BasePart tagged "SuitLocker" gets a hold prompt. Player attribute "SuitOn" = true
-- while wearing it. Airlock pads that lead outside need the suit (see Airlock.luau).
-- If a player is outside without a suit anyway, the crew pulls them back into the
-- airlock after a few seconds (no death: kids 7-12).
-- Looks: white suit colours instead of the avatar's clothes, plus the helmet and
-- backpack models from ServerStorage.SuitParts (built in Studio, not in git).
-- Suit oxygen itself is MB_ResourceServer's job (Player attribute "SuitO2").
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Notice = require(script.Parent.Notice)

local LOCKER_TAG = "SuitLocker"
local HOLD_SECONDS = 1.2
local RESCUE_SECONDS = 3 -- outside without a suit for this long -> back to the airlock
local SUIT_COLOR = Color3.fromRGB(236, 238, 242)
local HELMET_SCALE = 1.65 -- helmet height = head height * this
local PACK_SCALE = 1.05 -- backpack height = torso height * this

local Suit = {}

local outsideSince: { [Player]: number } = {}

local function suitPart(name: string): Model?
	local folder = ServerStorage:FindFirstChild("SuitParts")
	local model = folder and folder:FindFirstChild(name)
	return if model and model:IsA("Model") then model else nil
end

-- Clone a suit piece, size it to `height`, weld it to `to` at `offset`.
local function attach(name: string, to: BasePart, height: number, offset: CFrame, parent: Instance)
	local template = suitPart(name)
	if not template then
		warn(`[suit] ServerStorage.SuitParts.{name} is missing`)
		return
	end
	local piece = template:Clone()
	local _, size = piece:GetBoundingBox()
	if size.Y > 0 then
		piece:ScaleTo(piece:GetScale() * height / size.Y)
	end
	piece:PivotTo(to.CFrame * offset)
	for _, d in piece:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d:SetAttribute("HideInFirstPerson", name == "Helmet")
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = to
			weld.Part1 = d
			weld.Parent = d
		end
	end
	piece.Parent = parent
end

local function dress(character: Model)
	if character:FindFirstChild("SpaceSuit") then
		return
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not head or not torso then
		return
	end

	-- Put the avatar's clothes away and paint the body in suit white.
	local stash = Instance.new("Folder")
	stash.Name = "SuitStash"
	stash.Parent = character
	for _, item in character:GetChildren() do
		if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
			item.Parent = stash
		end
	end
	local colors = character:FindFirstChildOfClass("BodyColors")
	if colors then
		colors:Clone().Parent = stash
		for _, prop in
			{ "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }
		do
			(colors :: any)[prop] = SUIT_COLOR
		end
	end
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") then
			for _, d in accessory:GetDescendants() do
				if d:IsA("BasePart") then
					d:SetAttribute("SuitHiddenTransparency", d.Transparency)
					d.Transparency = 1
				end
			end
		end
	end

	local suit = Instance.new("Model")
	suit.Name = "SpaceSuit"
	suit.Parent = character
	attach("Helmet", head, head.Size.Y * HELMET_SCALE, CFrame.new(0, head.Size.Y * 0.12, 0), suit)
	local packHeight = torso.Size.Y * PACK_SCALE
	attach("Backpack", torso, packHeight, CFrame.new(0, 0.05, torso.Size.Z / 2 + packHeight * 0.22), suit)
end

local function undress(character: Model)
	local suit = character:FindFirstChild("SpaceSuit")
	if suit then
		suit:Destroy()
	end
	local stash = character:FindFirstChild("SuitStash")
	if stash then
		for _, item in stash:GetChildren() do
			if item:IsA("BodyColors") then
				local colors = character:FindFirstChildOfClass("BodyColors")
				if colors then
					colors:Destroy()
				end
			end
			item.Parent = character
		end
		stash:Destroy()
	end
	for _, d in character:GetDescendants() do
		local original = d:GetAttribute("SuitHiddenTransparency")
		if d:IsA("BasePart") and type(original) == "number" then
			d.Transparency = original
			d:SetAttribute("SuitHiddenTransparency", nil)
		end
	end
end

function Suit.isOn(player: Player): boolean
	return player:GetAttribute("SuitOn") == true
end

function Suit.set(player: Player, on: boolean)
	local character = player.Character
	if not character then
		return
	end
	if on then
		dress(character)
	else
		undress(character)
	end
	player:SetAttribute("SuitOn", on)
	Notice.send(player, if on then "suit.on" else "suit.off", "info")
end

local function bindLocker(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("SuitPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SuitPrompt"
	prompt.ActionText = "Suit" -- the client shows the right text in the player's language
	prompt.HoldDuration = HOLD_SECONDS
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		Suit.set(player, not Suit.isOn(player))
	end)
	prompt.Parent = part
end

-- The airlock's inside landing spot (where the crew brings a player back).
local function rescueSpot(): BasePart?
	local base = workspace:FindFirstChild("Base")
	local habitat = base and base:FindFirstChild("Habitat")
	local airlock = habitat and habitat:FindFirstChild("Airlock")
	local spot = airlock and airlock:FindFirstChild("InsideSpot")
	return if spot and spot:IsA("BasePart") then spot else nil
end

local function checkOutside()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		-- "Indoors" comes from Radiation (floor under the player belongs to a Shelter).
		local outside = player:GetAttribute("Indoors") == false
		if outside and not Suit.isOn(player) and player.Character then
			local since = outsideSince[player]
			if not since then
				outsideSince[player] = now
			elseif now - since >= RESCUE_SECONDS then
				outsideSince[player] = nil
				local spot = rescueSpot()
				if spot then
					player.Character:PivotTo(spot.CFrame + Vector3.new(0, 3, 0))
				end
				Notice.send(player, "suit.rescued", "alert")
			end
		else
			outsideSince[player] = nil
		end
	end
end

function Suit.start()
	for _, part in CollectionService:GetTagged(LOCKER_TAG) do
		bindLocker(part)
	end
	CollectionService:GetInstanceAddedSignal(LOCKER_TAG):Connect(bindLocker)

	local function onPlayer(player: Player)
		player:SetAttribute("SuitOn", false)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("SuitOn", false) -- a new character starts without the suit
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		outsideSince[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			checkOutside()
		end
	end)
end

return Suit
