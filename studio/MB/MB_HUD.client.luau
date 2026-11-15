-- MB_HUD (StarterPlayerScripts): the one HUD of the game. Builds everything in code and only SHOWS state.
-- Layout = Maria's mock-up (2026-11-14 19:41): icon-only pills, smooth rounded bars, round mini radar.
--   left:   energy (EnergyState) · base air (MB_BaseState) · radiation (Player.Dose / RadiationInfo)
--   centre: "Sol N · hh:mm" · suit O2 bar · solar flare countdown
--   right:  mini radar · food / water / tiredness (+ ice when carrying)
-- The older HUD panels of the Rojo client (EnergyHud, DoseMeter, RoleChip, RolePicker, SuitHud) are hidden on this
-- player's screen because this HUD shows the same data; their scripts keep running untouched.
-- Copy of the script that lives in the team place (studio/MB in the repo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local baseState = ReplicatedStorage:WaitForChild("MB_BaseState")
local notify = ReplicatedStorage:WaitForChild("MB_Notify")
local Config = require(ReplicatedStorage:WaitForChild("MB_Config"))
-- Optional systems of the Rojo client (the HUD works without them).
local radiationInfo = ReplicatedStorage:FindFirstChild("RadiationInfo")

local MESSAGES = {
	storm_warning = "Solar flare soon! Get inside the base.",
	storm_start = "Solar flare! Stay inside. Panels give no power.",
	storm_end = "The flare is over. It is safe to go out.",
	rescued = "Your suit ran out of air. The crew helped you back inside.",
	suit_low = "Suit air is low. Go back inside!",
	base_air_empty = "Base air is empty! The generator needs power.",
	power_empty = "No power! Wait for the Sun to charge the panels.",
	ice_full = "Your bag is full. Melt the ice at the base.",
	ice_got = "You got ice! Melt it at the base to drink.",
	need_ice = "No ice. Dig some at the drill outside.",
	harvest_wait = "The plants are still growing. Wait {n} s.",
	storm_fact = "{n}",
	panel_clean = "Panel is clean! More power for the base.",
	sample_got = "Sample collected! {n}",
	radar_broken = "The radar is broken. Fix it at the antenna outside.",
	radar_fixed = "Radar fixed! You can see your crew again.",
	rocket_ready = "The rocket is ready! Go to the launch console.",
	rocket_not_ready = "Not ready yet. Still to do: {n}.",
	new_mission = "A new mission begins. Good luck!",
	panel_fixed = "Panel repaired! It makes power again.",
	o2_fixed = "The oxygen generator works again!",
	launch_late = "It is late, but the rocket can still go. Launch now!",
}

local COLORS = {
	pill = Color3.fromRGB(0, 0, 0),
	track = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(245, 240, 235),
	warning = Color3.fromRGB(235, 90, 70),
	power = Color3.fromRGB(222, 168, 62),
	air = Color3.fromRGB(150, 190, 240),
	radiation = Color3.fromRGB(150, 196, 90),
	suit = Color3.fromRGB(196, 84, 64),
	food = Color3.fromRGB(196, 102, 58),
	water = Color3.fromRGB(88, 126, 214),
	fatigue = Color3.fromRGB(130, 112, 216),
	ice = Color3.fromRGB(190, 230, 255),
	storm = Color3.fromRGB(150, 40, 30),
	you = Color3.fromRGB(255, 255, 255),
	mate = Color3.fromRGB(120, 160, 240),
	base = Color3.fromRGB(222, 168, 62),
}
local PILL_ALPHA = 0.55 -- pill background transparency
local TRACK_ALPHA = 0.75 -- empty part of a bar
local FONT = Font.new(Font.fromEnum(Enum.Font.BuilderSans).Family, Enum.FontWeight.Bold)
local LOW_AT = 20
local REFERENCE_HEIGHT = 480 -- the mock-up is a phone screen

-- Small pixel icons ("#" = pixel), tinted per row.
local ICONS: { [string]: { string } } = {
	Power = { "...##..", "..##...", ".##....", "#####..", "...##..", "..##...", ".##...." },
	Air = { "....##.", "......#", "######.", ".......", "####...", ".......", "#####.." },
	Radiation = { "##...##", "###.###", ".#.#.#.", "...#...", "..###..", "..###..", "......." },
	Food = { "...#...", "..#....", ".#####.", "#######", "#######", ".#####.", "..###.." },
	Water = { "...#...", "..###..", ".#####.", ".#####.", "#######", "#######", ".#####." },
	Tired = { "####...", "..#....", ".#.....", "####...", "....###", ".....#.", "....###" },
	Ice = { "#..#..#", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "#..#..#" },
	Rock = { "..###..", ".#####.", "#######", "#######", ".#####.", "..###..", "......." },
}

local function fmt(s: string, vars: { [string]: any }): string
	return (string.gsub(s, "{(%w+)}", function(k)
		return if vars[k] ~= nil then tostring(vars[k]) else nil
	end))
end

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

type Icon = { frame: Frame, setColor: (Color3) -> (), destroy: () -> () }

local function icon(name: string, color: Color3): Icon
	local rows = ICONS[name] or ICONS.Power
	local px = 2
	local frame = new("Frame", {
		Name = name .. "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(#rows[1] * px, #rows * px),
	})
	local pixels: { Frame } = {}
	for y, row in rows do
		for x = 1, #row do
			if string.sub(row, x, x) == "#" then
				table.insert(
					pixels,
					new("Frame", {
						BorderSizePixel = 0,
						BackgroundColor3 = color,
						Size = UDim2.fromOffset(px, px),
						Position = UDim2.fromOffset((x - 1) * px, (y - 1) * px),
						Parent = frame,
					})
				)
			end
		end
	end
	return {
		frame = frame,
		setColor = function(c: Color3)
			for _, p in pixels do
				p.BackgroundColor3 = c
			end
		end,
		destroy = function()
			frame:Destroy()
		end,
	}
end

local function hlist(parent: Instance, gap: number, align: Enum.HorizontalAlignment?)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
		Parent = parent,
	})
