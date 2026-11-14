-- Radiation dose meter (under the role chip): bar to the mission limit, the dose as
-- "days of Mars background" (real Curiosity RAD rate) and whether the dose is growing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RadiationModel = require(ReplicatedStorage.Shared.RadiationModel)
local Strings = require(ReplicatedStorage.Shared.Strings)

local PANEL = Color3.fromRGB(27, 35, 48)
local TEXT = Color3.fromRGB(225, 232, 238)
local DIM = Color3.fromRGB(150, 162, 176)
local LEVEL_COLOR = {
	ok = Color3.fromRGB(110, 200, 110),
	rising = Color3.fromRGB(240, 200, 70),
	high = Color3.fromRGB(240, 130, 60),
	limit = Color3.fromRGB(230, 80, 80),
}

local RadiationClient = {}

local function label(parent: Instance, name: string, size: number, color: Color3, y: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(10, y)
	l.Size = UDim2.new(1, -20, 0, size + 4)
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = ""
	l.Parent = parent
	return l
end

function RadiationClient.start()
	local me = Players.LocalPlayer
	local lang = Strings.langFromLocale(me.LocaleId)
	local info = ReplicatedStorage:WaitForChild("RadiationInfo")
	local weather = ReplicatedStorage:WaitForChild("WeatherState")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DoseMeter"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.Position = UDim2.fromOffset(16, 112)
	box.Size = UDim2.fromOffset(250, 76)
	box.BackgroundColor3 = PANEL
	box.BackgroundTransparency = 0.1
	box.BorderSizePixel = 0
	box.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = box

	local title = label(box, "Title", 15, TEXT, 6)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(10, 28)
	track.Size = UDim2.new(1, -20, 0, 10)
	track.BackgroundColor3 = Color3.fromRGB(55, 66, 84)
	track.BorderSizePixel = 0
	track.Parent = box
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BorderSizePixel = 0
	fill.Parent = track
	for _, f in { track, fill } do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = f
	end
	local status = label(box, "Status", 13, DIM, 44)
	local days = label(box, "Days", 12, DIM, 59)
	gui.Parent = me:WaitForChild("PlayerGui")

	local function render()
		local baseRate = (info:GetAttribute("BaseRate") :: number?) or 0
		local limit = (info:GetAttribute("Limit") :: number?) or 1
		local dose = (me:GetAttribute("Dose") :: number?) or 0
		local level = RadiationModel.level(dose, limit)
		local color = LEVEL_COLOR[level]

		title.Text = Strings.get("radiation.meter.title", lang)
		fill.Size = UDim2.fromScale(math.clamp(dose / limit, 0, 1), 1)
		fill.BackgroundColor3 = color
		stroke.Color = color

		local storm = string.find((weather:GetAttribute("Payload") :: string?) or "", '"id":"radiation"', 1, true)
		local statusKey = if me:GetAttribute("Indoors") == true
			then "radiation.meter.indoors"
			elseif storm then "radiation.meter.storm"
			else "radiation.meter.outside"
		status.Text = Strings.get(statusKey, lang)
		status.TextColor3 = if statusKey == "radiation.meter.indoors" then DIM else color
		days.Text = Strings.get("radiation.meter.days", lang, {
			days = math.floor(RadiationModel.marsDays(dose, baseRate) + 0.5),
		})
	end

	for _, name in { "Dose", "Indoors" } do
		me:GetAttributeChangedSignal(name):Connect(render)
	end
	weather:GetAttributeChangedSignal("Payload"):Connect(render)
	render()
end

return RadiationClient
