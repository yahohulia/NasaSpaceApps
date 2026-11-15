-- Sparky the rover NPC: drives around the base and talks when a player presses the prompt.
-- World setup lives in Studio:
--   Workspace.Base.Habitat.Sparky      Model with a PrimaryPart (the rover)
--   Workspace.Base.Habitat.SparkyPath  Folder of invisible parts named 1, 2, 3... (route)
-- The client shows the line in the player's language (see client/SparkyClient.luau).
-- Talking is a dialog: the prompt opens it with a greeting, the player picks a question
-- (SparkyTalk:FireServer("ask", id), see shared/SparkyQuestions) and ends it with "bye".
-- Sparky waits while any dialog is open.
-- Answers: English players get the checked answer reworded by Roblox's TextGenerator (AI);
-- the AI may use only that answer as its fact. Ukrainian players, and any AI failure,
-- timeout or suspicious reply, get the checked i18n answer itself.
-- SparkySay:FireClient(player, keyOrText, kind?) where kind is nil, "thinking" or "ai".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")

local SparkyQuestions = require(ReplicatedStorage.Shared.SparkyQuestions)
local Strings = require(ReplicatedStorage.Shared.Strings)

local SPEED = 4 -- studs per second
local TURN_SECONDS = 0.6
local WAIT_AT_POINT = 2
local TALK_PAUSE = 5
local TALK_DISTANCE = 16 -- a dialog ends when the player walks further than this
local AI_TIMEOUT = 6 -- seconds; after that the checked answer is shown instead
local AI_MAX_CHARS = 220 -- longer replies are treated as off-topic

local SYSTEM_PROMPT = table.concat({
	"You are Sparky, a cheerful little rover on a Mars base.",
	"You talk to kids aged 7 to 12.",
	"Answer the question in one or two short sentences with simple words.",
	"Use ONLY the fact you are given. Do not add other facts, numbers, dates or names.",
	"Never say anything scary. Do not ask questions back.",
}, " ")

local Sparky = {}

local talkUntil = 0
local faceTarget: Vector3? = nil -- set when a player talks; only the drive loop moves the model
local asking: { [Player]: number } = {} -- id of the player's current question (drops stale replies)
local busy: { [Player]: boolean } = {} -- an AI reply is on its way (one at a time per player)
local talking: { [Player]: boolean } = {} -- players with the dialog open
local activeRover: Model? = nil

local function playerRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- True while someone near Sparky has the dialog open (drops players who walked away).
local function anyoneTalking(): boolean
	local model = activeRover
	for player in talking do
		local root = playerRoot(player)
		if not (model and root and (root.Position - model:GetPivot().Position).Magnitude <= TALK_DISTANCE) then
			talking[player] = nil
		end
	end
	return next(talking) ~= nil
end

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
	while os.clock() < talkUntil or anyoneTalking() do
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
	activeRover = model
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

	local talk = Instance.new("RemoteEvent")
	talk.Name = "SparkyTalk"
	talk.Parent = ReplicatedStorage

	local generator = Instance.new("TextGenerator")
	generator.Name = "SparkyBrain"
	generator.SystemPrompt = SYSTEM_PROMPT
	generator.Temperature = 0.7
	generator.Parent = ServerStorage

	-- Rewords the checked fact with the AI. Returns nil when the reply cannot be trusted.
	local function aiAnswer(player: Player, question: string, fact: string): string?
		local ok, result = pcall(function()
			return generator:GenerateTextAsync({
				UserPrompt = "Fact: " .. fact .. "\nQuestion: " .. question,
				MaxTokens = 80,
			})
		end)
		if not ok or typeof(result) ~= "table" or typeof(result.GeneratedText) ~= "string" then
			warn("[Sparky] AI failed:", result)
			return nil
		end
		-- Roblox puts this notice in front of every reply; the dialog shows it as a small note.
		local text = string.gsub(
			result.GeneratedText,
			"^%s*Content generated by artificial intelligence, may make mistakes%.%s*",
			""
		)
		text = string.gsub(text, "^%s+", "")
		text = string.gsub(text, "%s+$", "")
		-- New numbers would be invented facts (rule 6): the facts have none.
		if text == "" or #text > AI_MAX_CHARS or string.find(text, "%d") then
			return nil
		end
		local filtered: string? = nil
		pcall(function()
			local filterResult = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
			filtered = filterResult:GetNonChatStringForUserAsync(player.UserId)
		end)
		if not filtered or string.find(filtered, "#", 1, true) then
			return nil -- filter failed or hid words
		end
		return filtered
	end

	local function answer(player: Player, id: string)
		local q = SparkyQuestions.byId[id]
		if not q or busy[player] then
			return
		end
		local token = (asking[player] or 0) + 1
		asking[player] = token
		talkUntil = os.clock() + TALK_PAUSE
		if Strings.langFromLocale(player.LocaleId) ~= "en" then
			say:FireClient(player, q.answer)
			return
		end
		say:FireClient(player, "sparky.thinking", "thinking")
		busy[player] = true
		local reply: string? = nil
		local done = false
		task.spawn(function()
			reply = aiAnswer(player, Strings.get(q.question, "en"), Strings.get(q.answer, "en"))
			done = true
		end)
		local deadline = os.clock() + AI_TIMEOUT
		while not done and os.clock() < deadline do
			task.wait(0.1)
		end
		busy[player] = nil
		if asking[player] ~= token or not talking[player] then
			return -- the player asked something else or left
		end
		if reply then
			say:FireClient(player, reply, "ai")
		else
			say:FireClient(player, q.answer)
		end
	end

	prompt.Triggered:Connect(function(player)
		talking[player] = true
		local root = playerRoot(player)
		if root then
			faceTarget = root.Position
		end
		talkUntil = os.clock() + TALK_PAUSE
		say:FireClient(player, SparkyQuestions.greeting)
	end)

	talk.OnServerEvent:Connect(function(player, action: unknown, id: unknown)
		if not talking[player] then
			return
		end
		if action == "ask" and typeof(id) == "string" then
			answer(player, id)
		elseif action == "bye" then
			talking[player] = nil
			asking[player] = nil
			talkUntil = math.min(talkUntil, os.clock() + 1)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		asking[player] = nil
		busy[player] = nil
		talking[player] = nil
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