end

local function vlist(parent: Instance, gap: number, align: Enum.HorizontalAlignment?)
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, gap),
		Parent = parent,
	})
end

local function padding(x: number, y: number): UIPadding
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
	})
end

type Bar = { frame: Frame, set: (fraction: number, color: Color3) -> () }

-- Smooth rounded bar: light track, coloured fill.
local function bar(width: number, height: number): Bar
	local track = new("Frame", {
		BackgroundColor3 = COLORS.track,
		BackgroundTransparency = TRACK_ALPHA,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(width, height),
	}, { round() })
	local fill = new("Frame", {
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = track,
	}, { round() })
	return {
		frame = track,
		set = function(fraction: number, color: Color3)
			local f = math.clamp(fraction, 0, 1)
			fill.Size = UDim2.fromScale(f, 1)
			fill.Visible = f > 0
			fill.BackgroundColor3 = color
		end,
	}
end

type Stat = { root: Frame, set: (fraction: number) -> () }

-- [icon] ━━━━━━━━──── ; turns red when isBad(fraction) (default: low).
local function statRow(
	order: number,
	iconName: string,
	color: Color3,
	width: number,
	isBad: ((number) -> boolean)?
): Stat
	local root = new("Frame", {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
	})
	hlist(root, 10)
	local ic = icon(iconName, color)
	ic.frame.LayoutOrder = 1
	ic.frame.Parent = root
	local b = bar(width, 8)
	b.frame.LayoutOrder = 2
	b.frame.Parent = root
	return {
		root = root,
		set = function(fraction: number)
			local bad = if isBad then isBad(fraction) else fraction <= LOW_AT / 100
			b.set(fraction, if bad then COLORS.warning else color)
			ic.setColor(if bad then COLORS.warning else color)
		end,
	}
end

-- A dark rounded pill around one row.
local function pill(order: number, child: Instance): Frame
	local p = new("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = COLORS.pill,
		BackgroundTransparency = PILL_ALPHA,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
	}, { round(UDim.new(0, 10)), padding(12, 9) })
	child.Parent = p
	return p
end

-- Build --------------------------------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "MB_HUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	DisplayOrder = 5,
})

local scales: { UIScale } = {}
local function column(name: string, anchor: Vector2, position: UDim2, align: Enum.HorizontalAlignment?): Frame
	local frame = new("Frame", {
		Name = name,
		AnchorPoint = anchor,
		Position = position,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Parent = gui,
	})
	vlist(frame, 10, align)
	table.insert(scales, new("UIScale", { Parent = frame }))
	return frame
end

-- Left column.
local left = column("Left", Vector2.new(0, 0), UDim2.fromOffset(12, 8))
local powerRow = statRow(1, "Power", COLORS.power, 112)
pill(1, powerRow.root).Parent = left
local airRow = statRow(1, "Air", COLORS.air, 112)
pill(2, airRow.root).Parent = left
local radiationRow = statRow(1, "Radiation", COLORS.radiation, 112, function(f)
	return f >= 0.8 -- radiation is bad when HIGH
end)
local radiationPill = pill(3, radiationRow.root)
radiationPill.Parent = left

