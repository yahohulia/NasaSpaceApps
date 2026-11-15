-- Sparky the rover NPC: drives around the base and talks when a player presses the prompt.
-- World setup lives in Studio:
--   Workspace.Base.Habitat.Sparky      Model with a PrimaryPart (the rover)
--   Workspace.Base.Habitat.SparkyPath  Folder of invisible parts named 1, 2, 3... (route)
-- The client shows the line in the player's language (see client/SparkyClient.luau).
-- Talking is a dialog. Sparky is the crew's radio link to Earth:
--   SparkyTalk:FireServer("chat", text)  a question the player typed
--   SparkyTalk:FireServer("ask", id)     a quick question button (shared/SparkyQuestions)
--   SparkyTalk:FireServer("bye")
-- The question is filtered (TextService), then the AI (Roblox TextGenerator, context in
-- SparkyContext) answers as Mission Control, or says OFFTOPIC and Sparky turns it down at once.
-- A good question "flies" to Earth and back. The delay is today's real Mars -> Earth light
-- time from NASA JPL Horizons (Horizons.luau), counted in game minutes (the game clock is
-- sped up, so the wait is short in real time). If the player is gone by then, Sparky keeps
-- the answer until they talk again.
-- SparkySay:FireClient(player, keyOrText, kind?, extra?, info?) where kind is
--   nil (plain line), "thinking",
--   "sending" (extra = real seconds until the answer, info = { min, date, live, source })
--   or "earth" (Earth's answer; extra = true when the AI wrote it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local Horizons = require(script.Parent.Horizons)
local SparkyContext = require(script.Parent.SparkyContext)
local SparkyQuestions = require(ReplicatedStorage.Shared.SparkyQuestions)
local Strings = require(ReplicatedStorage.Shared.Strings)

local SPEED = 4 -- studs per second
local TURN_SECONDS = 0.6
local WAIT_AT_POINT = 2
local TALK_PAUSE = 5
local TALK_DISTANCE = 16 -- a dialog ends when the player walks further than this
local AI_TIMEOUT = 8 -- seconds to wait for the AI before "no signal"
local AI_MAX_CHARS = 320 -- longer replies are treated as off-topic
local MAX_QUESTION_CHARS = 120
-- Game minutes -> real seconds (a sol is 24 game hours of Config.SolSeconds real seconds).
local function gameMinutesToSeconds(minutes: number): number
	return minutes * 60 * Config.SolSeconds / (24 * 60 * 60)
end

local Sparky = {}

local talkUntil = 0
local faceTarget: Vector3? = nil -- set when a player talks; only the drive loop moves the model
local busy: { [Player]: boolean } = {} -- a question is on its way (one at a time per player)
local mailbox: { [Player]: { text: string, fromAi: boolean } } = {} -- Earth's answer that came while the player was away
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
	Horizons.start() -- today's real signal delay (live request, snapshot fallback)
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
	generator.Temperature = 0.5
	generator.Parent = ServerStorage

	-- The prompt includes today's delay; rebuilt when Horizons' answer arrives.
	local knownText = ""
	local promptFor = ""
	local function refreshPrompt()
		local delay = Horizons.get()
		local minutes = math.round(delay.minutes)
		local key = `{minutes}|{delay.date}`
		if key ~= promptFor then
			promptFor = key
			local systemPrompt, known = SparkyContext.build(minutes, delay.date)
			generator.SystemPrompt = systemPrompt
			knownText = known
		end
	end
	refreshPrompt()

	-- Solar conjunction: EventDirector's "Conjunction" event sets MB_BaseState@CommsOffline
	-- (the Sun is between Mars and Earth, no radio gets through).
	local function commsOffline(): boolean
		local state = ReplicatedStorage:FindFirstChild("MB_BaseState")
		return state ~= nil and state:GetAttribute("CommsOffline") == true
	end

	-- Filters text for this player. Returns nil when the filter fails or hides words.
	local function filter(player: Player, text: string): string?
		local result: string? = nil
		pcall(function()
			local f = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
			result = f:GetNonChatStringForUserAsync(player.UserId)
		end)
		if not result or string.find(result, "#", 1, true) then
			return nil
		end
		return result
	end

	-- Every number in the reply must appear in the known text (rule 6: no invented numbers).
	local function numbersKnown(text: string): boolean
		for number in string.gmatch(text, "%d+") do
			if not string.find(knownText, number, 1, true) then
				return false
			end
		end
		return true
	end

	-- Asks the AI. Returns ("ok", text), "offtopic", "unsure" (reply not trusted) or "fail".
	local function ask(player: Player, question: string): (string, string?)
		refreshPrompt()
		local ok, result = pcall(function()
			return generator:GenerateTextAsync({ UserPrompt = question, MaxTokens = 120 })
		end)
		if not ok or typeof(result) ~= "table" or typeof(result.GeneratedText) ~= "string" then
			warn("[Sparky] AI failed:", result)
			return "fail"
		end
		-- Roblox puts this notice in front of every reply; the dialog shows it as a small note.
		local text = string.gsub(
			result.GeneratedText,
			"^%s*Content generated by artificial intelligence, may make mistakes%.%s*",
			""
		)
		text = string.gsub(text, "^%s+", "")
		text = string.gsub(text, "%s+$", "")
		if text == "" or string.find(string.upper(text), "OFFTOPIC", 1, true) then
			return "offtopic"
		end
		if #text > AI_MAX_CHARS or not numbersKnown(text) then
			return "unsure"
		end
		local clean = filter(player, text)
		if not clean then
			return "unsure"
		end
		return "ok", clean
	end

	-- Sends Earth's answer now, or keeps it until the player talks to Sparky again.
	-- fromAi: show the "made by AI" note (checked lines go without it).
	local function deliver(player: Player, text: string, fromAi: boolean)
		if talking[player] and player.Parent then
			say:FireClient(player, text, "earth", fromAi)
		else
			mailbox[player] = { text = text, fromAi = fromAi }
		end
	end

	-- fallback: checked i18n answer key for quick buttons, used when the AI fails.
	local function handleQuestion(player: Player, question: string, fallback: string?)
		if busy[player] then
			say:FireClient(player, "sparky.chat.busy")
			return
		end
		if commsOffline() then
			say:FireClient(player, "sparky.chat.nosignal")
			return
		end
		busy[player] = true
		talkUntil = os.clock() + TALK_PAUSE
		say:FireClient(player, "sparky.thinking", "thinking")

		local status: string, reply: string? = "fail", nil
		local lang = Strings.langFromLocale(player.LocaleId)
		if fallback and lang ~= "en" then
			-- The AI writes Ukrainian badly: quick questions get the checked line instead.
			status, reply = "ok", Strings.get(fallback, lang)
		else
			local done = false
			task.spawn(function()
				status, reply = ask(player, question)
				done = true
			end)
			local deadline = os.clock() + AI_TIMEOUT
			while not done and os.clock() < deadline do
				task.wait(0.1)
			end
		end
		if status == "offtopic" then
			busy[player] = nil
			say:FireClient(player, "sparky.chat.offtopic")
			return
		end
		local answer: string? = reply
		if status ~= "ok" then
			answer = if fallback then Strings.get(fallback, lang) else nil
		end
		if not answer then
			busy[player] = nil
			say:FireClient(player, if status == "unsure" then "sparky.chat.unsure" else "sparky.chat.error")
			return
		end
		local fromAi = status == "ok" and not (fallback and lang ~= "en")
		-- There and back: the same light time each way.
		local delay = Horizons.get()
		local roundTrip = gameMinutesToSeconds(2 * delay.minutes)
		say:FireClient(player, "sparky.chat.sending", "sending", roundTrip, {
			min = math.round(delay.minutes),
			date = delay.date,
			live = delay.live,
			source = delay.source,
		})
		task.delay(roundTrip, function()
			-- A conjunction started while the answer was on its way: it gets through when it ends.
			while commsOffline() and player.Parent do
				task.wait(1)
			end
			busy[player] = nil
			if player.Parent then
				deliver(player, answer, fromAi)
			end
		end)
	end

	prompt.Triggered:Connect(function(player)
		talking[player] = true
		local root = playerRoot(player)
		if root then
			faceTarget = root.Position
		end
		talkUntil = os.clock() + TALK_PAUSE
		local mail = mailbox[player]
		if mail then
			mailbox[player] = nil
			say:FireClient(player, mail.text, "earth", mail.fromAi)
		else
			say:FireClient(player, SparkyQuestions.greeting)
		end
	end)

	talk.OnServerEvent:Connect(function(player, action: unknown, value: unknown)
		if not talking[player] then
			-- The dialog can also be opened by an event line (EventDirector -> SparkySay for everyone):
			-- a player standing next to Sparky may ask from there too.
			local root = playerRoot(player)
			if
				action == "bye" or not (root and (root.Position - rover:GetPivot().Position).Magnitude <= TALK_DISTANCE)
			then
				return
			end
			talking[player] = true
		end
		if action == "chat" and typeof(value) == "string" then
			local text = string.sub((string.gsub(value, "^%s+", "")), 1, MAX_QUESTION_CHARS)
			if text == "" then
				return
			end
			if not filter(player, text) then
				say:FireClient(player, "sparky.chat.filtered")
				return
			end
			handleQuestion(player, text)
		elseif action == "ask" and typeof(value) == "string" then
			local q = SparkyQuestions.byId[value]
			if q then
				handleQuestion(player, Strings.get(q.question, Strings.langFromLocale(player.LocaleId)), q.answer)
			end
		elseif action == "bye" then
			talking[player] = nil
			talkUntil = math.min(talkUntil, os.clock() + 1)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		mailbox[player] = nil
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
