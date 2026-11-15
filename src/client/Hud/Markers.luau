--!strict
-- World markers: "[!] Pump · 8 m" above tagged objects, or "< Farm · 20 m" at the screen edge when the
-- object is off-screen. Tag a Part or Model with Config.Hud.MarkerTag; attributes: Label, Kind.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(ReplicatedStorage.Shared.Strings)
local PixelIcon = require(script.Parent.PixelIcon)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local EDGE_MARGIN = 24

local CHEVRONS = { "ChevronLeft", "ChevronRight", "ChevronUp", "ChevronDown" }

type Marker = {
	frame: Frame,
	stroke: UIStroke,
	alert: Frame,
	chevrons: { [string]: PixelIcon.Icon },
	label: TextLabel,
}

local function showChevron(marker: Marker, which: string?)
	for name, icon in marker.chevrons do
		icon.frame.Visible = name == which
	end
end

local Markers = {}

local function worldPosition(target: Instance): Vector3?
	if target:IsA("BasePart") then
		return target.Position + Vector3.new(0, target.Size.Y / 2 + 1, 0)
	elseif target:IsA("Model") then
		local cf, size = target:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y / 2 + 1, 0)
	end
	return nil
end

local function makeMarker(parent: Instance): Marker
	local frame = Widgets.panel("Marker", Theme.Alert)
	frame.AnchorPoint = Vector2.new(0.5, 1)
	local padding = frame:FindFirstChildOfClass("UIPadding") :: UIPadding
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 10)
	Widgets.row(frame, 8)

	local chevrons: { [string]: PixelIcon.Icon } = {}
	for _, name in CHEVRONS do
		local icon = PixelIcon.new(name, 2, Theme.Objective)
		icon.frame.LayoutOrder = 1
		icon.frame.Visible = false
		icon.frame.Parent = frame
		chevrons[name] = icon
	end

	local alert = Instance.new("Frame")
	alert.Name = "Alert"
	alert.LayoutOrder = 2
	alert.BorderSizePixel = 0
	alert.BackgroundColor3 = Theme.Alert
	alert.Size = UDim2.fromOffset(16, 16)
	alert.Parent = frame
	local bang = PixelIcon.new("Alert", 2, Theme.Text)
	bang.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	bang.frame.Position = UDim2.fromScale(0.5, 0.5)
	bang.frame.Parent = alert

	local label = Widgets.label("Label", Theme.Text)
	label.LayoutOrder = 3
	label.Parent = frame

	frame.Parent = parent
	return {
		frame = frame,
		stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke,
		alert = alert,
		chevrons = chevrons,
		label = label,
	}
end

function Markers.start(lang: Strings.Lang)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HudMarkers"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- so positions match Camera:WorldToViewportPoint
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 4
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local markers: { [Instance]: Marker } = {}

	local function add(target: Instance)
		if not markers[target] then
			markers[target] = makeMarker(gui)
		end
	end
	local function remove(target: Instance)
		local marker = markers[target]
		if marker then
			marker.frame:Destroy()
			markers[target] = nil
		end
	end
	for _, target in CollectionService:GetTagged(Config.Hud.MarkerTag) do
		add(target)
	end
	CollectionService:GetInstanceAddedSignal(Config.Hud.MarkerTag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Config.Hud.MarkerTag):Connect(remove)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local center = viewport / 2
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local origin = if root and root:IsA("BasePart") then root.Position else camera.CFrame.Position

		for target, marker in markers do
			local position = worldPosition(target)
			if not position then
				marker.frame.Visible = false
				continue
			end

			local isAlert = target:GetAttribute("Kind") == "alert"
			local labelKey = target:GetAttribute("Label")
			local name = Strings.get(if typeof(labelKey) == "string" then labelKey else target.Name, lang)
			local meters = math.round((position - origin).Magnitude * Config.Hud.MetersPerStud)
			marker.label.Text = Strings.get("hud.marker.distance", lang, { label = name, m = meters })

			local screen = camera:WorldToViewportPoint(position)
			local inside = screen.Z > 0
				and screen.X >= EDGE_MARGIN
				and screen.X <= viewport.X - EDGE_MARGIN
				and screen.Y >= EDGE_MARGIN
				and screen.Y <= viewport.Y - EDGE_MARGIN

			if inside then
				marker.frame.AnchorPoint = Vector2.new(0.5, 1)
				marker.frame.Position = UDim2.fromOffset(screen.X, screen.Y)
				showChevron(marker, nil)
				marker.alert.Visible = isAlert
				marker.stroke.Enabled = true
				marker.stroke.Color = if isAlert then Theme.Alert else Theme.Objective
				marker.label.TextColor3 = Theme.Text
			else
				-- Off-screen (or behind the camera): pin to the edge in the object's direction,
				-- measured in camera space so objects behind us still point to the correct side.
				local rel = camera.CFrame:PointToObjectSpace(position)
				local dir = Vector2.new(rel.X, -rel.Y)
				if screen.Z > 0 then
					dir = Vector2.new(screen.X, screen.Y) - center
				end
				if dir.Magnitude < 1e-3 then
					dir = Vector2.new(0, 1)
				end
				local half = center - Vector2.new(EDGE_MARGIN, EDGE_MARGIN)
				local t = math.min(half.X / math.max(math.abs(dir.X), 1e-3), half.Y / math.max(math.abs(dir.Y), 1e-3))
				local pin = center + dir * t
				local n = dir / math.max(math.abs(dir.X), math.abs(dir.Y))
				marker.frame.AnchorPoint = Vector2.new(0.5 + 0.5 * n.X, 0.5 + 0.5 * n.Y)
				marker.frame.Position = UDim2.fromOffset(pin.X, pin.Y)
				local which = if math.abs(n.X) >= math.abs(n.Y)
					then (if n.X < 0 then "ChevronLeft" else "ChevronRight")
					else (if n.Y < 0 then "ChevronUp" else "ChevronDown")
				showChevron(marker, which)
				for _, icon in marker.chevrons do
					icon.setColor(if isAlert then Theme.Warning else Theme.Objective)
				end
				marker.alert.Visible = false
				marker.stroke.Enabled = false
				marker.label.TextColor3 = if isAlert then Theme.Warning else Theme.Objective
			end
			marker.frame.Visible = true
		end
	end)
end

return Markers
