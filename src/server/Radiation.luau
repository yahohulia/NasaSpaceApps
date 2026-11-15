-- Personal radiation dose. Outside the base a player's dose (Player attribute "Dose", μGy)
-- grows at the real Mars surface rate from Curiosity RAD, times the real storm ratio
-- during a radiation storm. Inside a building tagged "Shelter" it does not grow
-- (a game simplification). At the mission limit the medic keeps the player inside:
-- Player attribute "OutsideBlocked" = true (checked by Airlock).
-- "Inside" = MB_ResourceServer's "IsInside" (its MB_InsideZone boxes) when present,
-- else the solid floor under the player belongs to a Shelter-tagged model.
-- The result is Player attribute "Indoors" (Suit uses it too).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataMapping = require(ReplicatedStorage.Shared.DataMapping)
local RadiationModel = require(ReplicatedStorage.Shared.RadiationModel)
local Notice = require(script.Parent.Notice)
local Weather = require(script.Parent.Weather)

local radlab = require(script.Parent.data["radlab-2024-05"]) :: any

local SHELTER_TAG = "Shelter"
local FLOOR_PROBE = 12 -- studs to look down for a floor

local Radiation = {}

-- Real usual rate on the Mars surface (μGy/h) and the mission limit in μGy.
local baseRate = RadiationModel.medianRate(radlab.rows)
local limit = baseRate * 24 * DataMapping.radiation.limitMarsDays

local lastLevel: { [Player]: RadiationModel.Level } = {}

local function isIndoors(root: BasePart, params: RaycastParams): boolean
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -FLOOR_PROBE, 0), params)
	if not hit then
		return false
	end
	for _, shelter in CollectionService:GetTagged(SHELTER_TAG) do
		if hit.Instance:IsDescendantOf(shelter) then
			return true
		end
	end
	return false
end

-- Storm multiplier: the real peak/median ratio while a radiation storm is on, else 1.
local function stormRatio(): number
	local payload = Weather.current()
	if payload and payload.id == "radiation" and type(payload.vars.times) == "number" then
		return payload.vars.times :: number
	end
	return 1
end

local function announce(player: Player, level: RadiationModel.Level)
	if lastLevel[player] == level then
		return
	end
	local previous = lastLevel[player]
	lastLevel[player] = level
	if previous == nil or level == "ok" then
		return
	end
	local kind = if level == "rising" then "warn" else "alert"
	Notice.send(player, `radiation.level.{level}`, kind)
end

local function tick(dt: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true -- only real floors, not invisible pads or markers
	local characters = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	params.FilterDescendantsInstances = characters

	local ratio = stormRatio()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			-- MB_ResourceServer's zones (Player attribute "IsInside") know the base best;
			-- the floor check is the fallback when that system is not running.
			local mbInside = player:GetAttribute("IsInside")
			local indoors = if type(mbInside) == "boolean" then mbInside else isIndoors(root, params)
			player:SetAttribute("Indoors", indoors)
			local dose = (player:GetAttribute("Dose") :: number?) or 0
			if not indoors then
				dose += RadiationModel.gain(baseRate, ratio, DataMapping.radiation.speedUp, dt)
				player:SetAttribute("Dose", dose)
			end
			local level = RadiationModel.level(dose, limit)
			player:SetAttribute("OutsideBlocked", level == "limit")
			announce(player, level)
		end
	end
end

function Radiation.start()
	-- Shared numbers for the client HUD (real base rate, mission limit in μGy).
	local info = Instance.new("Configuration")
	info.Name = "RadiationInfo"
	info:SetAttribute("BaseRate", baseRate)
	info:SetAttribute("Limit", limit)
	info.Parent = ReplicatedStorage

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("Dose", 0)
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Dose", player:GetAttribute("Dose") or 0)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastLevel[player] = nil
	end)

	if RunService:IsStudio() then
		-- Studio test: ServerStorage.RadiationDebug:Fire(player, dose)
		local debug = Instance.new("BindableEvent")
		debug.Name = "RadiationDebug"
		debug.Event:Connect(function(player: Player, dose: number)
			player:SetAttribute("Dose", dose)
		end)
		debug.Parent = ServerStorage
	end

	task.spawn(function()
		local step = DataMapping.radiation.tickSeconds
		while true do
			local dt = task.wait(step)
			tick(dt)
		end
	end)
	print(`[radiation] base {string.format("%.2f", baseRate)} μGy/h, limit {math.floor(limit)} μGy`)
end

return Radiation
