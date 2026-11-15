-- Shows the current weather event: a card at the top of the screen (what happened,
-- the real fact, source + ARCHIVED/LIVE label). The event's look on the sky is SkyClient's job.
-- Reads ReplicatedStorage.WeatherState@Payload (JSON, "" = calm), set by the server.
-- A new weather event shows the full card for SHOW_SECONDS, then it folds into a small square
-- (same place, icon of the event) that stays while the weather lasts. Tap the square -> the full card
-- again; it stays open until the player taps X. Calm weather hides both.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Strings = require(ReplicatedStorage.Shared.Strings)

local PANEL = Color3.fromRGB(27, 35, 48)
local BORDER = Color3.fromRGB(232, 150, 60)
local TEXT = Color3.fromRGB(225, 232, 238)
local DIM = Color3.fromRGB(150, 162, 176)
local SHOW_SECONDS = 5 -- the full card, then the square
local ICONS = { dust = "🌪", cold = "❄", radiation = "☢", flare = "☀", cme = "🌞" }

local WeatherClient = {}

type Card = {
	gui: ScreenGui,
	box: Frame,
	square: TextButton,
	icon: TextLabel,
	close: TextButton,
	title: TextLabel,
	body: TextLabel,
	fact: TextLabel,
	footer: TextLabel,
}

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

	-- The folded card: a square with the event icon (tap = open the full card again).
	local square = Instance.new("TextButton")
	square.Name = "Square"
	square.AnchorPoint = Vector2.new(0.5, 0)
	square.Size = UDim2.fromOffset(56, 56)
	square.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	square.BackgroundTransparency = 0.2
	square.Text = ""
	square.Visible = false
	square.Parent = gui
	local squareCorner = Instance.new("UICorner")
	squareCorner.CornerRadius = UDim.new(0, 10)
	squareCorner.Parent = square
	local squareStroke = Instance.new("UIStroke")
	squareStroke.Color = BORDER
	squareStroke.Thickness = 3
	squareStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	squareStroke.Parent = square
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromScale(1, 0.62)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 26
	icon.TextColor3 = TEXT
	icon.Text = "🌦"
	icon.Parent = square
	local tap = Instance.new("TextLabel")
	tap.Name = "Tap"
	tap.Position = UDim2.fromScale(0, 0.58)
	tap.Size = UDim2.fromScale(1, 0.36)
	tap.BackgroundTransparency = 1
	tap.Font = Enum.Font.GothamBold
	tap.TextSize = 12
	tap.TextColor3 = TEXT
	tap.Text = "tap"
	tap.Parent = square

	-- X on the top-right corner of the open card (outside the list layout, placed every frame).
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Size = UDim2.fromOffset(30, 30)
	close.BackgroundColor3 = Color3.fromRGB(55, 55, 66)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 16
	close.TextColor3 = TEXT
	close.Text = "X"
	close.ZIndex = 3
	close.Visible = false
	close.Parent = gui
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = close
	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = TEXT
	closeStroke.Thickness = 2
	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeStroke.Parent = close

	local card = {
		gui = gui,
		box = box,
		square = square,
		icon = icon,
		close = close,
		title = label(box, "Title", 1, 22, BORDER, true),
		body = label(box, "Body", 2, 18, TEXT, false),
		fact = label(box, "Fact", 3, 16, TEXT, false),
		footer = label(box, "Footer", 4, 13, DIM, false),
	}
	gui.Parent = playerGui
	return card
end

function WeatherClient.start()
	local player = Players.LocalPlayer
	local lang = Strings.langFromLocale(player.LocaleId)
	local state = ReplicatedStorage:WaitForChild("WeatherState")
	local card = makeCard(player:WaitForChild("PlayerGui") :: PlayerGui)

	-- "hidden" (calm) | "full" (new event, folds after SHOW_SECONDS) | "open" (until X) | "square"
	local mode = "hidden"
	local foldAt = 0
	local shown = "" -- the payload on screen; a new one shows the full card again

	local function apply()
		local open = mode == "full" or mode == "open"
		card.gui.Enabled = mode ~= "hidden"
		card.box.Visible = open
		card.close.Visible = open
		card.square.Visible = mode == "square"
	end

	card.square.Activated:Connect(function()
		mode = "open"
		apply()
	end)
	card.close.Activated:Connect(function()
		mode = "square"
		apply()
	end)

	RunService.RenderStepped:Connect(function()
		if mode == "full" and os.clock() >= foldAt then
			mode = "square"
			apply()
		end
		if mode == "square" then
			-- Same spot as the card (MB_HUD moves the Box under its top bar).
			card.square.Position = card.box.Position
		elseif card.close.Visible then
			local base = card.gui.AbsolutePosition
			local p, s = card.box.AbsolutePosition, card.box.AbsoluteSize
			card.close.Position = UDim2.fromOffset(p.X + s.X - base.X - 4, p.Y - base.Y + 4)
		end
	end)

	local function render()
		local raw = state:GetAttribute("Payload")
		if typeof(raw) ~= "string" or raw == "" then
			mode, shown = "hidden", ""
			apply()
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
		card.icon.Text = ICONS[payload.id] or "🌦"
		if raw ~= shown then
			shown = raw
			mode = "full"
			foldAt = os.clock() + SHOW_SECONDS
		end
		apply()
	end

	state:GetAttributeChangedSignal("Payload"):Connect(render)
	render()
end

return WeatherClient
