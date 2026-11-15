-- MB_Achievements (ServerScriptService): in-game achievements, given once per player.
--   Welcome     - joining the game.
--   FirstSample - picking up the first rock sample outside. The team's Crafting script adds 1 to the
--                 player attribute "BagSamples" on every pickup; we watch that attribute.
-- Unlocked achievements are kept in a DataStore (if Studio/API access allows, otherwise for this session).
-- Each achievement can also give a real Roblox badge: put its id in MB_Config.Achievements.<Id>.BadgeId.
-- Other server scripts can award one with ServerStorage.MB_AwardAchievement:Fire(player, "Id").
-- The popup is drawn by MB_AchievementToast on the client (RemoteEvent ReplicatedStorage.MB_Achievement).
-- Copy of the script that lives in the team place (studio/MB in the repo).
local BadgeService = game:GetService("BadgeService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("MB_Config"))
local A = Config.Achievements

local remote = ReplicatedStorage:FindFirstChild("MB_Achievement")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "MB_Achievement"
	remote.Parent = ReplicatedStorage
end
local awardEvent = ServerStorage:FindFirstChild("MB_AwardAchievement")
if not awardEvent then
	awardEvent = Instance.new("BindableEvent")
	awardEvent.Name = "MB_AwardAchievement"
	awardEvent.Parent = ServerStorage
end

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("MB_Achievements_v1")
	end)
	if ok then
		store = result
	end
end

local unlocked: { [Player]: { [string]: boolean } } = {}

local function key(player: Player): string
	return "u" .. player.UserId
end

local function load(player: Player): { [string]: boolean }
	local set = {}
	if store then
		local ok, data = pcall(function()
			return (store :: DataStore):GetAsync(key(player))
		end)
		if ok and typeof(data) == "table" then
			for id, v in data do
				if v == true then
					set[id] = true
				end
			end
		elseif not ok then
			warn(
				"[MB_Achievements] DataStore not available, achievements last for this session only: " .. tostring(data)
			)
			store = nil
		end
	end
	return set
end

local function save(player: Player, id: string)
	if not store then
		return
	end
	pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function(old)
			local data = if typeof(old) == "table" then old else {}
			data[id] = true
			return data
		end)
	end)
end

local function award(player: Player, id: string, title: string?, text: string?)
	-- Event achievements (MB_EventDirector) come with their own title and text.
	local def = A[id] or (if title then { Title = title, Text = text or "", BadgeId = 0 } else nil)
	local set = unlocked[player]
	if not (def and set) or set[id] then
		return
	end
	set[id] = true
	remote:FireClient(player, id, def.Title, def.Text)
	if def.BadgeId and def.BadgeId > 0 then
		task.spawn(pcall, function()
			BadgeService:AwardBadge(player.UserId, def.BadgeId)
		end)
	end
	task.spawn(save, player, id)
end
awardEvent.Event:Connect(award)

local function setup(player: Player)
	unlocked[player] = load(player)

	-- Rock samples: BagSamples goes up by one on every pickup.
	local last = player:GetAttribute("BagSamples")
	player:GetAttributeChangedSignal("BagSamples"):Connect(function()
		local now = player:GetAttribute("BagSamples")
		if typeof(now) == "number" and now > (if typeof(last) == "number" then last else 0) then
			award(player, "FirstSample")
		end
		last = now
	end)

	-- Welcome: wait a moment so the HUD is ready to show the popup.
	task.delay(A.WelcomeDelay or 4, function()
		if player.Parent then
			award(player, "Welcome")
		end
	end)
end

Players.PlayerAdded:Connect(setup)
for _, player in Players:GetPlayers() do
	task.spawn(setup, player)
end
Players.PlayerRemoving:Connect(function(player)
	unlocked[player] = nil
end)
