--!strict
-- In-game HUD (team mock-up, 2026-11-14):
--   top-left     Sol + shared Oxygen / Water / Food      <- Remotes.ResourcesChanged (server)
--   top-right    space-weather event + countdown         <- Remotes.EventChanged (server)
--   bottom-left  role + personal radiation dose          <- local Player attributes
--   bottom       interaction prompt                      <- ProximityPrompts
--   world        markers on tagged objects               <- CollectionService tag
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local EventBanner = require(script.EventBanner)
local InteractPrompt = require(script.InteractPrompt)
local Markers = require(script.Markers)
local PlayerCard = require(script.PlayerCard)
local ResourcePanel = require(script.ResourcePanel)
local Theme = require(script.Theme)

local MIN_SCALE = 0.7
local MAX_SCALE = 1.6

local Hud = {}

function Hud.start()
	local player = Players.LocalPlayer
	local lang = Strings.langFromLocale(player.LocaleId)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- stays clear of the Roblox top bar
	gui.DisplayOrder = 5

	local scales: { UIScale } = {}
	local function corner(name: string, anchor: Vector2): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.AnchorPoint = anchor
		frame.AutomaticSize = Enum.AutomaticSize.XY
		frame.Size = UDim2.new()
		local m = Theme.Margin
		frame.Position = UDim2.new(anchor.X, m - anchor.X * 2 * m, anchor.Y, m - anchor.Y * 2 * m)
		local scale = Instance.new("UIScale")
		scale.Parent = frame
		table.insert(scales, scale)
		frame.Parent = gui
		return frame
	end

	local updateResources = ResourcePanel.new(corner("TopLeft", Vector2.new(0, 0)), lang)
	local updateEvent = EventBanner.new(corner("TopRight", Vector2.new(1, 0)), lang)
	PlayerCard.new(corner("BottomLeft", Vector2.new(0, 1)), lang, player)
	InteractPrompt.new(corner("BottomCenter", Vector2.new(0.5, 1)), lang)

	-- Keep the mock-up proportions on any screen size.
	local function rescale()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local s = math.clamp(camera.ViewportSize.Y / Theme.ReferenceHeight, MIN_SCALE, MAX_SCALE)
		for _, scale in scales do
			scale.Scale = s
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

	gui.Parent = player:WaitForChild("PlayerGui")
	Markers.start(lang)

	Remotes.get("ResourcesChanged").OnClientEvent:Connect(updateResources)
	Remotes.get("EventChanged").OnClientEvent:Connect(updateEvent)
end

return Hud