-- Centre column.
local center = column("Center", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8), Enum.HorizontalAlignment.Center)
local solPill = new("TextLabel", {
	LayoutOrder = 1,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(),
	BackgroundColor3 = COLORS.pill,
	BackgroundTransparency = PILL_ALPHA,
	FontFace = FONT,
	TextSize = 20,
	TextColor3 = COLORS.text,
	Text = "",
	Parent = center,
}, { round(), padding(18, 6) })

local suitPill = new("Frame", {
	LayoutOrder = 2,
	BackgroundColor3 = COLORS.pill,
	BackgroundTransparency = PILL_ALPHA,
	BorderSizePixel = 0,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(),
	Parent = center,
}, { round(), padding(22, 8) })
local suitBar = bar(140, 10)
suitBar.frame.Parent = suitPill

local stormPill = new("Frame", {
	LayoutOrder = 3,
	BackgroundColor3 = COLORS.storm,
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(),
	Visible = false,
	Parent = center,
}, { round(), padding(16, 5) })
hlist(stormPill, 10)
icon("Radiation", COLORS.text).frame.Parent = stormPill
local stormTime = new("TextLabel", {
	LayoutOrder = 2,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(),
	BackgroundTransparency = 1,
	FontFace = FONT,
	TextSize = 20,
	TextColor3 = COLORS.text,
	Text = "",
	Parent = stormPill,
})

-- Messages under the centre column.
local toast = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 150),
	AutomaticSize = Enum.AutomaticSize.Y,
	Size = UDim2.fromOffset(360, 0),
	BackgroundColor3 = COLORS.pill,
	BackgroundTransparency = PILL_ALPHA,
	FontFace = FONT,
	TextSize = 16,
	TextColor3 = COLORS.text,
	TextWrapped = true,
	Visible = false,
	Parent = gui,
}, { round(UDim.new(0, 12)), padding(14, 8) })
table.insert(scales, new("UIScale", { Parent = toast }))

-- Right column: mini radar, then needs.
local right = column("Right", Vector2.new(1, 0), UDim2.new(1, -8, 0, 8), Enum.HorizontalAlignment.Right)
local RADAR_SIZE = 86
local RADAR_RANGE = 150 -- studs from the centre to the edge
local radar = new("Frame", {
	Name = "Radar",
	LayoutOrder = 1,
	BackgroundColor3 = COLORS.pill,
	BackgroundTransparency = PILL_ALPHA,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(RADAR_SIZE, RADAR_SIZE),
	ClipsDescendants = true,
	Parent = right,
}, { round(), new("UIStroke", { Name = "Ring", Color = COLORS.track, Transparency = 0.8, Thickness = 1 }) })
new("Frame", { -- you
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(6, 6),
	BorderSizePixel = 0,
	BackgroundColor3 = COLORS.you,
	ZIndex = 3,
	Parent = radar,
}, { round() })
local baseDot = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(7, 7),
	BorderSizePixel = 0,
	BackgroundColor3 = COLORS.base,
	ZIndex = 2,
	Parent = radar,
})
local radarDots: { [Player]: Frame } = {}
-- Shown when the radar is broken (MB_BaseState.RadarOK = false).
local radarOff = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	FontFace = FONT,
	TextSize = 30,
	TextColor3 = COLORS.warning,
	Text = "×",
	ZIndex = 4,
	Visible = false,
	Parent = radar,
})

