--!strict
-- Soldering station: a 3D bench where a player fixes a broken circuit board in a short mini game.
-- Any machine can use it. The machine gives the player a broken board (SolderStation.giveBoard),
-- the player carries it to the bench and solders it, then brings the fixed board back
-- (SolderStation.takeBoard). Board kinds and their joint counts are in SolderConfig.Boards.
--
-- The bench is built here from parts, at Workspace.MB_Interactables.MB_SolderStation (an anchor
-- part World can place in Studio) or at SolderConfig.StationCFrame.
--
-- Player attribute: CarryingBoard = "<kind>" (broken) or "<kind>:fixed"; nil = empty hands.
-- Remote ReplicatedStorage.Solder: server -> client "state" / "close";
-- client -> server (sessionId, "start", contact) | (sessionId, "joint", contact, shiny) |
-- (sessionId, "test") | (sessionId, "close").
-- Each contact is a catch-the-drop game (SolderSlider) played on the client so it feels instant;
-- the server checks the order of contacts and that each one took a believable time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.SolderConfig)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Notice = require(script.Parent.Notice)

local SolderStation = {}

type Session = {
	id: string,
	player: Player,
	kind: string,
	joints: number,
	joint: number, -- the contact being soldered now; joints + 1 = all done
	pads: { Vector2 }, -- contact positions on the board, 0..1
	startedAt: number?, -- when the current contact's game started (nil = not started)
	perfect: number,
	shiny: { boolean }, -- per contact: the drop was never lost
	expires: number,
	done: boolean,
}

local remote: RemoteEvent
local bench: Model
local benchPart: BasePart
local session: Session? = nil
local lostHandlers: { [string]: (player: Player, fixed: boolean) -> () } = {}

-- Bench visuals that change with the session.
local iron: Model
local ironDock: CFrame
local ironWork: CFrame
local tip: BasePart
local tipLight: PointLight
local tipSmoke: ParticleEmitter
local dockLight: BasePart
local board: Model
local screen: TextLabel
local heatBar: Frame
local fanLed: BasePart

local COLORS = {
	metal = Color3.fromRGB(88, 96, 104),
	steel = Color3.fromRGB(176, 182, 188),
	dark = Color3.fromRGB(38, 42, 48),
	panel = Color3.fromRGB(58, 74, 92),
	green = Color3.fromRGB(22, 104, 62),
	gold = Color3.fromRGB(205, 160, 70),
	ready = Color3.fromRGB(80, 220, 120),
	hot = Color3.fromRGB(255, 140, 40),
	mat = Color3.fromRGB(52, 92, 112),
	grip = Color3.fromRGB(40, 120, 200),
}

-- Building the 3D bench ----------------------------------------------------------------------------

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
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
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- A cylinder from `a` to `b` (Roblox cylinders lie along X).
local function rod(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	color: Color3,
	material: Enum.Material?
): Part
	return part(
		parent,
		name,
		Vector3.new((b - a).Magnitude, width, width),
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
		color,
		material,
		Enum.PartType.Cylinder
	)
end

