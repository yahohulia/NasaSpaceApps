--!strict
-- Client side of the base lights (server: BaseLights.luau).
--   * Light panel: a prompt on the part tagged LightsConfig.PanelTag opens a window with an
--     On/Off switch for every room; the panel's own screen shows which rooms are lit.
--   * Inside the base: a soft colour grade and a darker Lighting.Ambient, so the lamps make
--     pools of light instead of a flat bright room. SkyClient reads Lighting attributes
--     "AmbientScale" and "OutdoorAmbientScale" (set here, local to this client).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LightsConfig = require(ReplicatedStorage.Shared.LightsConfig)
local Strings = require(ReplicatedStorage.Shared.Strings)

local BaseLightsClient = {}

local BG = Color3.fromRGB(16, 20, 30)
local ROW = Color3.fromRGB(28, 34, 48)
local TEXT = Color3.fromRGB(232, 236, 244)
local MUTED = Color3.fromRGB(150, 160, 180)
local ACCENT = Color3.fromRGB(255, 212, 140)
local ON_COLOR = Color3.fromRGB(255, 200, 110)
local OFF_COLOR = Color3.fromRGB(60, 80, 120)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

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
	b.TextSize = 20
	b.TextColor3 = TEXT
	b.Text = text
	b.Parent = parent
	corner(b, 6)
	return b
end

-- Rooms (zone parts) that have lamps: the server marks them with "LightsOn".
local function litRooms(): { { id: string, zone: BasePart } }
	local list = {}
	local base = workspace:FindFirstChild(LightsConfig.ZonesFolder[1])
	local zones = base and base:FindFirstChild(LightsConfig.ZonesFolder[2])
	if not zones then
		return list
	end
	for _, id in LightsConfig.Rooms do
		local zone = zones:FindFirstChild(id .. "Zone")
		if zone and zone:IsA("BasePart") and zone:GetAttribute("LightsOn") ~= nil then
			table.insert(list, { id = id, zone = zone })
		end
	end
	return list
end

local function zoneVolume(part: BasePart): number
	return part.Size.X * part.Size.Y * part.Size.Z
end

-- The room the player stands in (smallest zone that holds the point), or nil.
local function roomZoneAt(pos: Vector3): BasePart?
	local best: BasePart? = nil
	for _, room in litRooms() do
		local zone = room.zone
		local p = zone.CFrame:PointToObjectSpace(pos)
		local h = zone.Size / 2
		if math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z then
			if best == nil or zoneVolume(zone) < zoneVolume(best) then
				best = zone
			end
		end
	end
	return best
end

local function startInteriorLook(player: Player)
	local grade = Lighting:FindFirstChild("InteriorGrade")
	if not (grade and grade:IsA("ColorCorrectionEffect")) then
		local g = Instance.new("ColorCorrectionEffect")
		g.Name = "InteriorGrade"
		g.Parent = Lighting
		grade = g
	end
	local cc = grade :: ColorCorrectionEffect
	local target = LightsConfig.InteriorGrade
	local blend = 0 -- 0 outside, 1 inside
	local scale = 1
	local outdoorScale = 1
	local envDiffuse = Lighting.EnvironmentDiffuseScale
	local envSpecular = Lighting.EnvironmentSpecularScale
	local elapsed = 0
	local zoneCache: BasePart? = nil
	local baseState: Instance? = nil -- MB_BaseState (LightsDim), looked up with the zone

	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			zoneCache = if root and root:IsA("BasePart") then roomZoneAt(root.Position) else nil
			baseState = ReplicatedStorage:FindFirstChild("MB_BaseState")
		end
		local inside = player:GetAttribute("IsInside") == true or zoneCache ~= nil
		local k = math.clamp(dt / LightsConfig.InteriorBlendSeconds, 0, 1)
		blend += ((if inside then 1 else 0) - blend) * math.min(1, k * 4)

		local roomOn = zoneCache == nil or zoneCache:GetAttribute("LightsOn") ~= false
		-- low base power dims the lamps (server BaseLights, MB_BaseState@LightsDim 0..1)
		local dimValue = if baseState then baseState:GetAttribute("LightsDim") else nil
		local dim = if typeof(dimValue) == "number" then dimValue else 1
		local wantScale = if not inside
			then 1
			elseif roomOn then LightsConfig.InteriorAmbientOff
				+ (LightsConfig.InteriorAmbientOn - LightsConfig.InteriorAmbientOff) * dim
			else LightsConfig.InteriorAmbientOff
		scale += (wantScale - scale) * math.min(1, k * 4)
		Lighting:SetAttribute("AmbientScale", scale)
		local wantOutdoor = if not inside
			then 1
			elseif roomOn then LightsConfig.InteriorOutdoorAmbient
			else LightsConfig.InteriorOutdoorAmbientOff
		outdoorScale += (wantOutdoor - outdoorScale) * math.min(1, k * 4)
		Lighting:SetAttribute("OutdoorAmbientScale", outdoorScale)
		Lighting.EnvironmentDiffuseScale = envDiffuse + (LightsConfig.InteriorEnvDiffuse - envDiffuse) * blend
		Lighting.EnvironmentSpecularScale = envSpecular + (LightsConfig.InteriorEnvSpecular - envSpecular) * blend

		cc.Contrast = target.contrast * blend
		cc.Saturation = target.saturation * blend
		cc.TintColor = Color3.new(1, 1, 1):Lerp(target.tint, blend)
		cc.Enabled = blend > 0.01
	end)
