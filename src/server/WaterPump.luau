--!strict
-- Water pump at the water station (part tagged MB_WaterStation, built in Studio). It runs from the
-- start and breaks at a random moment (SolderConfig.PumpBreakMin..Max seconds of work). To fix it:
-- switch the pump off on its power shield in the Power room, take out the broken board, solder it
-- at the soldering station (SolderStation), put it back and switch the pump on again.
--
-- The power shield is built here: a floor-standing box with a big lever, next to the soldering
-- station (Workspace.MB_Interactables.MB_PumpPowerPanel anchor part, or SolderConfig.PumpPanelCFrame).
-- Station attributes: PumpPowered, PumpBroken, PumpBoardIn (booleans) and PumpWorking (all three
-- good). MB_ResourceServer checks PumpWorking before it gives water.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

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
	waitsForPower: boolean, -- fixed board is back in; cheer when the power comes on
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

-- Tells the mission director (MissionDirector) that a crew objective happened.
local function objectiveDone(player: Player?, id: string)
	local event = ServerStorage:FindFirstChild("MB_ObjectiveDone")
	if event and event:IsA("BindableEvent") then
		event:Fire(player, id)
	end
end

local function setup(pump: Pump)
	local station = pump.station
	station:SetAttribute("PumpPowered", true)
	station:SetAttribute("PumpBroken", false)
	station:SetAttribute("PumpBoardIn", true)
	pump.workedFor = 0
	pump.breakAt = nextBreak()
	pump.waitsForPower = false
end

-- The pump's power shield --------------------------------------------------------------------------

type Shield = {
	set: (powered: boolean, alarm: boolean) -> (),
	blink: (bright: boolean) -> (),
}
local shield: Shield? = nil

local function shieldPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Switches every pump on or off. A pump whose fixed board waits for power says it works again.
local function setPower(powered: boolean)
	for _, pump in pumps do
		pump.station:SetAttribute("PumpPowered", powered)
		if powered and pump.waitsForPower then
			pump.waitsForPower = false
			toAll("pump.toast.working", "info")
		end
	end
end

