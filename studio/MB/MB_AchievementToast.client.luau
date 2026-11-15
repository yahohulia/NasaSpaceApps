-- MB_AchievementToast (StarterPlayerScripts): the "Achievement unlocked!" card.
-- Listens to ReplicatedStorage.MB_Achievement (fired by MB_Achievements on the server).
-- A gold-framed card with a trophy slides in from the left (under the left column), stays a few seconds,
-- then fades out. Several achievements in a row are shown one after another.
-- Copy of the script that lives in the team place (studio/MB in the repo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local remote = ReplicatedStorage:WaitForChild("MB_Achievement")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local SHOW_SECONDS = 4
local FONT = Font.fromEnum(Enum.Font.BuilderSans)
local BOLD = Font.new(FONT.Family, Enum.FontWeight.Bold)
local HEAVY = Font.new(FONT.Family, Enum.FontWeight.Heavy)
local GOLD = Color3.fromRGB(240, 196, 70)
local TEXT = Color3.fromRGB(245, 240, 235)
local TROPHY = { "#######", "#.###.#", ".#####.", "..###..", "...#...", "..###..", ".#####." }

local gui = Instance.new("ScreenGui")
gui.Name = "MB_AchievementToast"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = playerGui

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0, 0) -- left side, under the left column (upper half: the lower half is for touch controls)
card.Position = UDim2.new(0, -30, 0.37, 0)
card.AutomaticSize = Enum.AutomaticSize.XY
card.Size = UDim2.new()
card.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
card.BackgroundTransparency = 1
card.Visible = false
card.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = card
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Thickness = 2
stroke.Transparency = 1
stroke.Parent = card
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 16)
pad.PaddingRight = UDim.new(0, 20)
pad.PaddingTop = UDim.new(0, 10)
pad.PaddingBottom = UDim.new(0, 12)
pad.Parent = card
local row = Instance.new("UIListLayout")
row.FillDirection = Enum.FillDirection.Horizontal
row.VerticalAlignment = Enum.VerticalAlignment.Center
row.Padding = UDim.new(0, 14)
row.SortOrder = Enum.SortOrder.LayoutOrder
row.Parent = card
local scale = Instance.new("UIScale")
scale.Parent = card

-- Trophy icon (pixel art, 3 px per pixel).
local trophy = Instance.new("Frame")
trophy.LayoutOrder = 1
trophy.BackgroundTransparency = 1
trophy.Size = UDim2.fromOffset(21, 21)
trophy.Parent = card
local trophyPixels: { Frame } = {}
for y, line in TROPHY do
	for x = 1, #line do
		if string.sub(line, x, x) == "#" then
			local p = Instance.new("Frame")
			p.BorderSizePixel = 0
			p.BackgroundColor3 = GOLD
			p.Size = UDim2.fromOffset(3, 3)
			p.Position = UDim2.fromOffset((x - 1) * 3, (y - 1) * 3)
			p.Parent = trophy
			table.insert(trophyPixels, p)
		end
	end
end

local texts = Instance.new("Frame")
texts.LayoutOrder = 2
texts.BackgroundTransparency = 1
texts.AutomaticSize = Enum.AutomaticSize.XY
texts.Size = UDim2.new()
texts.Parent = card
local col = Instance.new("UIListLayout")
col.SortOrder = Enum.SortOrder.LayoutOrder
col.Padding = UDim.new(0, 2)
col.Parent = texts

local function label(order: number, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.new()
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTransparency = 1
	l.Parent = texts
	return l
end
local header = label(1, BOLD, 13, GOLD)
header.Text = "Achievement unlocked!"
local title = label(2, HEAVY, 20, TEXT)
local body = label(3, FONT, 15, TEXT)

local function rescale()
	local camera = workspace.CurrentCamera
	if camera then
		scale.Scale = math.clamp(camera.ViewportSize.Y / 480, 0.75, 1.6)
	end
end
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end
rescale()

local function fade(visible: boolean, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t = if visible then 0 else 1
	TweenService:Create(card, info, {
		BackgroundTransparency = if visible then 0.3 else 1,
		Position = UDim2.new(0, if visible then 12 else -30, 0.37, 0),
	}):Play()
	TweenService:Create(stroke, info, { Transparency = t }):Play()
	for _, l in { header, title, body } do
		TweenService:Create(l, info, { TextTransparency = t }):Play()
	end
	for _, p in trophyPixels do
		TweenService:Create(p, info, { BackgroundTransparency = t }):Play()
	end
end

local queue: { { string } } = {}
local busy = false

local function showNext()
	if busy or #queue == 0 then
		return
	end
	busy = true
	local item = table.remove(queue, 1) :: { string }
	title.Text = item[1]
	body.Text = item[2]
	card.Visible = true
	fade(true, 0.35)
	task.delay(SHOW_SECONDS, function()
		fade(false, 0.5)
		task.wait(0.55)
		card.Visible = false
		busy = false
		showNext()
	end)
end

remote.OnClientEvent:Connect(function(_id: string, achievementTitle: string, text: string)
	table.insert(queue, { achievementTitle, text })
	showNext()
end)