end

function BaseLightsClient.start()
	local player = Players.LocalPlayer
	local lang = Strings.langFromLocale(player.LocaleId)
	local function t(key: string): string
		return Strings.get(key, lang)
	end
	local remote = ReplicatedStorage:WaitForChild("BaseLightsToggle", 30)
	if not (remote and remote:IsA("RemoteEvent")) then
		warn("[lights] no BaseLightsToggle remote")
		return
	end
	local toggle = remote :: RemoteEvent

	startInteriorLook(player)

	-- Window --------------------------------------------------------------------------------
	local gui = Instance.new("ScreenGui")
	gui.Name = "BaseLights"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 20
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local window = Instance.new("Frame")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(460, 560)
	window.BackgroundColor3 = BG
	window.Parent = gui
	corner(window, 10)
	local fit = Instance.new("UISizeConstraint")
	fit.MaxSize = Vector2.new(460, 560)
	fit.Parent = window
	local scaleToScreen = Instance.new("UIScale")
	scaleToScreen.Parent = window
	local windowHeight = 560
	local function rescale()
		local cam = workspace.CurrentCamera
		local view = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		scaleToScreen.Scale = math.min(1, (view.Y - 40) / windowHeight, (view.X - 32) / 460)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	local title = label(window, t("lights.title"), 26, ACCENT)
	title.Font = Enum.Font.GothamBold
	title.Position = UDim2.fromOffset(20, 12)
	title.Size = UDim2.new(1, -90, 0, 34)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local close = button(window, "X")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 12)
	close.Size = UDim2.fromOffset(44, 44)
	close.Modal = true -- frees the first-person mouse while the window is open

	local hint = label(window, t("lights.hint"), 15, MUTED)
	hint.Position = UDim2.fromOffset(20, 52)
	hint.Size = UDim2.new(1, -40, 0, 40)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextYAlignment = Enum.TextYAlignment.Top

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(20, 100)
	list.Size = UDim2.new(1, -40, 1, -170)
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local allOn = button(window, t("lights.all_on"))
	allOn.AnchorPoint = Vector2.new(0, 1)
	allOn.Position = UDim2.new(0, 20, 1, -16)
	allOn.Size = UDim2.new(0.5, -26, 0, 44)
	local allOff = button(window, t("lights.all_off"))
	allOff.AnchorPoint = Vector2.new(1, 1)
	allOff.Position = UDim2.new(1, -20, 1, -16)
	allOff.Size = UDim2.new(0.5, -26, 0, 44)

	local redraws: { () -> () } = {}
	local function redrawAll()
		for _, f in redraws do
			f()
		end
	end

	local function buildRows()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(redraws)
		for i, room in litRooms() do
			local row = Instance.new("Frame")
			row.LayoutOrder = i
			row.BackgroundColor3 = ROW
			row.Size = UDim2.new(1, 0, 0, 36)
			row.Parent = list
			corner(row, 6)
			local dot = Instance.new("Frame")
			dot.AnchorPoint = Vector2.new(0, 0.5)
			dot.Position = UDim2.new(0, 12, 0.5, 0)
			dot.Size = UDim2.fromOffset(14, 14)
			dot.Parent = row
			corner(dot, 7)
			local name = label(row, t("lights.room." .. room.id), 18)
			name.Position = UDim2.fromOffset(36, 0)
			name.Size = UDim2.new(1, -150, 1, 0)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local switch = button(row, "")
			switch.AnchorPoint = Vector2.new(1, 0.5)
			switch.Position = UDim2.new(1, -6, 0.5, 0)
			switch.Size = UDim2.fromOffset(100, 28)
			switch.TextSize = 16
			local function redraw()
				local on = room.zone:GetAttribute("LightsOn") ~= false
				dot.BackgroundColor3 = if on then ON_COLOR else OFF_COLOR
				switch.Text = if on then t("lights.on") else t("lights.off")
				switch.BackgroundColor3 = if on then Color3.fromRGB(150, 110, 40) else Color3.fromRGB(58, 76, 120)
			end
			redraw()
			table.insert(redraws, redraw)
			room.zone:GetAttributeChangedSignal("LightsOn"):Connect(redraw)
			switch.Activated:Connect(function()
				toggle:FireServer(room.id, room.zone:GetAttribute("LightsOn") == false)
			end)
		end
		-- Window fits the rows: header 100 + rows + buttons 76.
		local rows = #redraws
		windowHeight = 100 + rows * 42 + 76
		window.Size = UDim2.fromOffset(460, windowHeight)
		fit.MaxSize = Vector2.new(460, windowHeight)
		rescale()
	end

	local function setOpen(open: boolean)
		if open then
			buildRows()
			redrawAll()
		end
		gui.Enabled = open
		UserInputService.MouseIconEnabled = open
	end

	close.Activated:Connect(function()
		setOpen(false)
	end)
	allOn.Activated:Connect(function()
		toggle:FireServer("all", true)
	end)
	allOff.Activated:Connect(function()
		toggle:FireServer("all", false)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if gui.Enabled and not processed and input.KeyCode == Enum.KeyCode.Escape then
			setOpen(false)
		end
	end)

	-- Close the window when the player walks away from the panel.
	local currentPanel: BasePart? = nil
	RunService.Heartbeat:Connect(function()
		if not (gui.Enabled and currentPanel) then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			not (root and root:IsA("BasePart"))
			or (root.Position - (currentPanel :: BasePart).Position).Magnitude > LightsConfig.PanelDistance + 4
		then
			setOpen(false)
		end
	end)

	-- The panel's own screen: one lamp dot per room ---------------------------------------
	local function buildScreen(panel: BasePart)
		local surface = Instance.new("SurfaceGui")
		surface.Name = "LightsScreen"
		surface.Face = Enum.NormalId.Front
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 60
		surface.LightInfluence = 0
		surface.Brightness = 1.4
		surface.Adornee = panel
		surface.Parent = player:WaitForChild("PlayerGui")
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
		bg.Parent = surface
		local head = label(bg, t("lights.title"), 22, ACCENT)
		head.Font = Enum.Font.GothamBold
		head.Size = UDim2.new(1, 0, 0, 30)
		head.Position = UDim2.fromOffset(0, 6)
		local grid = Instance.new("Frame")
		grid.BackgroundTransparency = 1
		grid.Position = UDim2.fromOffset(10, 40)
		grid.Size = UDim2.new(1, -20, 1, -48)
		grid.Parent = bg
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.new(0.5, -6, 0, 26)
		gl.CellPadding = UDim2.fromOffset(6, 4)
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = grid
		local function fill()
			for _, c in grid:GetChildren() do
				if c:IsA("GuiObject") then
					c:Destroy()
				end
			end
			for i, room in litRooms() do
				local cell = Instance.new("Frame")
				cell.LayoutOrder = i
				cell.BackgroundTransparency = 1
				cell.Parent = grid
				local dot = Instance.new("Frame")
				dot.AnchorPoint = Vector2.new(0, 0.5)
				dot.Position = UDim2.new(0, 2, 0.5, 0)
				dot.Size = UDim2.fromOffset(12, 12)
				dot.Parent = cell
				corner(dot, 6)
				local name = label(cell, t("lights.room." .. room.id), 15)
				name.Position = UDim2.fromOffset(20, 0)
				name.Size = UDim2.new(1, -20, 1, 0)
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.TextSize = 17
				name.TextTruncate = Enum.TextTruncate.AtEnd
				local function redraw()
					local on = room.zone:GetAttribute("LightsOn") ~= false
					dot.BackgroundColor3 = if on then ON_COLOR else OFF_COLOR
					name.TextColor3 = if on then TEXT else MUTED
				end
				redraw()
				room.zone:GetAttributeChangedSignal("LightsOn"):Connect(redraw)
			end
		end
		fill()
		task.delay(3, fill) -- the server may mark the rooms a moment after we start
	end

	local function bindPanel(inst: Instance)
		if not inst:IsA("BasePart") or inst:FindFirstChild("LightsPrompt") then
			return
		end
		local panel = inst :: BasePart
		buildScreen(panel)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LightsPrompt"
		prompt.ActionText = t("lights.prompt.open")
		prompt.ObjectText = t("lights.object")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = LightsConfig.PanelDistance
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			currentPanel = panel
			setOpen(not gui.Enabled)
		end)
		prompt.Parent = panel
	end
	for _, inst in CollectionService:GetTagged(LightsConfig.PanelTag) do
		bindPanel(inst)
	end
	CollectionService:GetInstanceAddedSignal(LightsConfig.PanelTag):Connect(bindPanel)
end

return BaseLightsClient
