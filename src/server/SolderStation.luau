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
-- client -> server (sessionId, "hold" | "release" | "test" | "close").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.SolderConfig)
local Joint = require(ReplicatedStorage.Shared.SolderJoint)
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
	state: Joint.State,
	perfect: number,
	shiny: { boolean }, -- per contact: let go in time
	retries: number,
	expires: number,
	lease: number,
	lastInput: number,
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
local dockLight: BasePart
local board: Model
local screen: TextLabel

local COLORS = {
	metal = Color3.fromRGB(88, 96, 104),
	dark = Color3.fromRGB(38, 42, 48),
	panel = Color3.fromRGB(58, 74, 92),
	green = Color3.fromRGB(32, 112, 70),
	gold = Color3.fromRGB(205, 160, 70),
	ready = Color3.fromRGB(80, 220, 120),
	hot = Color3.fromRGB(255, 140, 40),
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

local function surfaceText(target: BasePart, text: string, color: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	return label
end

-- Local space of the bench: origin on the floor under the middle of the desk, -Z is the front
-- (where the player stands), +Y is up.
local function build(origin: CFrame)
	bench = Instance.new("Model")
	bench.Name = "MB_SolderStation"
	local at = function(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- Desk with a shelf, legs and a back panel.
	local top = part(bench, "Desk", Vector3.new(8, 0.3, 3.4), at(0, 3.2, 0), COLORS.metal, Enum.Material.DiamondPlate)
	top.CanCollide = true
	benchPart = top
	bench.PrimaryPart = top
	for _, x in { -3.7, 3.7 } do
		for _, z in { -1.5, 1.5 } do
			part(bench, "Leg", Vector3.new(0.3, 3.05, 0.3), at(x, 1.525, z), COLORS.dark, Enum.Material.Metal).CanCollide =
				true
		end
	end
	part(bench, "Shelf", Vector3.new(7.6, 0.2, 3), at(0, 0.9, 0), COLORS.dark, Enum.Material.Metal)
	local back = part(bench, "BackPanel", Vector3.new(8, 4, 0.2), at(0, 5.35, 1.6), COLORS.panel, Enum.Material.Metal)
	local sign = part(bench, "Sign", Vector3.new(5, 0.8, 0.05), at(0, 6.8, 1.47), COLORS.dark)
	surfaceText(sign, Strings.get("solder.bench.sign", "en"), Color3.fromRGB(255, 214, 120))
	-- Tool marks on the panel: a few hanging tools.
	part(bench, "Pliers", Vector3.new(0.15, 1.1, 0.1), at(2.4, 5.4, 1.45), COLORS.dark)
	part(bench, "Cutter", Vector3.new(0.15, 0.9, 0.1), at(2.9, 5.5, 1.45), Color3.fromRGB(190, 60, 50))
	part(bench, "Screwdriver", Vector3.new(0.12, 1.2, 0.1), at(3.4, 5.35, 1.45), Color3.fromRGB(240, 190, 60))
	back.CanCollide = true

	-- Iron controller with a small screen.
	part(bench, "IronUnit", Vector3.new(1.6, 0.9, 1.2), at(-2.6, 3.8, 0.5), COLORS.dark)
	local screenPart = part(bench, "Screen", Vector3.new(1.1, 0.4, 0.05), at(-2.6, 3.95, -0.12), Color3.new(0, 0, 0))
	screenPart.Material = Enum.Material.Neon
	screenPart.Color = Color3.fromRGB(10, 30, 20)
	screen = surfaceText(screenPart, Strings.get("solder.bench.ready", "en"), COLORS.ready)
	part(
		bench,
		"Knob",
		Vector3.new(0.12, 0.3, 0.3),
		at(-2.6, 3.6, -0.13) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(200, 60, 50),
		nil,
		Enum.PartType.Cylinder
	)

	-- Charging dock for the cordless iron: the ring glows orange while it heats, green when ready.
	part(bench, "DockBase", Vector3.new(1, 0.2, 1), at(-1.2, 3.45, 0.5), COLORS.dark)
	dockLight = part(
		bench,
		"DockLight",
		Vector3.new(0.1, 0.8, 0.8),
		at(-1.2, 3.56, 0.5) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.ready,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	part(
		bench,
		"DockSpring",
		Vector3.new(0.9, 0.35, 0.35),
		at(-1.2, 3.9, 0.5) * CFrame.Angles(0, 0, math.rad(60)),
		Color3.fromRGB(170, 175, 180),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)

	-- Cordless iron: handle + hot tip. One model moved between the dock and the board.
	iron = Instance.new("Model")
	iron.Name = "Iron"
	ironDock = at(-1.2, 4.05, 0.5) * CFrame.Angles(0, 0, math.rad(-30))
	ironWork = at(0.55, 4.55, -0.55) * CFrame.Angles(math.rad(-35), 0, math.rad(-35))
	local handle = part(
		iron,
		"Handle",
		Vector3.new(1.3, 0.26, 0.26),
		ironDock * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(40, 120, 200),
		nil,
		Enum.PartType.Cylinder
	)
	tip = part(
		iron,
		"Tip",
		Vector3.new(0.5, 0.08, 0.08),
		ironDock * CFrame.new(0, -0.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(170, 170, 175),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	tipLight = Instance.new("PointLight")
	tipLight.Color = COLORS.hot
	tipLight.Range = 4
	tipLight.Brightness = 2
	tipLight.Enabled = false
	tipLight.Parent = tip
	iron.PrimaryPart = handle
	iron.Parent = bench
	-- Keep the tip glued to the handle when the iron moves.
	iron:SetAttribute("TipOffset", handle.CFrame:ToObjectSpace(tip.CFrame).Position)

	-- "Helping hands" board holder, with the board that appears while someone works.
	part(bench, "HolderBase", Vector3.new(1.2, 0.15, 0.8), at(0.8, 3.43, -0.3), COLORS.dark)
	part(bench, "HolderArm", Vector3.new(0.1, 0.6, 0.1), at(0.3, 3.75, -0.3), Color3.fromRGB(170, 175, 180))
	part(bench, "HolderArm", Vector3.new(0.1, 0.6, 0.1), at(1.3, 3.75, -0.3), Color3.fromRGB(170, 175, 180))
	board = Instance.new("Model")
	board.Name = "Board"
	local boardCf = at(0.8, 4.1, -0.3) * CFrame.Angles(math.rad(-50), 0, 0)
	part(board, "Pcb", Vector3.new(1.6, 0.06, 1.1), boardCf, COLORS.green)
	part(board, "Chip", Vector3.new(0.5, 0.06, 0.35), boardCf * CFrame.new(0, 0.06, 0.15), COLORS.dark)
	for i = 1, 4 do
		part(
			board,
			"Pad",
			Vector3.new(0.14, 0.04, 0.14),
			boardCf * CFrame.new(-0.5 + (i - 1) / 3, 0.05, -0.3),
			COLORS.gold
		)
	end
	board.Parent = bench

	-- Sponge to clean the tip, a solder spool, a lamp.
	part(bench, "SpongeTray", Vector3.new(0.9, 0.1, 0.7), at(-2.6, 3.4, -0.9), COLORS.dark)
	part(
		bench,
		"Sponge",
		Vector3.new(0.7, 0.22, 0.5),
		at(-2.6, 3.55, -0.9),
		Color3.fromRGB(240, 210, 70),
		Enum.Material.Foil
	)
	part(
		bench,
		"SolderSpool",
		Vector3.new(0.4, 0.7, 0.7),
		at(2.6, 3.72, 0.6),
		Color3.fromRGB(200, 205, 210),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	part(bench, "LampPost", Vector3.new(0.12, 2.2, 0.12), at(3.4, 4.45, 1), COLORS.dark)
	part(bench, "LampArm", Vector3.new(0.12, 0.12, 1.6), at(3.4, 5.5, 0.25), COLORS.dark)
	local lampHead = part(
		bench,
		"LampHead",
		Vector3.new(0.7, 0.25, 0.7),
		at(3.4, 5.4, -0.5),
		Color3.fromRGB(255, 244, 214),
		Enum.Material.Neon
	)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 70
	spot.Range = 9
	spot.Brightness = 1.5
	spot.Color = Color3.fromRGB(255, 240, 210)
	spot.Parent = lampHead

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

local function moveIron(working: boolean)
	local handle = iron.PrimaryPart :: BasePart
	local target = if working then ironWork else ironDock
	handle.CFrame = target * CFrame.Angles(0, 0, math.rad(90))
	local offset = iron:GetAttribute("TipOffset")
	if typeof(offset) == "Vector3" then
		tip.CFrame = handle.CFrame * CFrame.new(offset)
	end
end

local function showBench(active: Session?)
	local working = active ~= nil and not active.done
	moveIron(working)
	for _, p in board:GetChildren() do
		if p:IsA("BasePart") then
			p.Transparency = if active then 0 else 1
		end
	end
	bench:SetAttribute("InUse", active ~= nil)
	local hot = active ~= nil and active.state.heat >= Config.MeltHeat
	tip.Material = if hot then Enum.Material.Neon else Enum.Material.Metal
	tip.Color = if hot then COLORS.hot else Color3.fromRGB(170, 170, 175)
	tipLight.Enabled = hot
	dockLight.Color = if working then COLORS.hot else COLORS.ready
	screen.Text = Strings.get(if working then "solder.bench.busy" else "solder.bench.ready", "en")
	screen.TextColor3 = if working then COLORS.hot else COLORS.ready
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
	if s.retries == 0 and s.perfect >= s.joints - 1 then
		return 3
	elseif s.retries <= 2 then
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
		phase = if s.done then "done" else s.state.phase,
		heat = s.state.heat,
		fill = s.state.fill,
		reason = s.state.reason,
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
		state = Joint.new(),
		perfect = 0,
		shiny = {},
		retries = 0,
		expires = os.clock() + Config.Timeout,
		lease = 0,
		lastInput = 0,
		done = false,
	}
	session = s
	showBench(s)
	send(s)
end

local function onEvent(player: Player, id: unknown, action: unknown)
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
	if action == "release" then
		s.state.holding = false
		return
	end
	local now = os.clock()
	if now - s.lastInput < 0.05 then
		return
	end
	s.lastInput = now
	local phase = s.state.phase
	if action == "hold" and s.joint <= s.joints and not s.done then
		if phase == "retry" or phase == "cool" or phase == "solid" then
			return
		end
		s.state.holding = true
		s.lease = now + Config.HoldLease
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

local function step(dt: number)
	local s = session
	if not s then
		return
	end
	local now = os.clock()
	if now > s.expires or not nearby(s.player) or SolderStation.carrying(s.player) ~= s.kind then
		close(s.player)
		return
	end
	if s.done or s.joint > s.joints then
		return
	end
	if now > s.lease then
		s.state.holding = false
	end
	local before = s.state.phase
	Joint.step(s.state, math.min(dt, Config.HoldLease))
	if s.state.phase == "retry" and before ~= "retry" then
		s.retries += 1
	end
	if s.state.phase == "solid" then
		if s.state.perfect then
			s.perfect += 1
		end
		s.shiny[s.joint] = s.state.perfect
		s.joint += 1
		s.state = Joint.new()
		if s.joint > s.joints then
			s.state.phase = "test"
		end
	end
	showBench(s)
	send(s)
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
		local previous = os.clock()
		while true do
			task.wait(Config.UpdateSeconds)
			local now = os.clock()
			step(now - previous)
			previous = now
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
