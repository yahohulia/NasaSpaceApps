-- Shows the current weather event: a card at the top of the screen (what happened,
-- the real fact, source + ARCHIVED/LIVE label) and the event's look on Lighting.
-- Reads ReplicatedStorage.WeatherState@Payload (JSON, "" = calm), set by the server.
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DataMapping = require(ReplicatedStorage.Shared.DataMapping)
local Strings = require(ReplicatedStorage.Shared.Strings)

local PANEL = Color3.fromRGB(27, 35, 48)
local BORDER = Color3.fromRGB(232, 150, 60)
local TEXT = Color3.fromRGB(225, 232, 238)
local DIM = Color3.fromRGB(150, 162, 176)

local WeatherClient = {}

type Card = { gui: ScreenGui, title: TextLabel, body: TextLabel, fact: TextLabel, footer: TextLabel }

local function label(
	parent: Instance,
	name: string,
	order: number,
	size: number,
	color: Color3,
	bold: boolean
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.LayoutOrder = order
	l.Size = UDim2.fromScale(1, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = parent
	return l
end

local function makeCard(playerGui: PlayerGui): Card
	local gui = Instance.new("ScreenGui")
	gui.Name = "WeatherCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9
	gui.Enabled = false

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 16)
	box.Size = UDim2.fromScale(0.92, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.BackgroundColor3 = PANEL
	box.BackgroundTransparency = 0.08
	box.BorderSizePixel = 0
	box.Parent = gui

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, math.huge)
	limit.Parent = box
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Color = BORDER
	stroke.Thickness = 2
	stroke.Parent = box
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = box
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = box

	local card = {
		gui = gui,
		title = label(box, "Title", 1, 22, BORDER, true),
		body = label(box, "Body", 2, 18, TEXT, false),
		fact = label(box, "Fact", 3, 16, TEXT, false),
		footer = label(box, "Footer", 4, 13, DIM, false),
	}
	gui.Parent = playerGui
	return card
end

-- Lighting values before any event, restored when the weather is calm.
type Base = { density: number, haze: number, color: Color3, brightness: number, clockTime: number }

local function tween(instance: Instance, seconds: number, goal: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Sine), goal):Play()
end

function WeatherClient.start()
	local player = Players.LocalPlayer
	local lang = Strings.langFromLocale(player.LocaleId)
	local state = ReplicatedStorage:WaitForChild("WeatherState")
	local card = makeCard(player:WaitForChild("PlayerGui") :: PlayerGui)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local base: Base? = if atmosphere
		then {
			density = atmosphere.Density,
			haze = atmosphere.Haze,
			color = atmosphere.Color,
			brightness = Lighting.Brightness,
			clockTime = Lighting.ClockTime,
		}
		else nil

	local function applyLook(id: string?)
		if not atmosphere or not base then
			return
		end
		local look = if id then DataMapping.looks[id] else nil
		local seconds = if look then look.fadeSeconds else 4
		if look then
			tween(atmosphere, seconds, {
				Density = look.atmosphereDensity,
				Haze = look.atmosphereHaze,
				Color = look.atmosphereColor,
			})
			tween(Lighting, seconds, {
				Brightness = base.brightness * look.brightnessScale,
				ClockTime = look.clockTime or base.clockTime,
			})
		else
			tween(atmosphere, seconds, { Density = base.density, Haze = base.haze, Color = base.color })
			tween(Lighting, seconds, { Brightness = base.brightness, ClockTime = base.clockTime })
		end
	end

	local function render()
		local raw = state:GetAttribute("Payload")
		if typeof(raw) ~= "string" or raw == "" then
			card.gui.Enabled = false
			applyLook(nil)
			return
		end
		local ok, payload = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok or type(payload) ~= "table" then
			warn("[weather] bad payload", raw)
			return
		end

		-- Text values (e.g. UV "Very_High") have their own translations.
		local vars = {}
		for key, value in payload.vars do
			if type(value) == "string" then
				local valueKey = `weather.value.{value}`
				local translated = Strings.get(valueKey, lang)
				vars[key] = if translated ~= valueKey then translated else value
			else
				vars[key] = value
			end
		end

		local prefix = `weather.{payload.id}`
		local labelKey = if payload.label == "LIVE" then "weather.label.live" else "weather.label.archived"
		card.title.Text = Strings.get(`{prefix}.title`, lang)
		card.body.Text = Strings.get(`{prefix}.body`, lang)
		card.fact.Text = Strings.get(`{prefix}.fact`, lang, vars)
		card.footer.Text =
			`{payload.source} · {payload.credit} · {Strings.get(labelKey, lang, { date = payload.date })}`
		card.gui.Enabled = true
		applyLook(payload.id)
	end

	state:GetAttributeChangedSignal("Payload"):Connect(render)
	render()
end

return WeatherClient
