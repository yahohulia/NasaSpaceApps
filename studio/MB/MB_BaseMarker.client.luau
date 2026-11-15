-- MB_BaseMarker (StarterPlayerScripts): "⌂ Base · 45 m" - how far the base entrance is.
-- Target: the airlock door (Workspace.MB_AirlockPorch; falls back to Workspace.MarsBase).
--   On screen: the label floats above the entrance.
--   Off screen: it sticks to the edge with an arrow pointing the way - only in the upper half of the
--   screen, the lower half stays free for touch controls.
--   Hidden while the player is inside the base (Player attribute IsInside).
-- Distance in metres = studs x 0.28 (Roblox avatar-scale convention, the same as the earlier HUD).
-- Copy of the script that lives in the team place (studio/MB in the repo).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local METERS_PER_STUD = 0.28
local EDGE = 16 -- px from the screen edge
local MAX_Y = 0.55 -- keep the label above this share of the screen height

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FONT = Font.new(Font.fromEnum(Enum.Font.BuilderSans).Family, Enum.FontWeight.Bold)
local TEXT = Color3.fromRGB(245, 240, 235)
local ACCENT = Color3.fromRGB(222, 168, 62)

local ICONS: { [string]: { string } } = {
	Base = { "...#...", "..###..", ".#####.", "#######", ".#...#.", ".#.#.#.", ".#.#.#." },
	Left = { "..#", ".##", "##.", ".##", "..#" },
	Right = { "#..", "##.", ".##", "##.", "#.." },
	Up = { "..#..", ".###.", "##.##" },
	Down = { "##.##", ".###.", "..#.." },
}

local function pixelIcon(rows: { string }, px: number, color: Color3): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(#rows[1] * px, #rows * px)
	for y, row in rows do
		for x = 1, #row do
			if string.sub(row, x, x) == "#" then
				local p = Instance.new("Frame")
				p.BorderSizePixel = 0
				p.BackgroundColor3 = color
				p.Size = UDim2.fromOffset(px, px)
				p.Position = UDim2.fromOffset((x - 1) * px, (y - 1) * px)
				p.Parent = f
			end
		end
	end
	return f
end

local gui = Instance.new("ScreenGui")
gui.Name = "MB_BaseMarker"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true -- positions match Camera:WorldToViewportPoint
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 4
gui.Parent = playerGui

local pill = Instance.new("Frame")
pill.Name = "Pill"
pill.AutomaticSize = Enum.AutomaticSize.XY
pill.Size = UDim2.new()
pill.BackgroundColor3 = Color3.new(0, 0, 0)
pill.BackgroundTransparency = 0.5
pill.Visible = false
pill.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = pill
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 12)
pad.PaddingTop = UDim.new(0, 4)
pad.PaddingBottom = UDim.new(0, 4)
pad.Parent = pill
local row = Instance.new("UIListLayout")
row.FillDirection = Enum.FillDirection.Horizontal
row.VerticalAlignment = Enum.VerticalAlignment.Center
row.SortOrder = Enum.SortOrder.LayoutOrder
row.Padding = UDim.new(0, 7)
row.Parent = pill

local arrows: { [string]: Frame } = {}
for i, name in { "Left", "Up", "Down" } do
	local a = pixelIcon(ICONS[name], 2, ACCENT)
	a.LayoutOrder = i -- before the icon
	a.Visible = false
	a.Parent = pill
	arrows[name] = a
end
local icon = pixelIcon(ICONS.Base, 2, ACCENT)
icon.LayoutOrder = 10
icon.Parent = pill
local label = Instance.new("TextLabel")
label.LayoutOrder = 11
label.AutomaticSize = Enum.AutomaticSize.XY
label.Size = UDim2.new()
label.BackgroundTransparency = 1
label.FontFace = FONT
label.TextSize = 15
label.TextColor3 = TEXT
label.Parent = pill
local right = pixelIcon(ICONS.Right, 2, ACCENT)
right.LayoutOrder = 20 -- after the text
right.Visible = false
right.Parent = pill
arrows.Right = right

local scale = Instance.new("UIScale")
scale.Parent = pill

local function target(): Vector3?
	local porch = workspace:FindFirstChild("MB_AirlockPorch")
	if porch and porch:IsA("Model") then
		local cf, size = porch:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y / 2 + 3, 0)
	end
	local base = workspace:FindFirstChild("MarsBase")
	if base and base:IsA("Model") then
		return base:GetPivot().Position
	end
	return nil
end

local function showArrow(which: string?)
	for name, a in arrows do
		a.Visible = name == which
	end
end

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local goal = target()
	if not (camera and root and root:IsA("BasePart") and goal) or player:GetAttribute("IsInside") == true then
		pill.Visible = false
		return
	end

	local viewport = camera.ViewportSize
	scale.Scale = math.clamp(viewport.Y / 480, 0.75, 1.6)
	local meters = math.round((goal - root.Position).Magnitude * METERS_PER_STUD)
	label.Text = `Base · {meters} m`

	local maxY = viewport.Y * MAX_Y
	local screen = camera:WorldToViewportPoint(goal)
	local onScreen = screen.Z > 0
		and screen.X >= EDGE
		and screen.X <= viewport.X - EDGE
		and screen.Y >= EDGE
		and screen.Y <= maxY

	if onScreen then
		pill.AnchorPoint = Vector2.new(0.5, 1)
		pill.Position = UDim2.fromOffset(screen.X, screen.Y)
		showArrow(nil)
	else
		-- Direction in camera space, so things behind the player still point to the correct side.
		local rel = camera.CFrame:PointToObjectSpace(goal)
		local dir = if screen.Z > 0
			then Vector2.new(screen.X - viewport.X / 2, screen.Y - viewport.Y / 2)
			else Vector2.new(rel.X, -rel.Y)
		if dir.Magnitude < 1e-3 then
			dir = Vector2.new(0, -1)
		end
		-- Pin inside the upper area: x in [EDGE, w-EDGE], y in [EDGE, maxY].
		local cx, cy = viewport.X / 2, (EDGE + maxY) / 2
		local hx, hy = viewport.X / 2 - EDGE, (maxY - EDGE) / 2
		local t = math.min(hx / math.max(math.abs(dir.X), 1e-3), hy / math.max(math.abs(dir.Y), 1e-3))
		local pin = Vector2.new(cx, cy) + dir * t
		local n = dir / math.max(math.abs(dir.X), math.abs(dir.Y))
		pill.AnchorPoint = Vector2.new(0.5 + 0.5 * n.X, 0.5 + 0.5 * n.Y)
		pill.Position = UDim2.fromOffset(pin.X, pin.Y)
		local which = if math.abs(n.X) >= math.abs(n.Y)
			then (if n.X < 0 then "Left" else "Right")
			else (if n.Y < 0 then "Up" else "Down")
		showArrow(which)
	end
	pill.Visible = true
end)