local needs = new("Frame", {
	LayoutOrder = 2,
	BackgroundColor3 = COLORS.pill,
	BackgroundTransparency = PILL_ALPHA,
	BorderSizePixel = 0,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(),
	Parent = right,
}, { round(UDim.new(0, 10)), padding(12, 10) })
vlist(needs, 10)
local foodRow = statRow(1, "Food", COLORS.food, 96)
foodRow.root.Parent = needs
local waterRow = statRow(2, "Water", COLORS.water, 96)
waterRow.root.Parent = needs
local fatigueRow = statRow(3, "Tired", COLORS.fatigue, 96, function(f)
	return f * 100 >= Config.Player.TiredAt -- tiredness is bad when HIGH
end)
fatigueRow.root.Parent = needs
local iceRow = new("Frame", {
	LayoutOrder = 4,
	BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(),
	Visible = false,
	Parent = needs,
})
hlist(iceRow, 10)
icon("Ice", COLORS.ice).frame.Parent = iceRow
local iceText = new("TextLabel", {
	LayoutOrder = 2,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(),
	BackgroundTransparency = 1,
	FontFace = FONT,
	TextSize = 14,
	TextColor3 = COLORS.ice,
	Text = "",
	Parent = iceRow,
})
-- Science samples for the mission: icon + "2/6".
local sampleRow = new("Frame", {
	LayoutOrder = 5,
	BackgroundTransparency = 1,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(),
	Parent = needs,
})
hlist(sampleRow, 10)
icon("Rock", Color3.fromRGB(120, 230, 255)).frame.Parent = sampleRow
local sampleText = new("TextLabel", {
	LayoutOrder = 2,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(),
	BackgroundTransparency = 1,
	FontFace = FONT,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(120, 230, 255),
	Text = "0/6",
	Parent = sampleRow,
})

-- Crosshair.
local cross = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(16, 16),
	BackgroundTransparency = 1,
	Parent = gui,
})
for _, size in { UDim2.fromOffset(2, 16), UDim2.fromOffset(16, 2) } do
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BorderSizePixel = 0,
		BackgroundColor3 = COLORS.text,
		Parent = cross,
	})
end

gui.Parent = playerGui

-- Scale with the screen ------------------------------------------------------------------------------
local function rescale()
	local camera = workspace.CurrentCamera
	if camera then
		local s = math.clamp(camera.ViewportSize.Y / REFERENCE_HEIGHT, 0.75, 1.6)
		for _, scale in scales do
			scale.Scale = s
		end
	end
end
local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	rescale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

-- Bind to state ---------------------------------------------------------------------------------------
local function num(inst: Instance?, name: string, default: number?): number
	local v = inst and inst:GetAttribute(name)
	return if typeof(v) == "number" then v else (default or 0)
end

local function watch(inst: Instance?, attrs: { string }, update: () -> ())
	if inst then
		for _, a in attrs do
			inst:GetAttributeChangedSignal(a):Connect(update)
		end
	end
	update()
end

-- Energy: the MB base power (solar panels, dust, storms, the oxygen generator).
watch(baseState, { "Power" }, function()
	powerRow.set(num(baseState, "Power") / 100)
end)
watch(baseState, { "BaseAir" }, function()
	airRow.set(num(baseState, "BaseAir") / 100)
end)
radiationPill.Visible = radiationInfo ~= nil
watch(player, { "Dose" }, function()
	radiationRow.set(num(player, "Dose") / math.max(1, num(radiationInfo, "Limit", 1)))
end)
watch(player, { "SuitO2" }, function()
	local f = num(player, "SuitO2") / 100
	suitBar.set(f, if f <= LOW_AT / 100 then COLORS.warning else COLORS.suit)
end)
watch(player, { "Food" }, function()
	foodRow.set(num(player, "Food") / 100)
end)
watch(player, { "Water" }, function()
	waterRow.set(num(player, "Water") / 100)
end)
watch(player, { "Fatigue" }, function()
	fatigueRow.set(num(player, "Fatigue") / 100)
end)
watch(player, { "Ice" }, function()
	local ice = num(player, "Ice")
	iceRow.Visible = ice > 0
	iceText.Text = `{ice}/{Config.Player.MaxIce}`
end)
watch(baseState, { "SamplesCollected", "SamplesTotal" }, function()
	sampleText.Text = `{num(baseState, "SamplesCollected")}/{num(baseState, "SamplesTotal", 6)}`
end)
watch(baseState, { "ClockTime", "Sol" }, function()
	local clock = num(baseState, "ClockTime")
	local h = math.floor(clock)
	local m = math.floor((clock - h) * 60)
	solPill.Text = string.format("Sol %d · %02d:%02d", num(baseState, "Sol", 1), h, m)
end)

-- Messages.
local toastToken = 0
notify.OnClientEvent:Connect(function(key: string, n: number?)
	local text = MESSAGES[key]
	if not text then
		return
	end
	toastToken += 1
	local my = toastToken
	toast.Text = fmt(text, { n = n or "" })
	toast.Visible = true
	task.delay(4, function()
		if toastToken == my then
			toast.Visible = false
		end
	end)
end)

