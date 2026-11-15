--!strict
-- Sliding doors. Each door is a Model tagged "SlidingDoor", built in Studio
-- (Workspace.MarsBaseFixes.RoomDoors / AirlockDoors): a frame, a "Lamp" and leaves (BaseParts with a
-- Vector3 attribute "Slide" = how far the leaf moves when it opens, in world space).
-- The door opens when any character comes close to its pivot and closes when everyone
-- has left. Every client animates the doors on its own, and the leaves never collide,
-- so nobody can get stuck in a closing door.
-- Optional model attributes:
--   OpenDistance / CloseDistance (numbers) - override the defaults below.
--   Requires = "Suit" | "NoSuit" - airlock doors: only a player wearing the space suit
--     (and not kept inside by the medic) / only a player without the suit opens it.
--     The model's invisible "Barrier" part then blocks the local player until they
--     meet the rule (the client moves its own character, so a local CanCollide is enough).
--     The server (Airlock) tells the player why the door stays shut.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local TAG = "SlidingDoor"
local OPEN_DISTANCE = 11 -- studs from the door centre: open when someone is closer
local CLOSE_DISTANCE = 13 -- studs: close when everyone is farther (no flapping at the edge)
local CHECK_SECONDS = 0.1
local OPEN_TWEEN = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local LAMP_OPEN = Color3.fromRGB(90, 230, 120)
local LAMP_CLOSED = Color3.fromRGB(255, 80, 70)

-- closed: where each leaf sits when the door is shut (the server never moves the leaves,
-- so the first CFrame this client sees is the closed one).
type Door = { model: Model, closed: { [BasePart]: CFrame }, isOpen: boolean }

local DoorClient = {}

local doors: { [Model]: Door } = {}

local function bind(instance: Instance)
	if instance:IsA("Model") and not doors[instance] then
		doors[instance] = { model = instance, closed = {}, isOpen = false }
	end
end

-- With StreamingEnabled the parts of a door can arrive after the model, so the leaves
-- and the lamp are looked up every time the door changes, not once at start.
local function setOpen(door: Door, open: boolean)
	if door.isOpen == open then
		return
	end
	door.isOpen = open
	local info = if open then OPEN_TWEEN else CLOSE_TWEEN
	for _, child in door.model:GetChildren() do
		local slide = child:GetAttribute("Slide")
		if child:IsA("BasePart") and typeof(slide) == "Vector3" then
			local closed = door.closed[child]
			if not closed then
				closed = child.CFrame
				door.closed[child] = closed
			end
			TweenService:Create(child, info, { CFrame = if open then closed + slide else closed }):Play()
		end
	end
	local lamp = door.model:FindFirstChild("Lamp")
	if lamp and lamp:IsA("BasePart") then
		lamp.Color = if open then LAMP_OPEN else LAMP_CLOSED
	end
end

-- May this player pass a door with the given "Requires" rule?
local function allowed(player: Player, rule: any): boolean
	local suitOn = player:GetAttribute("SuitOn") == true
	if rule == "Suit" then
		return suitOn and player:GetAttribute("OutsideBlocked") ~= true
	elseif rule == "NoSuit" then
		return not suitOn
	end
	return true
end

local function number(model: Model, name: string, default: number): number
	local value = model:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

-- Distance (ignoring height) from the door centre to the closest player who may pass.
local function closestAllowed(door: Door, characters: { [Player]: Vector3 }): number
	local centre = door.model:GetPivot().Position
	local rule = door.model:GetAttribute("Requires")
	local best = math.huge
	for player, position in characters do
		if allowed(player, rule) then
			local offset = position - centre
			best = math.min(best, Vector3.new(offset.X, 0, offset.Z).Magnitude)
		end
	end
	return best
end

function DoorClient.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		bind(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(bind)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
		doors[instance :: Model] = nil
	end)

	local localPlayer = Players.LocalPlayer
	while true do
		local characters: { [Player]: Vector3 } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				characters[player] = root.Position
			end
		end
		for _, door in doors do
			local model = door.model
			local distance = closestAllowed(door, characters)
			if distance < number(model, "OpenDistance", OPEN_DISTANCE) then
				setOpen(door, true)
			elseif distance > number(model, "CloseDistance", CLOSE_DISTANCE) then
				setOpen(door, false)
			end
			local barrier = model:FindFirstChild("Barrier")
			if barrier and barrier:IsA("BasePart") then
				barrier.CanCollide = not allowed(localPlayer, model:GetAttribute("Requires"))
			end
		end
		task.wait(CHECK_SECONDS)
	end
end

return DoorClient