-- A floor-standing box on a post: a yellow-black frame, a big lever that flips up (ON) or down
-- (OFF), a status lamp on the roof and a conduit up to the ceiling. -Z of the origin is its front.
local function buildShield(): Shield
	local folder = workspace:FindFirstChild("MB_Interactables")
	local anchor = folder and folder:FindFirstChild("MB_PumpPowerPanel")
	local origin = Config.PumpPanelCFrame
	if anchor and anchor:IsA("BasePart") then
		origin = anchor.CFrame * CFrame.new(0, -anchor.Size.Y / 2, 0)
		anchor.Transparency = 1
		anchor.CanCollide = false
	end
	local old = (folder or workspace):FindFirstChild("PumpPowerShield")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "PumpPowerShield"
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	shieldPart(model, "Base", Vector3.new(1.3, 0.12, 0.9), at(0, 0.06, 0), Color3.fromRGB(40, 44, 50))
	shieldPart(model, "Post", Vector3.new(0.3, 2.45, 0.3), at(0, 1.3, 0.05), Color3.fromRGB(120, 126, 132))
	local box = shieldPart(model, "Box", Vector3.new(1.6, 1.8, 0.55), at(0, 3.4, 0), Color3.fromRGB(78, 86, 96))
	box.CanCollide = true
	shieldPart(model, "Roof", Vector3.new(1.8, 0.1, 0.75), at(0, 4.35, -0.05), Color3.fromRGB(58, 64, 72))
	shieldPart(model, "Conduit", Vector3.new(0.25, 3, 0.25), at(0.55, 5.9, 0.15), Color3.fromRGB(120, 126, 132))

	-- Front plate: the yellow-black frame, the title and ON / OFF marks.
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.LightInfluence = 0.4
	gui.Parent = box
	local stripes = Instance.new("Frame")
	stripes.Size = UDim2.fromScale(1, 1)
	stripes.BackgroundColor3 = Color3.new(1, 1, 1)
	stripes.BorderSizePixel = 0
	stripes.Parent = gui
	local yellow, black = Color3.fromRGB(245, 196, 40), Color3.fromRGB(25, 25, 25)
	local keys = {}
	for i = 0, 9 do
		local color = if i % 2 == 0 then yellow else black
		table.insert(keys, ColorSequenceKeypoint.new(i / 10, color))
		table.insert(keys, ColorSequenceKeypoint.new((i + 1) / 10 - 0.001, color))
	end
	keys[#keys] = ColorSequenceKeypoint.new(1, black)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(keys)
	gradient.Rotation = 45
	gradient.Parent = stripes
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.new(1, -14, 1, -14)
	inner.BackgroundColor3 = Color3.fromRGB(34, 38, 44)
	inner.BorderSizePixel = 0
	inner.Parent = gui
	local function mark(text: string, y: number, h: number, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.08, y)
		label.Size = UDim2.fromScale(0.84, h)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.Parent = inner
		return label
	end
	mark(Strings.get("pump.power.name", "en"), 0.04, 0.13, Color3.fromRGB(235, 238, 240))
	local onMark = mark(Strings.get("pump.power.onShort", "en"), 0.22, 0.16, Color3.fromRGB(90, 220, 120))
	onMark.TextXAlignment = Enum.TextXAlignment.Left
	local offMark = mark(Strings.get("pump.power.offShort", "en"), 0.78, 0.16, Color3.fromRGB(235, 90, 70))
	offMark.TextXAlignment = Enum.TextXAlignment.Left

	-- Lever: a slot, a hinge, an arm and a red knob. It turns around the hinge.
	shieldPart(model, "Slot", Vector3.new(0.34, 1.05, 0.04), at(-0.42, 3.35, -0.29), Color3.fromRGB(15, 15, 18))
	local hinge = at(-0.42, 3.35, -0.36)
	local pin = shieldPart(model, "Hinge", Vector3.new(0.5, 0.22, 0.22), hinge, Color3.fromRGB(150, 155, 160))
	pin.Shape = Enum.PartType.Cylinder
	local arm = shieldPart(model, "LeverArm", Vector3.new(0.14, 0.75, 0.14), hinge, Color3.fromRGB(190, 195, 200))
	local knob = shieldPart(
		model,
		"LeverKnob",
		Vector3.new(0.36, 0.36, 0.36),
		hinge,
		Color3.fromRGB(210, 45, 40),
		Enum.Material.SmoothPlastic
	)
	knob.Shape = Enum.PartType.Ball
	local angle = Instance.new("NumberValue")
	angle.Name = "LeverAngle"
	angle.Value = -0.5
	angle.Parent = model
	local function placeLever()
		-- Negative angles tip the lever out towards the player.
		local turn = hinge * CFrame.Angles(angle.Value, 0, 0)
		arm.CFrame = turn * CFrame.new(0, 0.37, 0)
		knob.CFrame = turn * CFrame.new(0, 0.78, 0)
	end
	angle.Changed:Connect(placeLever)
	placeLever()

	-- Status lamp: green = water flows, red (blinking) = the pump needs help, dark = power off.
	local lamp = shieldPart(
		model,
		"Lamp",
		Vector3.new(0.34, 0.34, 0.34),
		at(-0.55, 4.55, -0.05),
		Color3.fromRGB(60, 60, 60),
		Enum.Material.SmoothPlastic
	)
	lamp.Shape = Enum.PartType.Ball
	local glow = Instance.new("PointLight")
	glow.Range = 7
	glow.Brightness = 2
	glow.Enabled = false
	glow.Parent = lamp
	model.Parent = folder or workspace

	-- Q / gamepad Y or a click flips the lever.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PowerSupply"
	prompt.KeyboardKeyCode = Enum.KeyCode.Q
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.MaxActivationDistance = Config.Distance
	prompt.RequiresLineOfSight = false
	prompt.ObjectText = Strings.get("pump.power.name", "en")
	prompt.ActionText = Strings.get("pump.power.switchOff", "en")
	prompt.Parent = box
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = Config.Distance
	click.Parent = box
	local powered = true
	local lastToggle = 0
	local function toggle(player: Player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) or (root.Position - box.Position).Magnitude > Config.Distance then
			return
		end
		if os.clock() - lastToggle < 0.3 then
			return
		end
		lastToggle = os.clock()
		setPower(not powered)
	end
	prompt.Triggered:Connect(toggle)
	click.MouseClick:Connect(toggle)

	local leverTween: Tween? = nil
	local function set(on: boolean, alarm: boolean)
		powered = on
		local target = if on then -0.5 else -(math.pi - 0.5)
		if math.abs(angle.Value - target) > 0.01 then
			if leverTween then
				leverTween:Cancel()
			end
			local tween = TweenService:Create(angle, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Value = target })
			leverTween = tween
			tween:Play()
		end
		prompt.ActionText = Strings.get(if on then "pump.power.switchOff" else "pump.power.switchOn", "en")
		onMark.TextTransparency = if on then 0 else 0.7
		offMark.TextTransparency = if on then 0.7 else 0
		local color = if not on
			then Color3.fromRGB(60, 60, 60)
			elseif alarm then Color3.fromRGB(255, 70, 50)
			else Color3.fromRGB(80, 230, 110)
		lamp.Color = color
		lamp.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		lamp.Transparency = 0
		glow.Color = color
		glow.Enabled = on
	end
	local function blink(bright: boolean)
		if powered then
			lamp.Transparency = if bright then 0 else 0.6
		end
	end
	return { set = set, blink = blink }
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
		if shield then
			shield.set(powered, broken or not boardIn)
		end
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
		else
			objectiveDone(nil, "pump") -- the fixed board is back in
		end
	end)
	station.ChildAdded:Connect(refresh)
	for _, name in { "PumpPowered", "PumpBroken", "PumpBoardIn" } do
		station:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

-- The mission director breaks the pump on sol 2 (its own random breaks stay as they are).
function WaterPump.breakNow()
	for _, pump in pumps do
		pump.station:SetAttribute("PumpBroken", true)
	end
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

	shield = buildShield()

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
					if shield then
						shield.blink(alarm.Brightness > 1)
					end
				end
			end
		end
	end)
end

return WaterPump