-- Older HUD panels: hide the ones this HUD replaces; keep the weather card under our centre column.
-- Roles are not shown in the game (Maria, 2026-11-14): the role chip and role picker stay hidden.
local HIDE_GUIS = { "EnergyHud", "DoseMeter", "RoleChip", "RolePicker" }
local HIDE_PARTS = { SuitHud = { "Oxygen", "Warning" } }

local function hideOldHud()
	for _, name in HIDE_GUIS do
		local g = playerGui:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
		end
	end
	for guiName, parts in HIDE_PARTS do
		local g = playerGui:FindFirstChild(guiName)
		for _, partName in parts do
			local part = g and g:FindFirstChild(partName)
			if part and part:IsA("GuiObject") and part.Visible then
				part.Visible = false
			end
		end
	end
end

local function placeWeatherCard(): number
	local y = center.AbsolutePosition.Y + center.AbsoluteSize.Y + 10
	local card = playerGui:FindFirstChild("WeatherCard")
	local box = card and card:FindFirstChild("Box")
	if card and card:IsA("ScreenGui") and card.Enabled and box and box:IsA("GuiObject") and box.Visible then
		box.AnchorPoint = Vector2.new(0.5, 0)
		box.Position = UDim2.new(0.5, 0, 0, y)
		box.BackgroundColor3 = COLORS.pill
		box.BackgroundTransparency = PILL_ALPHA
		y += box.AbsoluteSize.Y + 10
	end
	return y
end

-- Per-frame: old HUD, flare countdown, radar.
local function mmss(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

RunService.RenderStepped:Connect(function()
	hideOldHud()
	-- Messages go under the weather card and under the MB_EventUI block (it writes EventBottom).
	local eventBottom = gui:GetAttribute("EventBottom")
	toast.Position =
		UDim2.new(0.5, 0, 0, math.max(placeWeatherCard(), if typeof(eventBottom) == "number" then eventBottom else 0))

	local now = workspace:GetServerTimeNow()
	local startsAt = num(baseState, "StormStartsAt")
	local endsAt = num(baseState, "StormEndsAt")
	if baseState:GetAttribute("StormActive") == true and endsAt > 0 then
		stormTime.Text = mmss(endsAt - now)
		stormPill.Visible = true
	elseif startsAt > now then
		stormTime.Text = mmss(startsAt - now)
		stormPill.Visible = true
	else
		stormPill.Visible = false
	end

	local camera = workspace.CurrentCamera
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (camera and myRoot and myRoot:IsA("BasePart")) then
		return
	end
	-- Flat camera basis: "forward" is up on the radar, "right" is right.
	local look = camera.CFrame.LookVector
	local forward = Vector2.new(look.X, look.Z)
	forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector2.new(0, -1)
	local rightDir = Vector2.new(-forward.Y, forward.X)
	local function place(dot: GuiObject, worldPos: Vector3)
		local offset3 = worldPos - myRoot.Position
		local offset = Vector2.new(offset3.X, offset3.Z)
		local v = Vector2.new(offset:Dot(rightDir), -offset:Dot(forward)) / RADAR_RANGE
		if v.Magnitude > 0.85 then
			v = v.Unit * 0.85
		end
		dot.Position = UDim2.fromScale(0.5 + v.X / 2, 0.5 + v.Y / 2)
	end

	-- Broken radar: red ring, a cross, no dots until someone repairs the antenna.
	local radarOk = baseState:GetAttribute("RadarOK") ~= false and baseState:GetAttribute("CommsOffline") ~= true
	radarOff.Visible = not radarOk
	local ring = radar:FindFirstChild("Ring")
	if ring and ring:IsA("UIStroke") then
		ring.Color = if radarOk then COLORS.track else COLORS.warning
		ring.Transparency = if radarOk then 0.8 else 0.1
	end

	local baseModel = workspace:FindFirstChild("MarsBase")
	baseDot.Visible = baseModel ~= nil and radarOk
	if baseModel and baseModel:IsA("Model") then
		place(baseDot, baseModel:GetPivot().Position)
	end

	local alive: { [Player]: boolean } = {}
	for _, other in Players:GetPlayers() do
		local root = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			alive[other] = true
			local dot = radarDots[other]
			if not dot then
				dot = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(7, 7),
					BorderSizePixel = 0,
					BackgroundColor3 = COLORS.mate,
					ZIndex = 2,
					Parent = radar,
				}, { round() })
				radarDots[other] = dot
			end
			place(dot, root.Position)
			dot.Visible = radarOk
		end
	end
	for other, dot in radarDots do
		if not alive[other] then
			dot:Destroy()
			radarDots[other] = nil
		end
	end
end)
