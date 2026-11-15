--!strict
-- Soldering mini game and the "carry the board" hint. The server (SolderStation) owns the game;
-- this only draws it and sends hold / release / test / close.
-- How it plays: hold the glowing contact, the iron heats it, solder fills it, let go in time.
-- Too early or too late: wait for it to cool and try again. A quick release gives a shiny joint (star).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.SolderConfig)
local Strings = require(ReplicatedStorage.Shared.Strings)

local SolderClient = {}

local C = {
	panel = Color3.fromRGB(22, 30, 40),
	text = Color3.fromRGB(236, 242, 246),
	dim = Color3.fromRGB(150, 165, 178),
	mat = Color3.fromRGB(44, 78, 96),
	pcb = Color3.fromRGB(22, 104, 60),
	pcbEdge = Color3.fromRGB(12, 58, 34),
	trace = Color3.fromRGB(44, 138, 82), -- copper under the green mask
	silk = Color3.fromRGB(236, 240, 228),
	chip = Color3.fromRGB(24, 24, 28),
	tin = Color3.fromRGB(196, 200, 196),
	lead = Color3.fromRGB(226, 230, 234),
	gold = Color3.fromRGB(214, 172, 80),
	resistor = Color3.fromRGB(214, 190, 140),
	ledOff = Color3.fromRGB(70, 40, 40),
	glow = Color3.fromRGB(255, 205, 90),
	solder = Color3.fromRGB(214, 222, 228),
	solderLight = Color3.fromRGB(255, 255, 255),
	solderDark = Color3.fromRGB(150, 158, 166),
	solderDull = Color3.fromRGB(150, 150, 146), -- a slow joint sets grey and grainy
	grip = Color3.fromRGB(40, 120, 200),
	steel = Color3.fromRGB(190, 196, 202),
	tipCold = Color3.fromRGB(150, 120, 70),
	cold = Color3.fromRGB(80, 150, 230),
	melt = Color3.fromRGB(80, 210, 120),
	hot = Color3.fromRGB(235, 80, 60),
	star = Color3.fromRGB(255, 210, 60),
	button = Color3.fromRGB(46, 130, 90),
}
local HOT_ZONE = 0.85 -- the heat meter turns red above this (display only)

local function round(item: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0)
	corner.Parent = item
end

local function frame(parent: Instance, name: string, pos: UDim2, size: UDim2, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function text(
	parent: Instance,
	name: string,
	pos: UDim2,
	size: UDim2,
	content: string,
	maxSize: number?
): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Position = pos
	t.Size = size
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = C.text
	t.TextScaled = true
	t.TextWrapped = true
	t.Text = content
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize or 24
	limit.MinTextSize = 10
	limit.Parent = t
	t.Parent = parent
	return t
end

local function button(
	parent: Instance,
	name: string,
	pos: UDim2,
	size: UDim2,
	content: string,
	color: Color3
): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true
	b.Text = content
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 24
	limit.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.18, 0), UDim.new(0.18, 0)
	pad.Parent = b
	round(b, 10)
	b.Parent = parent
	return b
end

