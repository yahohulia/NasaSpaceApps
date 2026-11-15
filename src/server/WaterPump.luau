--!strict
-- Water pump at the water station (part tagged MB_WaterStation, built in Studio). It runs from the
-- start and breaks at a random moment (SolderConfig.PumpBreakMin..Max seconds of work). To fix it:
-- switch the Water room off on the light panel in the Power room, take out the broken board, solder
-- it at the soldering station (SolderStation), put it back and switch the Water room on again.
--
-- The pump has no switch of its own: its power is the Water room's switch on the light panel
-- (BaseLights sets LightsOn on Workspace.Base.Zones.WaterStationZone; we only read it).
-- Station attributes: PumpPowered, PumpBroken, PumpBoardIn (booleans) and PumpWorking (all three
-- good). MB_ResourceServer checks PumpWorking before it gives water.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.SolderConfig)
local LightsConfig = require(ReplicatedStorage.Shared.LightsConfig)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Notice = require(script.Parent.Notice)
local SolderStation = require(script.Parent.SolderStation)

local KIND = "WaterPump"
local ROOM_ZONE = "WaterStationZone" -- the Water room on the light panel
local WaterPump = {}

type Pump = {
	station: BasePart,
	workedFor: number, -- seconds of work since the last repair
	breakAt: number, -- it breaks after this many seconds of work
	waitsForPower: boolean, -- fixed board is back in; cheer when the room is switched on
	refresh: () -> (),
}

local pumps: { [BasePart]: Pump } = {}
local rng = Random.new()

local function nextBreak(): number
	return rng:NextNumber(Config.PumpBreakMin, Config.PumpBreakMax)
end

