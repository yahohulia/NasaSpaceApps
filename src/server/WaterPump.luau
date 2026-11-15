--!strict
-- Water pump at the water station (part tagged MB_WaterStation, built in Studio). It runs from the
-- start and breaks at a random moment (SolderConfig.PumpBreakMin..Max seconds of work). To fix it:
-- switch the power off, take out the broken board, solder it at the soldering station
-- (SolderStation), put it back and switch the power on.
--
-- Station attributes: PumpPowered, PumpBroken, PumpBoardIn (booleans) and PumpWorking (all three
-- good). MB_ResourceServer checks PumpWorking before it gives water.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.SolderConfig)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Notice = require(script.Parent.Notice)
local SolderStation = require(script.Parent.SolderStation)

local KIND = "WaterPump"
local WaterPump = {}

type Pump = {
	station: BasePart,
	workedFor: number, -- seconds of work since the last repair
	breakAt: number, -- it breaks after this many seconds of work
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
	station:SetAttribute("PumpPowered", true)
	station:SetAttribute("PumpBroken", false)
	station:SetAttribute("PumpBoardIn", true)
	pump.workedFor = 0
	pump.breakAt = nextBreak()
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

	-- Power switch: a separate box beside the pump (click it or press Q).
	local switch = Instance.new("Part")
	switch.Name = "PumpPowerSwitch"
	switch.Size = Vector3.new(1.6, 1, 0.3)
	switch.CFrame = station.CFrame * CFrame.new(2, 0.7, 0)
	switch.Anchored = true
	switch.CanCollide = false
	switch.Material = Enum.Material.SmoothPlastic
	switch.Parent = station
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 100
	surface.Parent = switch
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(1, 1)
	caption.BackgroundTransparency = 1
	caption.TextColor3 = Color3.new(1, 1, 1)
	caption.Font = Enum.Font.GothamBold
	caption.TextScaled = true
	caption.Parent = surface
	local powerPrompt = Instance.new("ProximityPrompt")
	powerPrompt.Name = "PowerSupply"
	powerPrompt.KeyboardKeyCode = Enum.KeyCode.Q
	powerPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	powerPrompt.MaxActivationDistance = Config.Distance
	powerPrompt.RequiresLineOfSight = false
	powerPrompt.ObjectText = Strings.get("pump.power.name", "en")
	powerPrompt.Parent = switch
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = Config.Distance
	click.Parent = switch

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

	local pump: Pump = { station = station, workedFor = 0, breakAt = nextBreak(), refresh = function() end }
	pumps[station] = pump
	setup(pump)

	local function refresh()
		local powered = station:GetAttribute("PumpPowered") == true
		local broken = station:GetAttribute("PumpBroken") == true
		local boardIn = station:GetAttribute("PumpBoardIn") == true
		local working = powered and boardIn and not broken
		station:SetAttribute("PumpWorking", working)
		switch.Color = if powered then Color3.fromRGB(35, 120, 86) else Color3.fromRGB(90, 61, 45)
		caption.Text = Strings.get(if powered then "pump.power.on" else "pump.power.off", "en")
		powerPrompt.ActionText = Strings.get(if powered then "pump.power.switchOff" else "pump.power.switchOn", "en")
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

	local lastToggle = 0
	local function toggle(player: Player)
		if not nearby(player, station) or os.clock() - lastToggle < 0.3 then
			return
		end
		lastToggle = os.clock()
		local powered = station:GetAttribute("PumpPowered") ~= true
		station:SetAttribute("PumpPowered", powered)
		if powered and station:GetAttribute("PumpWorking") == true then
			toAll("pump.toast.working", "info")
		elseif powered and station:GetAttribute("PumpBoardIn") ~= true then
			Notice.send(player, "pump.toast.noBoard", "warn")
		end
	end
	powerPrompt.Triggered:Connect(toggle)
	click.MouseClick:Connect(toggle)

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
			Notice.send(player, "pump.toast.boardBack", "info")
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