function SolderClient.start()
	local player = Players.LocalPlayer
	local lang = Strings.langFromLocale(player.LocaleId)
	local function t(key: string, vars: { [string]: string | number }?): string
		return Strings.get(key, lang, vars)
	end
	local remote = ReplicatedStorage:WaitForChild("Solder") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "SolderUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Carry hint ----------------------------------------------------------------------------------
	local carry = text(gui, "CarryHint", UDim2.new(0.5, 0, 0, 70), UDim2.fromScale(0.6, 0.05), "", 20)
	carry.AnchorPoint = Vector2.new(0.5, 0)
	carry.BackgroundColor3 = Color3.fromRGB(30, 44, 60)
	carry.BackgroundTransparency = 0.1
	carry.Visible = false
	round(carry, 8)
	local carryStroke = Instance.new("UIStroke")
	carryStroke.Thickness = 2
	carryStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	carryStroke.Parent = carry

	local benchPrompt: ProximityPrompt? = nil
	local function carrying(): (string?, boolean)
		local value = player:GetAttribute("CarryingBoard")
		if type(value) ~= "string" then
			return nil, false
		end
		local kind, suffix = string.match(value, "^([^:]+)(.*)$")
		return kind, suffix == ":fixed"
	end
	local function refreshCarry()
		local kind, fixed = carrying()
		carry.Visible = kind ~= nil
		if kind then
			carry.Text = t(
				if fixed then "solder.carry.fixed" else "solder.carry.broken",
				{ machine = t("solder.board." .. kind) }
			)
			carryStroke.Color = if fixed then C.melt else C.glow
		end
		-- Only a player with a broken board sees "Fix the board" at the bench (local change).
		if benchPrompt then
			benchPrompt.Enabled = kind ~= nil and not fixed
		end
	end
	player:GetAttributeChangedSignal("CarryingBoard"):Connect(refreshCarry)
	task.spawn(function()
		local folder = workspace:WaitForChild("MB_Interactables", 30) or workspace
		local bench = folder:WaitForChild("MB_SolderStation", 30)
		local desk = bench and bench:WaitForChild("Desk", 10)
		local prompt = desk and desk:WaitForChild("SolderPrompt", 10)
		if prompt and prompt:IsA("ProximityPrompt") then
			benchPrompt = prompt
			prompt.ActionText = t("solder.prompt.fix")
			prompt.ObjectText = t("solder.bench.name")
		end
		refreshCarry()
	end)
	refreshCarry()

	-- Panel ---------------------------------------------------------------------------------------
	local panel = frame(gui, "Workbench", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.94, 0.86), C.panel)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	round(panel, 16)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(900, 620)
	limit.Parent = panel
	local title = text(panel, "Title", UDim2.fromScale(0.04, 0.03), UDim2.fromScale(0.6, 0.07), t("solder.title"), 28)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local closeButton = button(
		panel,
		"Close",
		UDim2.fromScale(0.86, 0.03),
		UDim2.fromScale(0.1, 0.07),
		t("solder.close"),
		Color3.fromRGB(70, 80, 92)
	)
	closeButton.Modal = true

	-- Joint progress: one circle per contact, a star for a shiny joint.
	local progress = frame(panel, "Progress", UDim2.fromScale(0.04, 0.11), UDim2.fromScale(0.6, 0.06), C.panel)
	progress.BackgroundTransparency = 1
	local progressLayout = Instance.new("UIListLayout")
	progressLayout.FillDirection = Enum.FillDirection.Horizontal
	progressLayout.Padding = UDim.new(0, 8)
	progressLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	progressLayout.Parent = progress
	local dots: { TextLabel } = {}

	-- The circuit board: green solder mask on an anti-static mat.
	local mat = frame(panel, "Mat", UDim2.fromScale(0.025, 0.175), UDim2.fromScale(0.65, 0.59), C.mat)
	round(mat, 12)
	local boardArea = frame(panel, "Board", UDim2.fromScale(0.04, 0.19), UDim2.fromScale(0.62, 0.56), C.pcb)
	round(boardArea, 8)
	local edge = Instance.new("UIStroke")
	edge.Color, edge.Thickness = C.pcbEdge, 3
	edge.Parent = boardArea
	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 190, 180))
	sheen.Rotation = 35
	sheen.Parent = boardArea

	-- White silkscreen print.
	local function silk(content: string, x: number, y: number, w: number, h: number): TextLabel
		local label = text(boardArea, "Silk", UDim2.fromScale(x, y), UDim2.fromScale(w, h), content, 14)
		label.Font = Enum.Font.RobotoMono
		label.TextColor3 = C.silk
		label.ZIndex = 2
		return label
	end
	local function dot(parent: Instance, name: string, x: number, y: number, size: number, color: Color3): Frame
		local d = frame(parent, name, UDim2.fromScale(x, y), UDim2.fromScale(size, size), color)
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.SizeConstraint = Enum.SizeConstraint.RelativeYY
		round(d)
		return d
	end

	-- Gold-rimmed mounting holes in the corners.
	for _, spot in
		{ Vector2.new(0.03, 0.06), Vector2.new(0.97, 0.06), Vector2.new(0.03, 0.94), Vector2.new(0.97, 0.94) }
	do
		local hole = dot(boardArea, "MountHole", spot.X, spot.Y, 0.06, Color3.fromRGB(14, 22, 18))
		local rim = Instance.new("UIStroke")
		rim.Color, rim.Thickness = C.gold, 3
		rim.Parent = hole
	end

	-- U1: the control chip, a black package with silver legs, a notch and a pin-1 dot.
	local chip = frame(boardArea, "Chip", UDim2.fromScale(0.33, 0.1), UDim2.fromScale(0.34, 0.18), C.chip)
	chip.ZIndex = 3
	round(chip, 3)
	local notch = dot(chip, "Notch", 0, 0.5, 0.35, C.pcb)
	notch.ZIndex = 4
	dot(chip, "Pin1", 0.07, 0.2, 0.12, Color3.fromRGB(200, 200, 200)).ZIndex = 4
	local marking = text(chip, "Marking", UDim2.fromScale(0.12, 0.25), UDim2.fromScale(0.76, 0.5), t("solder.chip"), 14)
	marking.Font = Enum.Font.RobotoMono
	marking.TextColor3 = Color3.fromRGB(150, 150, 155)
	marking.ZIndex = 4
	silk("U1", 0.26, 0.1, 0.06, 0.07)
	local legX: { number } = {}
	for k = 0, 5 do
		local x = 0.36 + k * 0.056
		table.insert(legX, x)
		for _, y in { 0.065, 0.28 } do
			local leg = frame(boardArea, "Leg", UDim2.fromScale(x - 0.011, y), UDim2.fromScale(0.022, 0.035), C.tin)
			leg.ZIndex = 2
		end
	end

	-- R1, R2: beige resistors with colour bands; C1: a blue capacitor seen from above.
	local function resistor(name: string, x: number, y: number)
		local lead =
			frame(boardArea, name .. "Lead", UDim2.fromScale(x - 0.08, y - 0.005), UDim2.fromScale(0.16, 0.01), C.tin)
		lead.ZIndex = 2
		local body =
			frame(boardArea, name, UDim2.fromScale(x - 0.05, y - 0.025), UDim2.fromScale(0.1, 0.05), C.resistor)
		body.ZIndex = 3
		round(body, 6)
		for i, color in { Color3.fromRGB(120, 70, 30), Color3.fromRGB(20, 20, 20), Color3.fromRGB(200, 40, 30), C.gold } do
			local band = frame(body, "Band", UDim2.fromScale(0.15 + (i - 1) * 0.2, 0), UDim2.fromScale(0.08, 1), color)
			band.ZIndex = 4
		end
		silk(name, x - 0.04, y - 0.085, 0.08, 0.05)
	end
	resistor("R1", 0.15, 0.17)
	resistor("R2", 0.15, 0.31)
	local cap = dot(boardArea, "C1", 0.85, 0.2, 0.17, Color3.fromRGB(40, 70, 160))
	cap.ZIndex = 3
	local capStripe =
		frame(cap, "Stripe", UDim2.fromScale(0.62, 0), UDim2.fromScale(0.2, 1), Color3.fromRGB(150, 170, 220))
	capStripe.ZIndex = 4
	local capRim = Instance.new("UIStroke")
	capRim.Color, capRim.Thickness = Color3.fromRGB(20, 30, 70), 2
	capRim.Parent = cap
	silk("C1", 0.74, 0.08, 0.06, 0.06)
	for i, y in { 0.13, 0.23 } do
		local smd = frame(boardArea, "Smd" .. i, UDim2.fromScale(0.71, y), UDim2.fromScale(0.04, 0.035), C.resistor)
		smd.ZIndex = 3
	end
	silk(t("solder.pcb.label"), 0.6, 0.9, 0.34, 0.06).TextXAlignment = Enum.TextXAlignment.Right

	-- Four "OK" lamps that light up when the board passes its test.
	local leds: { Frame } = {}
	for i = 1, 4 do
		local led = frame(
			boardArea,
			"Led" .. i,
			UDim2.fromScale(0.76 + (i - 1) * 0.045, 0.37),
			UDim2.fromScale(0.03, 0.04),
			C.ledOff
		)
		led.ZIndex = 3
		round(led, 2)
		table.insert(leds, led)
	end
	silk("OK", 0.76, 0.42, 0.17, 0.05)

	local letGo = text(boardArea, "LetGo", UDim2.fromScale(0.5, 0.42), UDim2.fromScale(0.7, 0.2), t("solder.letGo"), 64)
	letGo.AnchorPoint = Vector2.new(0.5, 0.5)
	letGo.TextColor3 = C.star
	letGo.ZIndex = 8
	letGo.Visible = false
	local letGoStroke = Instance.new("UIStroke")
	letGoStroke.Thickness = 3
	letGoStroke.Color = Color3.fromRGB(60, 30, 0)
	letGoStroke.Parent = letGo

	-- Tools drawn in a frame twice their length: the tool fills the top half, so the frame's centre
	-- (where GUI rotation turns) is the tool's point.
	local function tool(name: string, width: number, length: number, rotation: number): Frame
		local holder = frame(boardArea, name, UDim2.fromScale(0, 0), UDim2.fromScale(width, length * 2), Color3.new())
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.BackgroundTransparency = 1
		holder.Rotation = rotation
		holder.ZIndex = 6
		holder.Visible = false
		return holder
	end
	local function piece(
		holder: Frame,
		name: string,
		y0: number,
		y1: number,
		w: number,
		color: Color3,
		radius: number?
	): Frame
		local p = frame(holder, name, UDim2.fromScale(0.5 - w / 2, y0), UDim2.fromScale(w, y1 - y0), color)
		p.ZIndex = 6
		if radius then
			round(p, radius)
		end
		return p
	end
	-- The iron, coming in from the upper right.
	local iron = tool("Iron", 0.065, 0.62, 32)
	piece(iron, "Cable", 0, 0.06, 0.3, Color3.fromRGB(20, 20, 22))
	piece(iron, "Grip", 0.06, 0.29, 1, C.grip, 8)
	for i, y in { 0.12, 0.17, 0.22 } do
		piece(iron, "Ring" .. i, y, y + 0.015, 1, Color3.fromRGB(25, 30, 40))
	end
	piece(iron, "Collar", 0.29, 0.32, 0.65, C.steel)
	piece(iron, "Shaft", 0.32, 0.46, 0.28, C.steel)
	local ironTip = piece(iron, "Tip", 0.46, 0.5, 0.16, C.tipCold, 2)
	-- The solder wire, coming in from the upper left.
	local wire = tool("Wire", 0.03, 0.8, -50)
	piece(wire, "Solder", 0, 0.5, 0.45, C.solder, 2)

	-- Heat meter.
	text(panel, "HeatTitle", UDim2.fromScale(0.7, 0.19), UDim2.fromScale(0.26, 0.05), t("solder.heat"), 20)
	local meter =
		frame(panel, "HeatMeter", UDim2.fromScale(0.74, 0.25), UDim2.fromScale(0.07, 0.5), Color3.fromRGB(44, 52, 60))
	round(meter, 10)
	local function zone(name: string, from: number, to: number, color: Color3)
		local z = frame(meter, name, UDim2.fromScale(0, 1 - to), UDim2.fromScale(1, to - from), color)
		z.BackgroundTransparency = 0.7
	end
	zone("Cold", 0, Config.MeltHeat, C.cold)
	zone("Melt", Config.MeltHeat, HOT_ZONE, C.melt)
	zone("Hot", HOT_ZONE, 1, C.hot)
	local heat = frame(meter, "Heat", UDim2.fromScale(0.2, 1), UDim2.fromScale(0.6, 0), C.cold)
	heat.AnchorPoint = Vector2.new(0, 1)
	round(heat, 6)
	local function zoneLabel(key: string, y: number, color: Color3)
		local l = text(
			panel,
			key,
			UDim2.fromScale(0.82, 0.25 + 0.5 * (1 - y) - 0.025),
			UDim2.fromScale(0.15, 0.05),
			t(key),
			16
		)
		l.TextColor3 = color
		l.TextXAlignment = Enum.TextXAlignment.Left
	end
	zoneLabel("solder.zone.hot", (1 + HOT_ZONE) / 2, C.hot)
	zoneLabel("solder.zone.melt", (Config.MeltHeat + HOT_ZONE) / 2, C.melt)
	zoneLabel("solder.zone.cold", Config.MeltHeat / 2, C.cold)

	-- Solder fill bar under the board.
	text(panel, "FillTitle", UDim2.fromScale(0.04, 0.76), UDim2.fromScale(0.16, 0.05), t("solder.fill"), 18)
	local fillTrack =
		frame(panel, "FillTrack", UDim2.fromScale(0.21, 0.775), UDim2.fromScale(0.45, 0.03), Color3.fromRGB(44, 52, 60))
	round(fillTrack, 6)
	local fillBar = frame(fillTrack, "Fill", UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), C.solder)
	round(fillBar, 6)

	local status = text(panel, "Status", UDim2.fromScale(0.04, 0.83), UDim2.fromScale(0.92, 0.07), "", 28)
	local hint = text(panel, "Hint", UDim2.fromScale(0.04, 0.91), UDim2.fromScale(0.92, 0.05), t("solder.hint"), 16)
	hint.TextColor3 = C.dim
	local actionButton =
		button(panel, "Action", UDim2.fromScale(0.68, 0.79), UDim2.fromScale(0.28, 0.1), t("solder.test"), C.button)
	actionButton.Visible = false

	-- First-time "how to" card.
	local howTo = frame(panel, "HowTo", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(16, 22, 30))
	howTo.BackgroundTransparency = 0.05
	howTo.ZIndex = 20
	howTo.Visible = false
	round(howTo, 16)
	local howTitle =
		text(howTo, "Title", UDim2.fromScale(0.1, 0.08), UDim2.fromScale(0.8, 0.1), t("solder.how.title"), 34)
	howTitle.ZIndex = 21
	for i = 1, 3 do
		local step = text(
			howTo,
			"Step" .. i,
			UDim2.fromScale(0.1, 0.22 + (i - 1) * 0.17),
			UDim2.fromScale(0.8, 0.13),
			t("solder.how." .. i),
			24
		)
		step.TextXAlignment = Enum.TextXAlignment.Left
		step.ZIndex = 21
	end
	local note = text(howTo, "Note", UDim2.fromScale(0.1, 0.72), UDim2.fromScale(0.8, 0.06), t("solder.simulation"), 16)
	note.TextColor3 = C.dim
	note.ZIndex = 21
	local gotIt =
		button(howTo, "GotIt", UDim2.fromScale(0.35, 0.82), UDim2.fromScale(0.3, 0.1), t("solder.how.ok"), C.button)
	gotIt.ZIndex = 21
	local seenHowTo = false
	gotIt.Activated:Connect(function()
		howTo.Visible = false
	end)

	-- State ---------------------------------------------------------------------------------------
	local id: string? = nil
	local joints = 0
	local joint = 0
	local phase = ""
	local perfect = 0
	local pads: { TextButton } = {}
	local beads: { Frame } = {}
	local shades: { UIGradient } = {}
	local traces: { GuiObject } = {} -- traces and pad labels, rebuilt for each board
	local holding = false
	local heldInput: InputObject? = nil
	local heartbeat = 0
	local puffClock = 0
	local previousMouse = false
	local blink = 0

	local function release()
		local was = holding
		holding, heldInput = false, nil
		iron.Visible = false
		wire.Visible = false
		if id and was then
			remote:FireServer(id, "release")
		end
	end

	local function canHold(): boolean
		return panel.Visible
			and not howTo.Visible
			and joint >= 1
			and joint <= joints
			and phase ~= "retry"
			and phase ~= "cool"
			and phase ~= "test"
			and phase ~= "done"
	end

	local function hold(inputObject: InputObject?)
		if not canHold() or not id then
			return
		end
		holding, heldInput, heartbeat = true, inputObject, 0
		remote:FireServer(id, "hold")
		local pad = pads[joint]
		if pad then
			iron.Position = pad.Position
			wire.Position = pad.Position + UDim2.fromScale(-0.01, 0.01)
			iron.Visible = true
			wire.Visible = true
		end
	end

	local function clearBoard()
		for _, list in { pads, beads, traces, dots } :: { { Instance } } do
			for _, item in list do
				item:Destroy()
			end
			table.clear(list)
		end
		table.clear(shades)
	end

	local function buildBoard(padSpots: { Vector2 })
		clearBoard()
		-- Copper traces under the mask, from each contact to one of the chip's lower legs. Contacts and
		-- legs are paired left to right; a trace goes up from its contact, across, and up to its leg.
		-- Outer traces turn higher, so no two traces cross.
		local order = {}
		for i in padSpots do
			table.insert(order, i)
		end
		table.sort(order, function(a, b)
			return padSpots[a].X < padSpots[b].X
		end)
		local legs = { legX[2], legX[3], legX[4], legX[5] }
		local route: { { pad: number, leg: number } } = {}
		for rank, i in order do
			route[rank] = { pad = i, leg = legs[math.min(rank, #legs)] }
		end
		local function segment(x0: number, y0: number, x1: number, y1: number)
			local horizontal = math.abs(y1 - y0) < 0.001
			local seg = frame(
				boardArea,
				"Trace",
				UDim2.fromScale(
					math.min(x0, x1) - (if horizontal then 0 else 0.006),
					math.min(y0, y1) - (if horizontal then 0.009 else 0)
				),
				UDim2.fromScale(
					if horizontal then math.abs(x1 - x0) + 0.006 else 0.012,
					if horizontal then 0.018 else math.abs(y1 - y0) + 0.009
				),
				C.trace
			)
			seg.ZIndex = 1
			table.insert(traces, seg)
		end
		local left, right = {}, {}
		for _, r in route do
			table.insert(if padSpots[r.pad].X < r.leg then left else right, r)
		end
		table.sort(right, function(a, b)
			return padSpots[a.pad].X > padSpots[b.pad].X
		end)
		for _, group in { left, right } do
			for k, r in group do
				local spot = padSpots[r.pad]
				local turn = 0.36 + (k - 1) * 0.045
				segment(spot.X, turn, spot.X, spot.Y)
				segment(spot.X, turn, r.leg, turn)
				segment(r.leg, 0.315, r.leg, turn)
			end
		end

		for i, spot in padSpots do
			-- Through-hole pad: a tinned ring, the hole, and the part's lead sticking through it.
			local pad = Instance.new("TextButton")
			pad.Name = "Contact" .. i
			pad.AnchorPoint = Vector2.new(0.5, 0.5)
			pad.Position = UDim2.fromScale(spot.X, spot.Y)
			pad.Size = UDim2.fromScale(0.12, 0.12)
			pad.SizeConstraint = Enum.SizeConstraint.RelativeYY
			pad.BackgroundColor3 = C.tin
			pad.AutoButtonColor = false
			pad.Text = ""
			pad.ZIndex = 3
			round(pad)
			local ring = Instance.new("UIStroke")
			ring.Name = "Ring"
			ring.Thickness = 0
			ring.Color = C.glow
			ring.Parent = pad
			pad.Parent = boardArea
			local hole = dot(pad, "Hole", 0.5, 0.5, 0.5, Color3.fromRGB(16, 22, 18))
			hole.ZIndex = 4
			local lead = dot(pad, "Lead", 0.5, 0.5, 0.26, C.lead)
			lead.ZIndex = 4
			-- The solder: a silver dome that grows over the hole and the ring.
			local bead = dot(pad, "Solder", 0.5, 0.5, 0, Color3.new(1, 1, 1))
			bead.ZIndex = 5
			local shade = Instance.new("UIGradient")
			shade.Color = ColorSequence.new(C.solderLight, C.solderDark)
			shade.Rotation = 45
			shade.Parent = bead
			local shine = dot(bead, "Shine", 0.33, 0.3, 0.28, Color3.new(1, 1, 1))
			shine.ZIndex = 6
			shine.BackgroundTransparency = 0.15
			table.insert(traces, silk(tostring(i), spot.X + 0.035, spot.Y + 0.04, 0.04, 0.06))
			table.insert(pads, pad)
			table.insert(beads, bead)
			table.insert(shades, shade)

			pad.InputBegan:Connect(function(inputObject)
				local kind = inputObject.UserInputType
				if (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) and i == joint then
					hold(inputObject)
				end
			end)
			pad.MouseLeave:Connect(function()
				if holding and heldInput and heldInput.UserInputType == Enum.UserInputType.MouseButton1 then
					release()
				end
			end)

			local step = text(progress, "Dot" .. i, UDim2.new(), UDim2.fromScale(0.09, 1), tostring(i), 20)
			step.BackgroundColor3 = Color3.fromRGB(50, 60, 70)
			step.BackgroundTransparency = 0
			local stepAspect = Instance.new("UIAspectRatioConstraint")
			stepAspect.AspectRatio = 1
			stepAspect.Parent = step
			round(step)
			table.insert(dots, step)
		end
	end

	local function popup(at: GuiObject, content: string, color: Color3)
		local p =
			text(boardArea, "Popup", at.Position - UDim2.fromScale(0.1, 0.12), UDim2.fromScale(0.2, 0.08), content, 26)
		p.TextColor3 = color
		p.ZIndex = 9
		local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(p, info, { Position = p.Position - UDim2.fromScale(0, 0.12), TextTransparency = 1 }):Play()
		task.delay(1.2, function()
			p:Destroy()
		end)
	end

	local function puff(at: GuiObject)
		local s = frame(boardArea, "Smoke", at.Position, UDim2.fromScale(0.03, 0.04), Color3.fromRGB(220, 225, 230))
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.BackgroundTransparency = 0.4
		s.ZIndex = 7
		round(s)
		local drift = (math.random() - 0.5) * 0.06
		local info = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		TweenService:Create(s, info, {
			Position = at.Position + UDim2.fromScale(drift, -0.2),
			Size = UDim2.fromScale(0.07, 0.09),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(1, function()
			s:Destroy()
		end)
	end

	local function hide()
		if not panel.Visible then
			return
		end
		release()
		panel.Visible = false
		id = nil
		Input.MouseIconEnabled = previousMouse
		GuiService.SelectedObject = nil
	end

	local function sendClose()
		if id then
			remote:FireServer(id, "close")
		end
		hide()
	end
	closeButton.Activated:Connect(sendClose)
	actionButton.Activated:Connect(function()
		if not id then
			return
		end
		if phase == "test" then
			remote:FireServer(id, "test")
		elseif phase == "done" then
			sendClose()
		end
	end)

	local statusColor = {
		cold = C.text,
		heat = C.cold,
		flow = C.melt,
		release = C.star,
		cool = C.cold,
		retry = C.hot,
		test = C.melt,
		done = C.star,
	}

	local function starsText(n: number): string
		return string.rep("★", n) .. string.rep("☆", 3 - n)
	end

	remote.OnClientEvent:Connect(function(kind: string, state: any)
		if kind == "close" then
			if state == id then
				hide()
			end
			return
		end
		if kind ~= "state" or (id and id ~= state.id) then
			return
		end
		if not panel.Visible then
			previousMouse = Input.MouseIconEnabled
			panel.Visible = true
			title.Text = t("solder.title", { machine = t("solder.board." .. state.kind) })
			buildBoard(state.pads)
			joint, perfect = 0, 0
			for _, led in leds do
				led.BackgroundColor3 = C.ledOff
			end
			if not seenHowTo then
				seenHowTo = true
				howTo.Visible = true
			end
		end
		id = state.id
		joints = state.joints
		Input.MouseIconEnabled = true

		-- A joint was finished since the last update.
		if joint >= 1 and state.joint > joint and pads[joint] then
			local shiny = state.perfect > perfect
			popup(
				pads[joint],
				t(if shiny then "solder.pop.shiny" else "solder.pop.ok"),
				if shiny then C.star else C.text
			)
			release()
		end
		local previousPhase = phase
		joint, phase, perfect = state.joint, state.phase, state.perfect
		if phase == "retry" or phase == "cool" or phase == "test" or phase == "done" then
			release()
		end

		heat.Size = UDim2.fromScale(0.6, state.heat)
		heat.BackgroundColor3 = if state.heat >= HOT_ZONE
			then C.hot
			elseif state.heat >= Config.MeltHeat then C.melt
			else C.cold
		fillBar.Size = UDim2.fromScale(if joint <= joints then state.fill else 1, 1)

		local key = "solder.phase." .. phase
		if phase == "retry" then
			key = if state.reason == "hot" then "solder.phase.retryHot" else "solder.phase.retryEarly"
		end
		status.Text = if phase == "done" then t("solder.phase.done", { stars = starsText(state.stars) }) else t(key)
		status.TextColor3 = statusColor[phase] or C.text
		letGo.Visible = phase == "release"
		actionButton.Visible = phase == "test" or phase == "done"
		-- Leave room for the button on the right.
		status.Size = UDim2.fromScale(if actionButton.Visible then 0.62 else 0.92, 0.07)
		actionButton.Text = t(if phase == "done" then "solder.done" else "solder.test")
		hint.Text = if phase == "done"
			then t("solder.carry.fixed", { machine = t("solder.board." .. state.kind) })
			else t("solder.hint")

		if phase == "done" and previousPhase ~= "done" then
			for i, led in leds do
				task.delay(i * 0.25, function()
					led.BackgroundColor3 = C.melt
				end)
			end
		end

		for i, pad in pads do
			local finished = i < joint
			local current = i == joint
			local shiny = state.shiny[i] == true
			pad.BackgroundColor3 = if current and not finished then C.glow else C.tin
			-- The dome grows from the lead to a little past the ring. A quick release leaves it shiny.
			local bead = beads[i]
			local size = if finished then 1.08 elseif current then 0.3 + state.fill * 0.78 else 0
			bead.Size = UDim2.fromScale(size, size)
			bead.Visible = finished or (current and state.fill > 0)
			local dull = finished and not shiny
			shades[i].Color = ColorSequence.new(C.solderLight, if dull then C.solderDull else C.solderDark)
			local shine = bead:FindFirstChild("Shine") :: Frame?
			if shine then
				shine.Visible = not dull
			end
			local step = dots[i]
			if step then
				step.Text = if finished then (if shiny then "★" else "✓") else tostring(i)
				step.TextColor3 = if finished and shiny then C.star else C.text
				step.BackgroundColor3 = if finished
					then C.button
					elseif current then Color3.fromRGB(150, 110, 40)
					else Color3.fromRGB(50, 60, 70)
			end
		end
	end)

	-- Keyboard / gamepad: hold Space or A for the glowing contact.
	Input.InputBegan:Connect(function(inputObject, processed)
		if not panel.Visible then
			return
		end
		if inputObject.KeyCode == Enum.KeyCode.Escape and not processed then
			sendClose()
		elseif inputObject.KeyCode == Enum.KeyCode.Space or inputObject.KeyCode == Enum.KeyCode.ButtonA then
			if howTo.Visible then
				howTo.Visible = false
			else
				hold(inputObject)
			end
		end
	end)
	Input.InputEnded:Connect(function(inputObject)
		if
			holding
			and (
				inputObject == heldInput
				or inputObject.UserInputType == Enum.UserInputType.MouseButton1
				or inputObject.KeyCode == Enum.KeyCode.Space
				or inputObject.KeyCode == Enum.KeyCode.ButtonA
			)
		then
			release()
		end
	end)
	Input.InputChanged:Connect(function(inputObject)
		if holding and inputObject == heldInput and inputObject.UserInputType == Enum.UserInputType.Touch then
			local pad = pads[joint]
			if not pad then
				return
			end
			local p, size = pad.AbsolutePosition, pad.AbsoluteSize
			local x, y = inputObject.Position.X, inputObject.Position.Y
			if x < p.X or x > p.X + size.X or y < p.Y or y > p.Y + size.Y then
				release()
			end
		end
	end)
	Input.WindowFocusReleased:Connect(release)

	RunService.RenderStepped:Connect(function(dt)
		if not panel.Visible then
			return
		end
		blink += dt
		local pad = pads[joint]
		if pad then
			local ring = pad:FindFirstChild("Ring") :: UIStroke?
			if ring then
				ring.Thickness = if canHold() then 3 + math.sin(blink * 6) * 2 else 0
			end
		end
		letGo.Rotation = math.sin(blink * 18) * 4
		if holding and id then
			heartbeat += dt
			if heartbeat >= 0.2 then
				heartbeat = 0
				remote:FireServer(id, "hold")
			end
			ironTip.BackgroundColor3 = if phase == "flow" or phase == "release" then C.hot else C.tipCold
			puffClock += dt
			if pad and (phase == "flow" or phase == "release") and puffClock >= 0.15 then
				puffClock = 0
				puff(pad)
			end
		end
	end)

	player.CharacterAdded:Connect(sendClose)
end

return SolderClient
