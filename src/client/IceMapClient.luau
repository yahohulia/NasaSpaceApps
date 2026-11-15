--!strict
-- Full-screen ice map opened from the science console (part tagged IceMapConsole).
-- Zoom levels: 1 = all of Mars (NASA map), 2 = Arcadia Planitia (the box on the NASA map),
-- 3 = our landing zone (game map) with ice spots and the base's guess for each.
-- Real data and quotes: kb/data/ice-map.md. Read-only view, no server state.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local IceMapConfig = require(ReplicatedStorage.Shared.IceMapConfig)
local Strings = require(ReplicatedStorage.Shared.Strings)

local IceMapClient = {}

local MAX_LEVEL = 3
local TWEEN = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BG = Color3.fromRGB(16, 20, 30)
local TEXT = Color3.fromRGB(232, 236, 244)
local ACCENT = Color3.fromRGB(255, 220, 120)

local function label(parent: Instance, text: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = color or TEXT
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = Color3.fromRGB(44, 52, 74)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 22
	b.TextColor3 = TEXT
	b.Text = text
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = b
	return b
end

function IceMapClient.start()
	local player = Players.LocalPlayer
	local lang = Strings.langFromLocale(player.LocaleId)
	local function t(key: string, vars: { [string]: string | number }?): string
		return Strings.get(key, lang, vars)
	end
	local W, H = IceMapConfig.ImageSize.X, IceMapConfig.ImageSize.Y

	-- Window -------------------------------------------------------------------------------
	local gui = Instance.new("ScreenGui")
	gui.Name = "IceMap"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	local window = Instance.new("Frame")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.9, 0.88)
	window.BackgroundColor3 = BG
	window.Parent = gui
	local wc = Instance.new("UICorner")
	wc.CornerRadius = UDim.new(0, 10)
	wc.Parent = window

	local title = label(window, t("icemap.title"), 26, ACCENT)
	title.Font = Enum.Font.GothamBold
	title.Position = UDim2.fromOffset(20, 10)
	title.Size = UDim2.new(1, -200, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local levelName = label(window, "", 18)
	levelName.Position = UDim2.fromOffset(20, 44)
	levelName.Size = UDim2.new(1, -200, 0, 24)
	levelName.TextXAlignment = Enum.TextXAlignment.Left

	local close = button(window, "✕")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 12)
	close.Size = UDim2.fromOffset(44, 44)

	local zoomOut = button(window, "−")
	zoomOut.AnchorPoint = Vector2.new(1, 0)
	zoomOut.Position = UDim2.new(1, -112, 0, 12)
	zoomOut.Size = UDim2.fromOffset(44, 44)
	local zoomIn = button(window, "+")
	zoomIn.AnchorPoint = Vector2.new(1, 0)
	zoomIn.Position = UDim2.new(1, -64, 0, 12)
	zoomIn.Size = UDim2.fromOffset(44, 44)

	-- The viewport keeps the NASA image aspect, so zoom is just scaling the image inside it.
	local viewport = Instance.new("Frame")
	viewport.Name = "Viewport"
	viewport.AnchorPoint = Vector2.new(0.5, 0)
	viewport.Position = UDim2.new(0.5, 0, 0, 76)
	viewport.Size = UDim2.new(1, -40, 1, -170)
	viewport.BackgroundColor3 = Color3.new(0, 0, 0)
	viewport.ClipsDescendants = true
	viewport.Parent = window
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = W / H
	aspect.Parent = viewport

	local image = Instance.new("ImageLabel")
	image.Name = "NasaMap"
	image.BackgroundTransparency = 1
	image.Image = IceMapConfig.Image
	image.ScaleType = Enum.ScaleType.Stretch
	image.Size = UDim2.fromScale(1, 1)
	image.Parent = viewport

	-- The marker lives inside the image (scale coords), so it zooms with it.
	local here = Instance.new("Frame")
	here.AnchorPoint = Vector2.new(0.5, 0.5)
	here.Position = UDim2.fromScale(IceMapConfig.HerePixel.X / W, IceMapConfig.HerePixel.Y / H)
	here.Size = UDim2.fromOffset(16, 16)
	here.BackgroundColor3 = ACCENT
	here.Parent = image
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(1, 0)
	hc.Parent = here
	local hereText = label(here, t("icemap.here"), 16, ACCENT)
	hereText.Font = Enum.Font.GothamBold
	hereText.AnchorPoint = Vector2.new(0, 0.5)
	hereText.Position = UDim2.new(1, 6, 0.5, 0)
	hereText.Size = UDim2.fromOffset(160, 20)
	hereText.TextXAlignment = Enum.TextXAlignment.Left
	hereText.TextStrokeTransparency = 0.3

	-- Level 3: our landing zone (game map) -------------------------------------------------
	local zone = Instance.new("Frame")
	zone.Name = "Zone"
	zone.Size = UDim2.fromScale(1, 1)
	zone.BackgroundColor3 = BG
	zone.BackgroundTransparency = 0
	zone.Visible = false
	zone.Parent = viewport

	local square = Instance.new("Frame")
	square.AnchorPoint = Vector2.new(0.5, 0.5)
	square.Position = UDim2.fromScale(0.5, 0.5)
	square.Size = UDim2.fromScale(0.9, 0.9)
	square.BackgroundColor3 = Color3.fromRGB(176, 96, 60)
	square.Parent = zone
	local sq = Instance.new("UIAspectRatioConstraint")
	sq.AspectRatio = 1
	sq.Parent = square
	local mountains = Instance.new("UIStroke")
	mountains.Color = Color3.fromRGB(96, 52, 38)
	mountains.Thickness = 10
	mountains.Parent = square

	local zoneInfo = label(zone, t("icemap.zone.nasa"), 16)
	zoneInfo.Position = UDim2.fromOffset(10, 8)
	zoneInfo.Size = UDim2.new(0.25, 0, 0.5, 0)
	zoneInfo.TextXAlignment = Enum.TextXAlignment.Left
	zoneInfo.TextYAlignment = Enum.TextYAlignment.Top
	local zoneNote = label(zone, t("icemap.deposit.note"), 15, Color3.fromRGB(190, 196, 210))
	zoneNote.AnchorPoint = Vector2.new(1, 0)
	zoneNote.Position = UDim2.new(1, -10, 0, 8)
	zoneNote.Size = UDim2.new(0.22, 0, 0.5, 0)
	zoneNote.TextXAlignment = Enum.TextXAlignment.Right
	zoneNote.TextYAlignment = Enum.TextYAlignment.Top

	local half = IceMapConfig.ZoneHalfSize
	local function toSquare(p: Vector3): UDim2
		-- world +X = right, world -Z = up on the map
		return UDim2.fromScale((p.X + half) / (2 * half), (p.Z + half) / (2 * half))
	end

	local function dot(pos: Vector3, color: Color3, size: number, text: string)
		local d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Position = toSquare(pos)
		d.Size = UDim2.fromOffset(size, size)
		d.BackgroundColor3 = color
		d.Parent = square
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = d
		local l = label(d, text, 15)
		l.Font = Enum.Font.GothamBold
		l.AnchorPoint = Vector2.new(0, 0.5)
		l.Position = UDim2.new(1, 6, 0.5, 0)
		l.Size = UDim2.fromOffset(230, 36)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextStrokeTransparency = 0.4
	end

	local zoneDrawn = false
	local function drawZone()
		if zoneDrawn then
			return
		end
		zoneDrawn = true
		for _, mark in IceMapConfig.Landmarks do
			local m = workspace:FindFirstChild(mark.model)
			if m and m:IsA("Model") then
				local cf = m:GetBoundingBox()
				dot(cf.Position, Color3.fromRGB(235, 235, 240), 14, t(mark.key))
			end
		end
		local byName: { [string]: BasePart } = {}
		for _, inst in CollectionService:GetTagged("MB_Drill") do
			if inst:IsA("BasePart") then
				byName[inst.Name] = inst
			end
		end
		for _, dep in IceMapConfig.Deposits do
			local site = byName[dep.site]
			if site then
				dot(
					site.Position,
					Color3.fromRGB(110, 190, 255),
					16,
					t("icemap.deposit", { name = dep.label, chance = dep.chance })
				)
			end
		end
	end

	-- Footer: legend + credit ---------------------------------------------------------------
	local legend = label(window, t("icemap.legend"), 16)
	legend.AnchorPoint = Vector2.new(0.5, 1)
	legend.Position = UDim2.new(0.5, 0, 1, -40)
	legend.Size = UDim2.new(1, -40, 0, 46)

	local credit =
		label(window, t("icemap.credit", { credit = IceMapConfig.Credit, date = IceMapConfig.ArchivedDate }), 14)
	credit.TextColor3 = Color3.fromRGB(170, 176, 190)
	credit.AnchorPoint = Vector2.new(0.5, 1)
	credit.Position = UDim2.new(0.5, 0, 1, -12)
	credit.Size = UDim2.new(1, -40, 0, 22)

	-- Zoom ---------------------------------------------------------------------------------
	local level = 1
	local function imageTarget(lvl: number): (UDim2, UDim2)
		if lvl == 1 then
			return UDim2.fromScale(1, 1), UDim2.fromScale(0, 0)
		end
		local v = IceMapConfig.ArcadiaView
		local s = W / v.width
		local viewH = v.width * H / W
		return UDim2.fromScale(s, s), UDim2.fromScale(-(v.cx - v.width / 2) / W * s, -(v.cy - viewH / 2) / H * s)
	end

	local function setLevel(lvl: number)
		level = math.clamp(lvl, 1, MAX_LEVEL)
		levelName.Text = t("icemap.level." .. level)
		local size, pos = imageTarget(level)
		TweenService:Create(image, TWEEN, { Size = size, Position = pos }):Play()
		here.Visible = level < 3
		if level == 3 then
			drawZone()
		end
		zone.Visible = level == 3
		zoneInfo.Visible = level == 3
		legend.Text = if level == 3 then t("icemap.hint") else t("icemap.legend")
		zoomOut.Active = level > 1
		zoomIn.Active = level < MAX_LEVEL
		zoomOut.TextTransparency = if level > 1 then 0 else 0.6
		zoomIn.TextTransparency = if level < MAX_LEVEL then 0 else 0.6
	end

	local function open()
		gui.Enabled = true
		setLevel(1)
	end
	local function closeMap()
		gui.Enabled = false
	end

	close.Activated:Connect(closeMap)
	zoomIn.Activated:Connect(function()
		setLevel(level + 1)
	end)
	zoomOut.Activated:Connect(function()
		setLevel(level - 1)
	end)
	viewport.InputChanged:Connect(function(input)
		if gui.Enabled and input.UserInputType == Enum.UserInputType.MouseWheel then
			setLevel(level + (if input.Position.Z > 0 then 1 else -1))
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if gui.Enabled and not processed and input.KeyCode == Enum.KeyCode.Escape then
			closeMap()
		end
	end)

	-- Console prompt (made on this client only) --------------------------------------------
	local function bindConsole(inst: Instance)
		if not inst:IsA("BasePart") or inst:FindFirstChild("IceMapPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "IceMapPrompt"
		prompt.ActionText = t("icemap.prompt.open")
		prompt.ObjectText = t("icemap.object")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = IceMapConfig.PromptDistance
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			if gui.Enabled then
				closeMap()
			else
				open()
			end
		end)
		prompt.Parent = inst
	end
	for _, inst in CollectionService:GetTagged(IceMapConfig.ConsoleTag) do
		bindConsole(inst)
	end
	CollectionService:GetInstanceAddedSignal(IceMapConfig.ConsoleTag):Connect(bindConsole)
end

return IceMapClient
