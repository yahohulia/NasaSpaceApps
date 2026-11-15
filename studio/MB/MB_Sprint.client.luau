-- MB_Sprint (StarterPlayerScripts): running with a stamina bar.
--   PC: hold Shift while walking. A small hint "[Shift] + [↑] Run" sits in the bottom-left corner.
--   Phone: tap the Run button (above the jump button) to start or stop running.
--   The bar (in the MB_HUD centre column) lasts Config.Sprint.MaxSeconds of running and refills from
--   empty in RefillSeconds. No running while the player is slowed (hungry, thirsty or very tired).
-- Speed comes from the server (MB_ResourceServer sets the walk speed); running multiplies it on this client.
-- Copy of the script that lives in the team place (studio/MB in the repo).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("MB_Config"))
local S = Config.Sprint
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Font.new(Font.fromEnum(Enum.Font.BuilderSans).Family, Enum.FontWeight.Bold)
local PILL = Color3.fromRGB(0, 0, 0)
local TEXT = Color3.fromRGB(245, 240, 235)
local GOOD = Color3.fromRGB(110, 205, 120)
local LOW = Color3.fromRGB(235, 90, 70)

local stamina = S.MaxSeconds -- seconds of running left
local wantRun = false -- Shift held / Run button on
local running = false
local exhausted = false -- ran out: wait until MinToStart before running again
local sinceRun = math.huge

local humanoid: Humanoid? = nil
local baseSpeed = Config.Player.NormalWalkSpeed
local lastSet = -1 -- the WalkSpeed this script set last (to tell it apart from server changes)

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function round(radius: UDim?): UICorner
	return new("UICorner", { CornerRadius = radius or UDim.new(1, 0) })
end

-- Stamina bar --------------------------------------------------------------------------------------
-- Lives in the MB_HUD centre column (under the suit bar) so it scales with the rest of the HUD.
local hud = playerGui:WaitForChild("MB_HUD", 15)
local center = hud and hud:WaitForChild("Center", 5)
local ownGui: ScreenGui? = nil
if not center then
	ownGui = new("ScreenGui", { Name = "MB_Sprint", ResetOnSpawn = false, Parent = playerGui })
	center = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Parent = ownGui,
	})
end

local RUN_ICON = { "..##...", "..##...", ".####..", "#.##.#.", "..##...", ".#..#..", "#....#." }
local barPill = new("Frame", {
	Name = "Stamina",
	LayoutOrder = 4,
	BackgroundColor3 = PILL,
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(),
	Parent = center,
}, {
	round(),
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 18),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	}),
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}),
})
local icon = new("Frame", {
	LayoutOrder = 1,
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(14, 14),
	Parent = barPill,
})
local iconPixels: { Frame } = {}
for y, row in RUN_ICON do
	for x = 1, #row do
		if string.sub(row, x, x) == "#" then
			table.insert(
				iconPixels,
				new("Frame", {
					BorderSizePixel = 0,
					BackgroundColor3 = GOOD,
					Size = UDim2.fromOffset(2, 2),
					Position = UDim2.fromOffset((x - 1) * 2, (y - 1) * 2),
					Parent = icon,
				})
			)
		end
	end
end
local track = new("Frame", {
	LayoutOrder = 2,
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.75,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(116, 8),
	Parent = barPill,
}, { round() })
local fill = new("Frame", {
	BackgroundColor3 = GOOD,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Parent = track,
}, { round() })

local function drawBar()
	local f = math.clamp(stamina / S.MaxSeconds, 0, 1)
	fill.Size = UDim2.fromScale(f, 1)
	fill.Visible = f > 0
	local c = if exhausted or f < 0.25 then LOW else GOOD
	fill.BackgroundColor3 = c
	for _, p in iconPixels do
		p.BackgroundColor3 = c
	end
end

-- PC hint: "[Shift] + [↑] Run" in the bottom-left corner ---------------------------------------
local function keycap(text: string, order: number): TextLabel
	return new("TextLabel", {
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.15,
		FontFace = FONT,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(30, 30, 30),
		Text = text,
	}, {
		round(UDim.new(0, 4)),
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}),
	})
end

local function label(text: string, order: number): TextLabel
	return new("TextLabel", {
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextSize = 14,
		TextColor3 = TEXT,
		Text = text,
	})
end

local controlsGui = new("ScreenGui", {
	Name = "MB_SprintControls",
	ResetOnSpawn = false,
	DisplayOrder = 6,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	Parent = playerGui,
})

local hint = new("Frame", {
	Name = "Hint",
	-- Bottom-left: the bottom centre is taken by the team's bag / hotbar, and on PC the corner is free.
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -16),
	BackgroundColor3 = PILL,
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(),
	Visible = false,
	Parent = controlsGui,
}, {
	round(),
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
	}),
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}),
})
keycap("Shift", 1).Parent = hint
label("+", 2).Parent = hint
keycap("↑", 3).Parent = hint
label("Run", 4).Parent = hint