local function nearby(player: Player, station: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and (root.Position - station.Position).Magnitude <= Config.Distance
end

local function toAll(key: string, kind: string)
	for _, player in Players:GetPlayers() do
		Notice.send(player, key, kind)
	end
end

local function setup(pump: Pump)
	local station = pump.station
	station:SetAttribute("PumpBroken", false)
	station:SetAttribute("PumpBoardIn", true)
	pump.workedFor = 0
	pump.breakAt = nextBreak()
	pump.waitsForPower = false
end

-- The Water room's zone part (nil if the place has none: then the pump always has power).
local function roomZone(): BasePart?
	local node: Instance? = workspace
	for _, name in LightsConfig.ZonesFolder do
		node = node and node:FindFirstChild(name)
	end
	local zone = node and node:FindFirstChild(ROOM_ZONE)
	return if zone and zone:IsA("BasePart") then zone else nil
end

local function bind(station: Instance)
	if not station:IsA("BasePart") or pumps[station] then
		return
	end
	-- Old attributes from the first soldering version.
	for _, name in { "PumpRepaired", "Repairing", "SolderJoint1", "SolderJoint2", "SolderJoint3", "SolderJoint4" } do
		station:SetAttribute(name, nil)
	end
	for _, name in { "PumpRepairPrompt", "PumpBoardPrompt", "PumpPowerSwitch", "PumpAlarm", "PumpSparks" } do
		local old = station:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	-- Board slot: take the broken board out, or put the fixed one back.
	local boardPrompt = Instance.new("ProximityPrompt")
	boardPrompt.Name = "PumpBoardPrompt"
	boardPrompt.ObjectText = Strings.get("pump.name", "en")
	boardPrompt.KeyboardKeyCode = Enum.KeyCode.F
	boardPrompt.HoldDuration = 0.5
	boardPrompt.MaxActivationDistance = Config.Distance
	boardPrompt.RequiresLineOfSight = false
	boardPrompt.Parent = station

	-- Broken look: sparks, a blinking red light and a "!" sign above the pump.
	local sparks = Instance.new("Sparkles")
	sparks.Name = "PumpSparks"
	sparks.SparkleColor = Color3.fromRGB(255, 200, 80)
	sparks.Enabled = false
	sparks.Parent = station
	local alarm = Instance.new("PointLight")
	alarm.Name = "PumpAlarm"
	alarm.Color = Color3.fromRGB(255, 60, 50)
	alarm.Range = 10
	alarm.Brightness = 3
	alarm.Enabled = false
	alarm.Parent = station
	local sign = Instance.new("BillboardGui")
	sign.Name = "PumpSign"
	sign.Size = UDim2.fromOffset(160, 64)
	sign.StudsOffset = Vector3.new(0, 4, 0)
	sign.AlwaysOnTop = true
	sign.MaxDistance = 60
	sign.Enabled = false
	sign.Parent = station
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundColor3 = Color3.fromRGB(200, 50, 40)
	signText.TextColor3 = Color3.new(1, 1, 1)
	signText.Font = Enum.Font.GothamBold
	signText.TextScaled = true
	signText.Text = Strings.get("pump.sign.broken", "en")
	signText.Parent = sign
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = signText

	local pump: Pump = {
		station = station,
		workedFor = 0,
		breakAt = nextBreak(),
		waitsForPower = false,
		refresh = function() end,
	}
	pumps[station] = pump
	setup(pump)

	local function refresh()
		local powered = station:GetAttribute("PumpPowered") == true
		local broken = station:GetAttribute("PumpBroken") == true
		local boardIn = station:GetAttribute("PumpBoardIn") == true
		local working = powered and boardIn and not broken
		station:SetAttribute("PumpWorking", working)
		boardPrompt.Enabled = broken or not boardIn
		boardPrompt.ActionText = Strings.get(if boardIn then "pump.prompt.takeBoard" else "pump.prompt.putBoard", "en")
		sparks.Enabled = broken and boardIn and powered
		alarm.Enabled = broken or not boardIn
		sign.Enabled = broken or not boardIn
		signText.Text = Strings.get(
			if not boardIn then "pump.sign.noBoard" elseif powered then "pump.sign.broken" else "pump.sign.takeBoard",
			"en"
		)
		local water = station:FindFirstChild("MB_Prompt")
		if water and water:IsA("ProximityPrompt") then
			water.Enabled = working
		end
	end
	pump.refresh = refresh

	-- Power follows the Water room switch on the light panel.
	local function followRoom()
		local zone = roomZone()
		local powered = zone == nil or zone:GetAttribute("LightsOn") ~= false
		if powered == (station:GetAttribute("PumpPowered") == true) then
			return
		end
		station:SetAttribute("PumpPowered", powered)
		if powered and pump.waitsForPower then
			pump.waitsForPower = false
			toAll("pump.toast.working", "info")
		end
	end
	local zone = roomZone()
	if zone then
		zone:GetAttributeChangedSignal("LightsOn"):Connect(followRoom)
	else
		warn("[WaterPump] no " .. ROOM_ZONE .. " zone: the pump has no power switch")
	end
	followRoom()

	boardPrompt.Triggered:Connect(function(player)
		if not nearby(player, station) then
			return
		end
		if station:GetAttribute("PumpBoardIn") == true then
			if station:GetAttribute("PumpBroken") ~= true then
				return
			end
			if station:GetAttribute("PumpPowered") == true then
				Notice.send(player, "pump.toast.powerFirst", "warn")
				return
			end
			if SolderStation.carrying(player) then
				Notice.send(player, "pump.toast.handsFull", "warn")
				return
			end
			station:SetAttribute("PumpBoardIn", false)
			SolderStation.giveBoard(player, KIND, false)
			Notice.send(player, "pump.toast.tookBoard", "info")
		else
			local kind, fixed = SolderStation.carrying(player)
			if kind ~= KIND then
				Notice.send(player, "pump.toast.needBoard", "info")
				return
			end
			if not fixed then
				Notice.send(player, "pump.toast.needFixed", "info")
				return
			end
			SolderStation.takeBoard(player)
			station:SetAttribute("PumpBoardIn", true)
			station:SetAttribute("PumpBroken", false)
			pump.workedFor, pump.breakAt = 0, nextBreak()
			if station:GetAttribute("PumpPowered") == true then
				toAll("pump.toast.working", "info")
			else
				pump.waitsForPower = true
				Notice.send(player, "pump.toast.boardBack", "info")
			end
		end
	end)

	-- Studio test: set PumpBroken = true on the station to break it right away.
	station:GetAttributeChangedSignal("PumpBroken"):Connect(function()
		if station:GetAttribute("PumpBroken") == true then
			toAll("pump.toast.broken", "alert")
		end
	end)
	station.ChildAdded:Connect(refresh)
	for _, name in { "PumpPowered", "PumpBroken", "PumpBoardIn" } do
		station:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

function WaterPump.start()
	-- The carrier left or respawned: the board goes back into the pump as it was.
	SolderStation.onLost(KIND, function(_player, fixed)
		for _, pump in pumps do
			if pump.station:GetAttribute("PumpBoardIn") ~= true then
				pump.station:SetAttribute("PumpBoardIn", true)
				pump.station:SetAttribute("PumpBroken", not fixed)
				if fixed then
					pump.workedFor, pump.breakAt = 0, nextBreak()
				end
				return
			end
		end
	end)

	CollectionService:GetInstanceAddedSignal("MB_WaterStation"):Connect(bind)
	CollectionService:GetInstanceRemovedSignal("MB_WaterStation"):Connect(function(station)
		if station:IsA("BasePart") then
			pumps[station] = nil
		end
	end)
	for _, station in CollectionService:GetTagged("MB_WaterStation") do
		bind(station)
	end

	local function reset()
		SolderStation.reset()
		for _, pump in pumps do
			setup(pump)
		end
	end
	local function bindReset(child: Instance)
		if child.Name == "MB_ResetMission" and child:IsA("BindableEvent") then
			child.Event:Connect(reset)
		end
	end
	for _, child in ServerStorage:GetChildren() do
		bindReset(child)
	end
	ServerStorage.ChildAdded:Connect(bindReset)

	-- Count work time; a working pump breaks once it reaches its random limit.
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			for _, pump in pumps do
				local station = pump.station
				if station:GetAttribute("PumpWorking") == true then
					pump.workedFor += dt
					if pump.workedFor >= pump.breakAt then
						station:SetAttribute("PumpBroken", true)
					end
				end
				local alarm = station:FindFirstChild("PumpAlarm")
				if alarm and alarm:IsA("PointLight") and alarm.Enabled then
					alarm.Brightness = if alarm.Brightness > 1 then 0.5 else 3
				end
			end
		end
	end)
end

return WaterPump
