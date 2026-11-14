-- Sparky the rover NPC: drives around the base and talks when a player presses the prompt.
-- World setup lives in Studio:
--   Workspace.Base.Habitat.Sparky      Model with a PrimaryPart (the rover)
--   Workspace.Base.Habitat.SparkyPath  Folder of invisible parts named 1, 2, 3... (route)
-- The client shows the line in the player's language (see client/SparkyClient.luau).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SparkyLines = require(ReplicatedStorage.Shared.SparkyLines)

local SPEED = 4 -- studs per second
local TURN_SECONDS = 0.6
local WAIT_AT_POINT = 2
local TALK_PAUSE = 5

local Sparky = {}

local talkUntil = 0
local faceTarget: Vector3? = nil -- set when a player talks; only the drive loop moves the model
local nextLine: { [Player]: number } = {}

local function getRoute(folder: Instance): { Vector3 }
	local points = {}
	for _, child in folder:GetChildren() do
		local index = tonumber(child.Name)
		if index and child:IsA("BasePart") then
			table.insert(points, { index = index, pos = child.Position })
		end
	end
	table.sort(points, function(a, b)
		return a.index < b.index
	end)
	local route = {}
	for _, p in points do
		table.insert(route, p.pos)
	end
	return route
end

local function flatLook(from: Vector3, to: Vector3): CFrame
	local target = Vector3.new(to.X, from.Y, to.Z)
	if (target - from).Magnitude < 0.01 then
		return CFrame.new(from)
	end
	return CFrame.lookAt(from, target)
end

local function turnTo(model: Model, goal: CFrame)
	local start = model:GetPivot()
	local t = 0
	while t < TURN_SECONDS do
		t += RunService.Heartbeat:Wait()
		model:PivotTo(start:Lerp(goal, math.min(t / TURN_SECONDS, 1)))
	end
end

local function waitWhileTalking(model: Model)
	while os.clock() < talkUntil do
		local target = faceTarget
		if target then
			faceTarget = nil
			local pos = model:GetPivot().Position
			turnTo(model, flatLook(pos, target))
		else
			task.wait(0.1)
		end
	end
end

local function driveTo(model: Model, point: Vector3)
	local pivot = model:GetPivot()
	local goal = Vector3.new(point.X, pivot.Position.Y, point.Z)
	turnTo(model, flatLook(pivot.Position, goal))
	while true do
		waitWhileTalking(model)
		local pos = model:GetPivot().Position
		local offset = goal - pos
		local dt = RunService.Heartbeat:Wait()
		local step = SPEED * dt
		if offset.Magnitude <= step then
			model:PivotTo(flatLook(goal, goal + model:GetPivot().LookVector))
			return
		end
		model:PivotTo(flatLook(pos + offset.Unit * step, goal))
	end
end

function Sparky.start()
	local habitat = workspace:FindFirstChild("Base") and workspace.Base:FindFirstChild("Habitat")
	local model = habitat and habitat:FindFirstChild("Sparky")
	local pathFolder = habitat and habitat:FindFirstChild("SparkyPath")
	if not (model and model:IsA("Model") and model.PrimaryPart and pathFolder) then
		warn("[Sparky] Workspace.Base.Habitat.Sparky (with PrimaryPart) or SparkyPath not found")
		return
	end
	local rover: Model = model

	local say = Instance.new("RemoteEvent")
	say.Name = "SparkySay"
	say.Parent = ReplicatedStorage

	local prompt = rover.PrimaryPart:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk" -- the client replaces it with the player's language
	prompt.ObjectText = "Sparky"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = rover.PrimaryPart

	prompt.Triggered:Connect(function(player)
		local index = nextLine[player] or 1
		nextLine[player] = index % #SparkyLines + 1
		talkUntil = os.clock() + TALK_PAUSE
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			faceTarget = root.Position
		end
		say:FireClient(player, SparkyLines[index])
	end)

	Players.PlayerRemoving:Connect(function(player)
		nextLine[player] = nil
	end)

	local route = getRoute(pathFolder)
	if #route < 2 then
		warn("[Sparky] SparkyPath needs at least 2 points")
		return
	end
	task.spawn(function()
		while rover.Parent do
			for _, point in route do
				driveTo(rover, point)
				local resume = os.clock() + WAIT_AT_POINT
				while os.clock() < resume do
					waitWhileTalking(rover)
					task.wait(0.1)
				end
				waitWhileTalking(rover)
			end
		end
	end)
end

return Sparky