local function surfaceGui(target: BasePart, face: Enum.NormalId, pixels: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels
	gui.LightInfluence = 0
	gui.Parent = target
	return gui
end

local function surfaceText(target: BasePart, text: string, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = surfaceGui(target, Enum.NormalId.Front, 60)
	return label
end

-- CFrame at `pivot` whose -Y axis points along `dir` (the iron is built tip-down along -Y).
local function pointing(pivot: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(pivot, pivot + dir.Unit) * CFrame.Angles(math.rad(90), 0, 0)
end

-- Cordless iron: cable sleeve, grip with rubber rings, steel collar and shaft, hot tip.
local function buildIron(pivot: CFrame): Attachment
	iron = Instance.new("Model")
	iron.Name = "Iron"
	local function along(y: number): CFrame
		return pivot * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
	end
	part(iron, "Sleeve", Vector3.new(0.35, 0.14, 0.14), along(0.62), COLORS.dark, nil, Enum.PartType.Cylinder)
	part(iron, "Grip", Vector3.new(0.9, 0.28, 0.28), along(0), COLORS.grip, nil, Enum.PartType.Cylinder)
	for i, y in { -0.25, -0.05, 0.15 } do
		part(iron, "Ring" .. i, Vector3.new(0.06, 0.3, 0.3), along(y), COLORS.dark, nil, Enum.PartType.Cylinder)
	end
	part(
		iron,
		"Collar",
		Vector3.new(0.16, 0.2, 0.2),
		along(-0.53),
		COLORS.steel,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	part(
		iron,
		"Shaft",
		Vector3.new(0.6, 0.09, 0.09),
		along(-0.9),
		COLORS.steel,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	tip = part(
		iron,
		"Tip",
		Vector3.new(0.25, 0.05, 0.05),
		along(-1.32),
		Color3.fromRGB(150, 120, 70),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	tipLight = Instance.new("PointLight")
	tipLight.Color = COLORS.hot
	tipLight.Range = 4
	tipLight.Brightness = 2
	tipLight.Enabled = false
	tipLight.Parent = tip
	-- Flux smoke rises from the joint while the solder melts.
	tipSmoke = Instance.new("ParticleEmitter")
	tipSmoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	tipSmoke.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
	tipSmoke.Transparency = NumberSequence.new(0.5, 1)
	tipSmoke.Size = NumberSequence.new(0.1, 0.5)
	tipSmoke.Lifetime = NumberRange.new(0.8, 1.4)
	tipSmoke.Rate = 12
	tipSmoke.Speed = NumberRange.new(0.1, 0.3)
	tipSmoke.Acceleration = Vector3.new(0, 1.5, 0)
	tipSmoke.LockedToPart = false
	tipSmoke.Enabled = false
	tipSmoke.Parent = tip
	iron.WorldPivot = pivot
	local cableEnd = Instance.new("Attachment")
	cableEnd.Name = "CableEnd"
	cableEnd.Parent = iron:FindFirstChild("Sleeve")
	cableEnd.Position = Vector3.new(0.17, 0, 0)
	cableEnd.Axis = Vector3.new(1, 0, 0)
	return cableEnd
end

-- Local space of the bench: origin on the floor under the middle of the desk, -Z is the front
-- (where the player stands), +Y is up. The desk top is at y = 3.35.
local function build(origin: CFrame)
	bench = Instance.new("Model")
	bench.Name = "MB_SolderStation"
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local function pos(x: number, y: number, z: number): Vector3
		return at(x, y, z).Position
	end

	-- Desk: diamond-plate top, front trim, legs, a shelf with two storage bins.
	local top = part(bench, "Desk", Vector3.new(8, 0.3, 3.4), at(0, 3.2, 0), COLORS.metal, Enum.Material.DiamondPlate)
	top.CanCollide = true
	benchPart = top
	bench.PrimaryPart = top
	part(bench, "Trim", Vector3.new(8.05, 0.14, 0.14), at(0, 3.2, -1.72), Color3.fromRGB(240, 190, 50))
	for _, x in { -3.7, 3.7 } do
		for _, z in { -1.5, 1.5 } do
			part(bench, "Leg", Vector3.new(0.3, 3.05, 0.3), at(x, 1.525, z), COLORS.dark, Enum.Material.Metal).CanCollide =
				true
		end
	end
	part(bench, "Shelf", Vector3.new(7.6, 0.2, 3), at(0, 0.9, 0), COLORS.dark, Enum.Material.Metal)
	part(bench, "BinA", Vector3.new(1.6, 0.8, 1.2), at(-2.4, 1.4, 0.3), Color3.fromRGB(230, 120, 40))
	part(bench, "BinB", Vector3.new(1.6, 0.8, 1.2), at(-0.5, 1.4, 0.3), Color3.fromRGB(60, 120, 200))

	-- Anti-static work mat.
	part(bench, "Mat", Vector3.new(6.4, 0.04, 2.6), at(0.3, 3.37, -0.15), COLORS.mat)

	-- Pegboard with tools, small part drawers and the sign.
	local peg = part(bench, "Pegboard", Vector3.new(8, 3.6, 0.15), at(0, 5.15, 1.62), Color3.fromRGB(196, 172, 128))
	peg.CanCollide = true
	local holes = Instance.new("Frame")
	holes.Size = UDim2.fromScale(1, 1)
	holes.BackgroundTransparency = 1
	holes.Parent = surfaceGui(peg, Enum.NormalId.Front, 20)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(3, 3)
	grid.CellPadding = UDim2.fromOffset(7, 7)
	grid.Parent = holes
	for _ = 1, 15 * 7 do
		local hole = Instance.new("Frame")
		hole.BackgroundColor3 = Color3.fromRGB(110, 92, 64)
		hole.BorderSizePixel = 0
		hole.Parent = holes
	end
	local sign = part(bench, "Sign", Vector3.new(5, 0.75, 0.06), at(0, 6.6, 1.52), COLORS.dark)
	surfaceText(sign, Strings.get("solder.bench.sign", "en"), Color3.fromRGB(255, 214, 120))
	-- Pliers, cutters, screwdriver and tweezers on hooks.
	rod(bench, "PliersJawA", pos(-3.2, 5.6, 1.5), pos(-3.3, 5.1, 1.5), 0.08, COLORS.steel, Enum.Material.Metal)
	rod(bench, "PliersJawB", pos(-3.0, 5.6, 1.5), pos(-2.9, 5.1, 1.5), 0.08, COLORS.steel, Enum.Material.Metal)
	rod(bench, "PliersGripA", pos(-3.3, 5.1, 1.5), pos(-3.45, 4.4, 1.5), 0.13, Color3.fromRGB(200, 50, 45))
	rod(bench, "PliersGripB", pos(-2.9, 5.1, 1.5), pos(-2.75, 4.4, 1.5), 0.13, Color3.fromRGB(200, 50, 45))
	rod(bench, "DriverShaft", pos(-2.3, 5.8, 1.5), pos(-2.3, 5.0, 1.5), 0.06, COLORS.steel, Enum.Material.Metal)
	rod(bench, "DriverGrip", pos(-2.3, 5.0, 1.5), pos(-2.3, 4.4, 1.5), 0.2, Color3.fromRGB(240, 190, 60))
	rod(bench, "TweezerA", pos(-1.8, 5.7, 1.5), pos(-1.85, 4.7, 1.5), 0.05, COLORS.steel, Enum.Material.Metal)
	rod(bench, "TweezerB", pos(-1.8, 5.7, 1.5), pos(-1.72, 4.7, 1.5), 0.05, COLORS.steel, Enum.Material.Metal)
	for row = 0, 1 do
		for col = 0, 2 do
			local drawer = part(
				bench,
				"Drawer",
				Vector3.new(0.55, 0.35, 0.4),
				at(2.1 + col * 0.62, 4.35 + row * 0.42, 1.38),
				Color3.fromRGB(70, 140, 190)
			)
			drawer.Transparency = 0.25
			part(
				bench,
				"Handle",
				Vector3.new(0.2, 0.05, 0.05),
				drawer.CFrame * CFrame.new(0, 0, -0.22),
				Color3.new(1, 1, 1)
			)
		end
	end

	-- Iron station: body, screen with a heat bar, knob and a power LED.
	local unit = part(bench, "IronUnit", Vector3.new(1.5, 0.8, 1.1), at(-2.8, 3.77, 0.45), COLORS.dark)
	local screenPart =
		part(bench, "Screen", Vector3.new(1.05, 0.38, 0.04), at(-2.8, 3.9, -0.12), Color3.fromRGB(8, 20, 14))
	local screenGui = surfaceGui(screenPart, Enum.NormalId.Front, 80)
	screen = Instance.new("TextLabel")
	screen.Size = UDim2.fromScale(1, 0.62)
	screen.BackgroundTransparency = 1
	screen.Font = Enum.Font.Code
	screen.TextScaled = true
	screen.TextColor3 = COLORS.ready
	screen.Text = Strings.get("solder.bench.ready", "en")
	screen.Parent = screenGui
	local barTrack = Instance.new("Frame")
	barTrack.Position = UDim2.fromScale(0.08, 0.7)
	barTrack.Size = UDim2.fromScale(0.84, 0.18)
	barTrack.BackgroundColor3 = Color3.fromRGB(30, 50, 40)
	barTrack.BorderSizePixel = 0
	barTrack.Parent = screenGui
	heatBar = Instance.new("Frame")
	heatBar.Size = UDim2.fromScale(0, 1)
	heatBar.BackgroundColor3 = COLORS.hot
	heatBar.BorderSizePixel = 0
	heatBar.Parent = barTrack
	part(
		bench,
		"Knob",
		Vector3.new(0.12, 0.26, 0.26),
		at(-3.3, 3.6, -0.13) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(200, 60, 50),
		nil,
		Enum.PartType.Cylinder
	)
	part(bench, "PowerLed", Vector3.new(0.08, 0.08, 0.04), at(-2.3, 3.6, -0.12), COLORS.ready, Enum.Material.Neon)
	-- Brass tip cleaner and a wet sponge.
	part(
		bench,
		"Cleaner",
		Vector3.new(0.3, 0.5, 0.5),
		at(-2.95, 3.5, -0.75) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.dark,
		nil,
		Enum.PartType.Cylinder
	)
	part(
		bench,
		"BrassWool",
		Vector3.new(0.06, 0.42, 0.42),
		at(-2.95, 3.66, -0.75) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.gold,
		Enum.Material.Foil,
		Enum.PartType.Cylinder
	)
	part(bench, "SpongeTray", Vector3.new(0.85, 0.08, 0.6), at(-2.15, 3.42, -0.8), COLORS.dark)
	part(
		bench,
		"Sponge",
		Vector3.new(0.7, 0.16, 0.48),
		at(-2.15, 3.5, -0.8),
		Color3.fromRGB(240, 210, 70),
		Enum.Material.Foil
	)

	-- Charging dock: a stand with a tube that holds the iron and a ring that glows when charged.
	local dockBase = at(-1.4, 3.42, 0.35)
	part(
		bench,
		"DockBase",
		Vector3.new(0.1, 1, 1),
		dockBase * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.dark,
		nil,
		Enum.PartType.Cylinder
	)
	dockLight = part(
		bench,
		"DockLight",
		Vector3.new(0.05, 1.04, 1.04),
		dockBase * CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.ready,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	local dockDir = (pos(-1.4, 3.6, 0.65) - pos(-1.4, 4.4, 0.1)).Unit
	local tubeTop = pos(-1.4, 4.4, 0.1)
	rod(bench, "DockTube", tubeTop, tubeTop + dockDir * 0.9, 0.34, COLORS.steel, Enum.Material.Metal)
	rod(bench, "DockArm", pos(-1.4, 3.45, 0.35), tubeTop + dockDir * 0.6, 0.08, COLORS.dark, Enum.Material.Metal)
	ironDock = pointing(tubeTop - dockDir * 0.75, dockDir)

	-- "Helping hands" holder with the board; the board shows only while someone works on it.
	part(bench, "HolderBase", Vector3.new(1.4, 0.18, 0.7), at(0.3, 3.46, -0.35), COLORS.dark, Enum.Material.Metal)
	for _, x in { -0.25, 0.85 } do
		rod(bench, "HolderRod", pos(x, 3.5, -0.3), pos(x, 4.25, -0.3), 0.07, COLORS.steel, Enum.Material.Metal)
		part(bench, "Clip", Vector3.new(0.12, 0.12, 0.3), at(x, 4.25, -0.32), Color3.fromRGB(200, 50, 45))
	end
	board = Instance.new("Model")
	board.Name = "Board"
	local boardCf = at(0.3, 4.25, -0.35) * CFrame.Angles(math.rad(-55), 0, 0)
	local function onBoard(name: string, size: Vector3, x: number, z: number, color: Color3, shape: Enum.PartType?)
		local p = part(board, name, size, boardCf * CFrame.new(x, 0.03 + size.Y / 2, z), color, nil, shape)
		return p
	end
	part(board, "Pcb", Vector3.new(1.7, 0.06, 1.15), boardCf, COLORS.green)
	onBoard("Chip", Vector3.new(0.55, 0.06, 0.3), 0, 0.25, COLORS.dark)
	for i = 0, 5 do
		onBoard("Pin", Vector3.new(0.03, 0.02, 0.06), -0.22 + i * 0.09, 0.08, COLORS.steel)
	end
	onBoard(
		"ResistorA",
		Vector3.new(0.3, 0.07, 0.07),
		-0.55,
		0.3,
		Color3.fromRGB(215, 190, 140),
		Enum.PartType.Cylinder
	)
	onBoard(
		"ResistorB",
		Vector3.new(0.3, 0.07, 0.07),
		-0.55,
		0.15,
		Color3.fromRGB(215, 190, 140),
		Enum.PartType.Cylinder
	)
	local cap = part(
		board,
		"Capacitor",
		Vector3.new(0.3, 0.2, 0.2),
		boardCf * CFrame.new(0.6, 0.18, 0.25) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(40, 70, 160),
		nil,
		Enum.PartType.Cylinder
	)
	cap.Name = "Capacitor"
	onBoard("Led", Vector3.new(0.08, 0.08, 0.08), 0.6, -0.05, Color3.fromRGB(230, 50, 40), Enum.PartType.Ball)
	for i = 0, 3 do
		onBoard("Pad", Vector3.new(0.12, 0.02, 0.12), -0.5 + i / 3, -0.3, COLORS.steel, Enum.PartType.Ball)
	end
	board.Parent = bench

	-- Fume extractor aimed at the board, with a fan grill and a green "on" light.
	local fan = part(
		bench,
		"FumeExtractor",
		Vector3.new(0.9, 0.9, 0.4),
		at(1.75, 3.85, 0.25) * CFrame.Angles(0, math.rad(-35), 0),
		COLORS.dark
	)
	local grill = Instance.new("Frame")
	grill.AnchorPoint = Vector2.new(0.5, 0.5)
	grill.Position = UDim2.fromScale(0.5, 0.5)
	grill.Size = UDim2.fromScale(0.85, 0.85)
	grill.BackgroundColor3 = Color3.fromRGB(70, 75, 82)
	grill.Parent = surfaceGui(fan, Enum.NormalId.Front, 60)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = grill
	for i = 1, 4 do
		local slat = Instance.new("Frame")
		slat.AnchorPoint = Vector2.new(0.5, 0.5)
		slat.Position = UDim2.fromScale(0.5, i / 5)
		slat.Size = UDim2.fromScale(0.9, 0.05)
		slat.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
		slat.BorderSizePixel = 0
		slat.Parent = grill
	end
	fanLed = part(
		bench,
		"FanLed",
		Vector3.new(0.08, 0.08, 0.04),
		fan.CFrame * CFrame.new(0.35, 0.37, -0.21),
		Color3.fromRGB(40, 60, 40),
		Enum.Material.Neon
	)
	part(
		bench,
		"FanFeet",
		Vector3.new(0.8, 0.08, 0.5),
		at(1.75, 3.4, 0.25) * CFrame.Angles(0, math.rad(-35), 0),
		COLORS.dark
	)

	-- Solder spool on a stand, with the wire hanging down to the mat.
	part(bench, "SpoolStand", Vector3.new(0.7, 0.12, 0.5), at(3.0, 3.41, 0.55), COLORS.dark, Enum.Material.Metal)
	rod(bench, "SpoolPost", pos(3.0, 3.45, 0.55), pos(3.0, 3.95, 0.55), 0.07, COLORS.steel, Enum.Material.Metal)
	local axle = at(3.0, 3.95, 0.55)
	part(
		bench,
		"SpoolCore",
		Vector3.new(0.4, 0.38, 0.38),
		axle,
		Color3.fromRGB(205, 210, 215),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	for _, x in { -0.21, 0.21 } do
		part(
			bench,
			"SpoolFlange",
			Vector3.new(0.05, 0.75, 0.75),
			axle * CFrame.new(x, 0, 0),
			Color3.fromRGB(200, 50, 45),
			nil,
			Enum.PartType.Cylinder
		)
	end
	rod(
		bench,
		"SolderWire",
		pos(3.0, 3.8, 0.28),
		pos(2.55, 3.4, -0.4),
		0.035,
		Color3.fromRGB(205, 210, 215),
		Enum.Material.Metal
	)

	-- Magnifier lamp: a clamp on the back, an arm and a ring light with a lens over the board.
	rod(bench, "LampPost", pos(3.55, 3.35, 1.2), pos(3.55, 6.0, 1.2), 0.12, COLORS.dark, Enum.Material.Metal)
	rod(bench, "LampArm", pos(3.55, 6.0, 1.2), pos(0.6, 5.7, -0.25), 0.1, COLORS.dark, Enum.Material.Metal)
	local head = at(0.45, 5.55, -0.4) * CFrame.Angles(0, 0, math.rad(90))
	part(
		bench,
		"LampRing",
		Vector3.new(0.12, 1.25, 1.25),
		head,
		Color3.fromRGB(255, 246, 225),
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	local lens = part(
		bench,
		"Lens",
		Vector3.new(0.14, 0.95, 0.95),
		head,
		Color3.fromRGB(190, 225, 245),
		Enum.Material.Glass,
		Enum.PartType.Cylinder
	)
	lens.Transparency = 0.45
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Left
	spot.Angle = 70
	spot.Range = 9
	spot.Brightness = 1.5
	spot.Color = Color3.fromRGB(255, 240, 210)
	spot.Parent = lens

	-- The working spot over the board: the iron comes in from the upper right.
	local joint = (boardCf * CFrame.new(0.15, 0.05, -0.3)).Position
	local workDir = (origin:VectorToWorldSpace(Vector3.new(-0.45, -0.75, 0.45))).Unit
	ironWork = pointing(joint - workDir * 1.45, workDir)

	-- Iron with a cable to the station.
	local cableEnd = buildIron(ironDock)
	local socket = Instance.new("Attachment")
	socket.Name = "CableSocket"
	socket.Position = Vector3.new(0.76, -0.1, 0)
	socket.Axis = Vector3.new(0, -1, 0)
	socket.Parent = unit
	local cable = Instance.new("Beam")
	cable.Name = "IronCable"
	cable.Attachment0 = socket
	cable.Attachment1 = cableEnd
	cable.Color = ColorSequence.new(Color3.fromRGB(20, 20, 22))
	cable.Width0, cable.Width1 = 0.07, 0.07
	cable.CurveSize0, cable.CurveSize1 = 0.8, 0.8
	cable.Segments = 16
	cable.FaceCamera = true
	cable.LightInfluence = 1
	cable.Parent = unit
	iron.Parent = bench

	-- The prompt sits on the desk. SolderClient shows it only to a player who carries a broken board.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SolderPrompt"
	prompt.ActionText = Strings.get("solder.prompt.fix", "en")
	prompt.ObjectText = Strings.get("solder.bench.name", "en")
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Distance
	prompt.RequiresLineOfSight = false
	prompt.Parent = top
	prompt.Triggered:Connect(function(player)
		SolderStation.open(player)
	end)
	bench:SetAttribute("InUse", false)
end

local function showBench(active: Session?)
	local working = active ~= nil and not active.done
	iron:PivotTo(if working then ironWork else ironDock)
	for _, p in board:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = if active then 0 else 1
		end
	end
	bench:SetAttribute("InUse", active ~= nil)
	local hot = working and active ~= nil and active.startedAt ~= nil
	tip.Material = if hot then Enum.Material.Neon else Enum.Material.Metal
	tip.Color = if hot then COLORS.hot else Color3.fromRGB(150, 120, 70)
	tipLight.Enabled = hot
	tipSmoke.Enabled = hot
	-- The ring glows green while the iron sits charged in its dock.
	dockLight.Color = if working then Color3.fromRGB(50, 55, 60) else COLORS.ready
	dockLight.Material = if working then Enum.Material.SmoothPlastic else Enum.Material.Neon
	fanLed.Color = if working then COLORS.ready else Color3.fromRGB(40, 60, 40)
	screen.Text = Strings.get(if working then "solder.bench.busy" else "solder.bench.ready", "en")
	screen.TextColor3 = if working then COLORS.hot else COLORS.ready
	heatBar.Size = UDim2.fromScale(if hot then 0.8 elseif working then 0.3 else 0, 1)
end

-- Carried boards ------------------------------------------------------------------------------------

local function boardAttr(kind: string, fixed: boolean): string
	return if fixed then kind .. ":fixed" else kind
end

-- Returns the kind of board the player carries (nil = none) and whether it is fixed.
function SolderStation.carrying(player: Player): (string?, boolean)
	local value = player:GetAttribute("CarryingBoard")
	if type(value) ~= "string" then
		return nil, false
	end
	local kind, suffix = string.match(value, "^([^:]+)(.*)$")
	return kind, suffix == ":fixed"
end

local function attachView(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("CarriedBoard")
	if old then
		old:Destroy()
	end
	local kind, fixed = SolderStation.carrying(player)
	if not kind then
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not (hand and hand:IsA("BasePart")) then
		return
	end
	local view = Instance.new("Part")
	view.Name = "CarriedBoard"
	view.Size = Vector3.new(1.2, 0.08, 0.8)
	view.Color = if fixed then COLORS.green else Color3.fromRGB(90, 70, 50)
	view.Material = Enum.Material.SmoothPlastic
	view.CanCollide = false
	view.CanTouch = false
	view.CanQuery = false
	view.Massless = true
	view.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.1, -0.3)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = hand, view
	weld.Parent = view
	if not fixed then
		local smoke = Instance.new("Smoke")
		smoke.Size, smoke.Opacity, smoke.RiseVelocity = 0.3, 0.15, 1
		smoke.Color = Color3.fromRGB(90, 90, 90)
		smoke.Parent = view
	end
	view.Parent = character
end

function SolderStation.giveBoard(player: Player, kind: string, fixed: boolean)
	player:SetAttribute("CarryingBoard", boardAttr(kind, fixed))
	attachView(player)
end

-- Takes the board out of the player's hands. Returns false if they carry none.
function SolderStation.takeBoard(player: Player): boolean
	if player:GetAttribute("CarryingBoard") == nil then
		return false
	end
	player:SetAttribute("CarryingBoard", nil)
	attachView(player)
	return true
end

-- Called when a carried board is lost (the player left or respawned): the machine takes it back.
function SolderStation.onLost(kind: string, handler: (player: Player, fixed: boolean) -> ())
	lostHandlers[kind] = handler
end

local function loseBoard(player: Player)
	local kind, fixed = SolderStation.carrying(player)
	if not kind then
		return
	end
	player:SetAttribute("CarryingBoard", nil)
	local handler = lostHandlers[kind]
	if handler then
		handler(player, fixed)
	end
end

-- The mini game -------------------------------------------------------------------------------------

local function nearby(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root ~= nil
		and root:IsA("BasePart")
		and humanoid ~= nil
		and humanoid.Health > 0
		and (root.Position - benchPart.Position).Magnitude <= Config.Distance
end

local function stars(s: Session): number
	if s.perfect >= s.joints - 1 then
		return 3
	elseif s.perfect * 2 >= s.joints then
		return 2
	end
	return 1
end

local function send(s: Session)
	remote:FireClient(s.player, "state", {
		id = s.id,
		kind = s.kind,
		joints = s.joints,
		joint = s.joint,
		pads = s.pads,
		phase = if s.done then "done" elseif s.joint > s.joints then "test" else "aim",
		perfect = s.perfect,
		shiny = s.shiny,
		stars = stars(s),
	})
end

local function close(player: Player)
	local s = session
	if not s or s.player ~= player then
		return
	end
	session = nil
	showBench(nil)
	if player.Parent == Players then
		remote:FireClient(player, "close", s.id)
	end
end

-- Random contact spots on the board: two staggered rows below the chip (so straight traces up to
-- the chip never cross another contact), shuffled, slightly jittered.
local rng = Random.new()
local function layoutPads(count: number): { Vector2 }
	local spots = {}
	for col = 0, 3 do
		table.insert(spots, Vector2.new(0.14 + col * 0.24, 0.58))
	end
	for col = 0, 2 do
		table.insert(spots, Vector2.new(0.26 + col * 0.24, 0.82))
	end
	local pads = {}
	for _ = 1, math.min(count, #spots) do
		local spot = table.remove(spots, rng:NextInteger(1, #spots)) :: Vector2
		table.insert(pads, spot + Vector2.new(rng:NextNumber(-0.02, 0.02), rng:NextNumber(-0.02, 0.02)))
	end
	return pads
end

function SolderStation.open(player: Player)
	if not nearby(player) then
		return
	end
	local active = session
	if active and active.player == player then
		send(active)
		return
	end
	if active then
		Notice.send(player, "solder.toast.busy", "warn")
		return
	end
	local kind, fixed = SolderStation.carrying(player)
	if not kind then
		Notice.send(player, "solder.toast.noBoard", "info")
		return
	end
	if fixed then
		Notice.send(player, "solder.toast.alreadyFixed", "info")
		return
	end
	local def = Config.Boards[kind]
	if not def then
		return
	end
	local s: Session = {
		id = HttpService:GenerateGUID(false),
		player = player,
		kind = kind,
		joints = def.joints,
		joint = 1,
		pads = layoutPads(def.joints),
		startedAt = nil,
		perfect = 0,
		shiny = {},
		expires = os.clock() + Config.Timeout,
		done = false,
	}
	session = s
	showBench(s)
	send(s)
end

local function onEvent(player: Player, id: unknown, action: unknown, contact: unknown, shiny: unknown)
	local s = session
	if not s or s.player ~= player or id ~= s.id or type(action) ~= "string" then
		return
	end
	if action == "close" then
		close(player)
		return
	end
	if not nearby(player) then
		close(player)
		return
	end
	local now = os.clock()
	if action == "start" and contact == s.joint and s.joint <= s.joints and not s.done then
		s.startedAt = now
		showBench(s)
	elseif action == "joint" and contact == s.joint and s.startedAt ~= nil and not s.done then
		-- A full contact takes a few seconds of catching; anything faster is not believable.
		if now - (s.startedAt :: number) < Config.MinJointSeconds then
			return
		end
		local wasShiny = shiny == true
		if wasShiny then
			s.perfect += 1
		end
		s.shiny[s.joint] = wasShiny
		s.joint += 1
		s.startedAt = nil
		showBench(s)
		send(s)
	elseif action == "test" and s.joint > s.joints and not s.done then
		s.done = true
		player:SetAttribute("CarryingBoard", boardAttr(s.kind, true))
		attachView(player)
		showBench(s)
		send(s)
		-- Leave the result on screen for a moment, then free the bench.
		task.delay(4, function()
			if session == s then
				close(player)
			end
		end)
	end
end

-- Closes the session when the player walks away, takes too long or loses the board.
local function step()
	local s = session
	if not s then
		return
	end
	local now = os.clock()
	if now > s.expires or not nearby(s.player) or SolderStation.carrying(s.player) ~= s.kind then
		close(s.player)
		return
	end
end

function SolderStation.start()
	remote = Instance.new("RemoteEvent")
	remote.Name = "Solder"
	remote.Parent = ReplicatedStorage

	local folder = workspace:FindFirstChild("MB_Interactables")
	local anchor = folder and folder:FindFirstChild("MB_SolderStation")
	local origin = Config.StationCFrame
	if anchor and anchor:IsA("BasePart") then
		-- Anchor part: its bottom face is the floor, its front face looks at the player.
		origin = anchor.CFrame * CFrame.new(0, -anchor.Size.Y / 2, 0)
		anchor.Transparency = 1
		anchor.CanCollide = false
	end
	build(origin)
	bench.Parent = folder or workspace
	showBench(nil)

	remote.OnServerEvent:Connect(onEvent)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			if session and session.player == player then
				close(player)
			end
			loseBoard(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		close(player)
		loseBoard(player)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.UpdateSeconds)
			step()
		end
	end)
end

-- Mission restart: drop all boards and free the bench (machines reset their own state).
function SolderStation.reset()
	if session then
		close(session.player)
	end
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("CarryingBoard") ~= nil then
			player:SetAttribute("CarryingBoard", nil)
			attachView(player)
		end
	end
end

return SolderStation