-- Phone: round Run button above the jump button --------------------------------------------------
local runButton = new("TextButton", {
	Name = "RunButton",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(1, -60, 1, -150),
	Size = UDim2.fromOffset(64, 64),
	BackgroundColor3 = PILL,
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	FontFace = FONT,
	TextSize = 16,
	TextColor3 = TEXT,
	Text = "Run",
	AutoButtonColor = false,
	Visible = false,
	Parent = controlsGui,
}, { round(), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.5, Thickness = 2 }) })

local function placeRunButton()
	-- Stack above Roblox's jump button when it exists, so thumbs find it easily.
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
	if jump and jump:IsA("GuiObject") and jump.AbsoluteSize.X > 0 then
		local size = math.floor(jump.AbsoluteSize.X * 0.75)
		runButton.Size = UDim2.fromOffset(size, size)
		local centerX = jump.AbsolutePosition.X + jump.AbsoluteSize.X / 2
		local inset = controlsGui.AbsolutePosition
		runButton.AnchorPoint = Vector2.new(0.5, 1)
		runButton.Position = UDim2.fromOffset(centerX - inset.X, jump.AbsolutePosition.Y - inset.Y - 10)
	end
end

local function refreshControls()
	local touch = UserInputService.TouchEnabled
	local keyboard = UserInputService.KeyboardEnabled
	hint.Visible = keyboard
	runButton.Visible = touch
	if touch then
		placeRunButton()
	end
end
UserInputService.LastInputTypeChanged:Connect(refreshControls)
refreshControls()
-- The jump button appears a bit later and moves when the screen rotates: keep the Run button above it.
task.spawn(function()
	while controlsGui.Parent do
		if runButton.Visible then
			placeRunButton()
		end
		task.wait(2)
	end
end)

local function drawButton()
	runButton.BackgroundColor3 = if wantRun then GOOD else PILL
	runButton.BackgroundTransparency = if wantRun then 0.2 else 0.45
end

runButton.Activated:Connect(function()
	wantRun = not wantRun
	drawButton()
end)

-- Shift (and gamepad left stick press) at high priority, so Shift does not also toggle Shift Lock.
ContextActionService:BindActionAtPriority(
	"MB_Sprint",
	function(_, state)
		if state == Enum.UserInputState.Begin then
			wantRun = true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			wantRun = false
		end
		return Enum.ContextActionResult.Sink
	end,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift,
	Enum.KeyCode.ButtonL3
)

-- Speed ---------------------------------------------------------------------------------------------
local function apply()
	local h = humanoid
	if not h then
		return
	end
	local speed = if running then baseSpeed * S.Multiplier else baseSpeed
	if h.WalkSpeed ~= speed then
		lastSet = speed
		h.WalkSpeed = speed
	end
end

local function onCharacter(character: Model)
	local h = character:WaitForChild("Humanoid", 10)
	if not (h and h:IsA("Humanoid")) then
		return
	end
	humanoid = h
	baseSpeed = h.WalkSpeed
	lastSet = -1
	running = false
	-- A change we did not make came from the server (normal / slowed speed): that is the new base.
	h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if h.WalkSpeed ~= lastSet then
			baseSpeed = h.WalkSpeed
			apply()
		end
	end)
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

RunService.Heartbeat:Connect(function(dt)
	local h = humanoid
	local moving = h ~= nil and h.MoveDirection.Magnitude > 0.1 and h.FloorMaterial ~= Enum.Material.Air
	local slowed = baseSpeed < Config.Player.NormalWalkSpeed - 0.01 -- hungry / thirsty / very tired

	if exhausted and stamina >= S.MinToStart then
		exhausted = false
	end
	local canRun = not exhausted and not slowed and stamina > 0
	local nowRunning = wantRun and moving and canRun

	if nowRunning then
		stamina = math.max(0, stamina - dt)
		sinceRun = 0
		if stamina <= 0 then
			exhausted = true
			nowRunning = false
		end
	else
		sinceRun += dt
		if sinceRun >= S.RefillDelay then
			stamina = math.min(S.MaxSeconds, stamina + dt * S.MaxSeconds / S.RefillSeconds)
		end
	end

	if nowRunning ~= running then
		running = nowRunning
		apply()
	end
	-- Phone toggle switches itself off when the bar runs out.
	if exhausted and wantRun and runButton.Visible then
		wantRun = false
		drawButton()
	end
	player:SetAttribute("MB_Stamina", stamina / S.MaxSeconds) -- local only, for other UI
	drawBar()
end)
drawBar()
drawButton()
