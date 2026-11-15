-- MB_SleepClient (StarterPlayerScripts): the sleep screen.
-- While Player@Sleeping is true (set by MB_ResourceServer when the player lies down in a bed):
--   the screen gets darker, and a card at the top shows "Sleeping…", how many seconds of sleep are left
--   (Fatigue / SleepRate) and a bar that fills up as the player rests.
--   Space (jump) or the "Wake up" button wakes the player early (RemoteEvent MB_Sleep "wake").
-- Stays in the upper half of the screen (the lower half is for the phone controls). Never on top of another card:
-- an open weather card folds when the player lies down, and while an event / weather card is shown (T, a tap
-- on its square, or one popping up) the sleep card steps aside until it closes.
-- Copy of the script that lives in the team place (studio/MB in the repo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local sleepEvent = ReplicatedStorage:WaitForChild("MB_Sleep") :: RemoteEvent

local FONT = Font.fromEnum(Enum.Font.BuilderSans)
local BOLD = Font.new(FONT.Family, Enum.FontWeight.Bold)
local HEAVY = Font.new(FONT.Family, Enum.FontWeight.Heavy)
local TEXT = Color3.fromRGB(245, 240, 235)
local MUTED = Color3.fromRGB(200, 205, 215)
local NIGHT = Color3.fromRGB(130, 112, 216) -- same purple as the tiredness bar in MB_HUD

local function new(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

-- Darker screen behind the HUD (the HUD stays readable on top).
local dimGui = new("ScreenGui", {
	Name = "MB_SleepDim",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 1,
	Enabled = false,
	Parent = playerGui,
})
new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(5, 5, 20),
	BackgroundTransparency = 0.45,
	Active = false,
	Parent = dimGui,
})

-- The card.
local gui = new("ScreenGui", {
	Name = "MB_Sleep",
	ResetOnSpawn = false,
	DisplayOrder = 21,
	Enabled = false,
	Parent = playerGui,
})
local card = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.22),
	Size = UDim2.fromOffset(280, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(10, 10, 20),
	BackgroundTransparency = 0.15,
	Parent = gui,
})
new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = card })
new("UIStroke", { Color = NIGHT, Thickness = 3, Parent = card })
new("UIPadding", {
	PaddingLeft = UDim.new(0, 16),
	PaddingRight = UDim.new(0, 16),
	PaddingTop = UDim.new(0, 12),
	PaddingBottom = UDim.new(0, 14),
	Parent = card,
})
new("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 8),
	Parent = card,
})
local scale = new("UIScale", { Parent = card })

local title = new("TextLabel", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundTransparency = 1,
	FontFace = HEAVY,
	TextSize = 22,
	TextColor3 = TEXT,
	Text = "💤 Sleeping…",
	Parent = card,
})
local left = new("TextLabel", {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	FontFace = BOLD,
	TextSize = 17,
	TextColor3 = TEXT,
	Text = "",
	Parent = card,
})
local track = new("Frame", {
	LayoutOrder = 3,
	Size = UDim2.new(1, 0, 0, 12),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.8,
	Parent = card,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
local fill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = NIGHT,
	Parent = track,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
new("TextLabel", {
	LayoutOrder = 4,
	Size = UDim2.new(1, 0, 0, 16),
	BackgroundTransparency = 1,
	FontFace = FONT,
	TextSize = 14,
	TextColor3 = MUTED,
	Text = if UserInputService.KeyboardEnabled then "Press Space to wake up" else "Tap the button to wake up",
	Parent = card,
})
local wakeButton = new("TextButton", {
	LayoutOrder = 5,
	Size = UDim2.fromOffset(150, 38),
	BackgroundColor3 = NIGHT,
	FontFace = HEAVY,
	TextSize = 18,
	TextColor3 = TEXT,
	Text = "Wake up",
	Parent = card,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = wakeButton })

local function wakeUp()
	if player:GetAttribute("Sleeping") == true then
		sleepEvent:FireServer("wake")
	end
end
wakeButton.Activated:Connect(wakeUp)
UserInputService.JumpRequest:Connect(wakeUp)

-- How rested: the bar starts at the fatigue the player had when they lay down.
local startFatigue = 1
local function onSleepingChanged()
	local asleep = player:GetAttribute("Sleeping") == true
	gui.Enabled = asleep
	dimGui.Enabled = asleep
	if asleep then
		startFatigue = math.max(player:GetAttribute("Fatigue") or 1, 1)
		-- Fold an open weather card into its square (WeatherClient follows these attributes, like the T key).
		local weather = playerGui:FindFirstChild("WeatherCard")
		local box = weather and weather:FindFirstChild("Box")
		if
			weather
			and weather:IsA("ScreenGui")
			and weather.Enabled
			and box
			and box:IsA("GuiObject")
			and box.Visible
		then
			player:SetAttribute("MB_EventsOpen", false)
			player:SetAttribute("MB_EventsToggleId", (player:GetAttribute("MB_EventsToggleId") or 0) + 1)
		end
	end
end

-- Is another full card on screen (weather card or event card)?
local function otherCardOpen(): boolean
	local weather = playerGui:FindFirstChild("WeatherCard")
	local box = weather and weather:FindFirstChild("Box")
	if weather and weather:IsA("ScreenGui") and weather.Enabled and box and box:IsA("GuiObject") and box.Visible then
		return true
	end
	local events = playerGui:FindFirstChild("MB_EventUI")
	local eventCard = events and events:FindFirstChild("Card")
	return eventCard ~= nil and eventCard:IsA("GuiObject") and eventCard.Visible
end
player:GetAttributeChangedSignal("Sleeping"):Connect(onSleepingChanged)
onSleepingChanged()

RunService.RenderStepped:Connect(function()
	if not gui.Enabled then
		return
	end
	card.Visible = not otherCardOpen()
	local camera = workspace.CurrentCamera
	if camera then
		scale.Scale = math.clamp(camera.ViewportSize.Y / 480, 0.75, 1.4)
	end
	local fatigue = player:GetAttribute("Fatigue") or 0
	local rate = player:GetAttribute("SleepRate")
	local seconds = math.ceil(fatigue / (if typeof(rate) == "number" and rate > 0 then rate else 6))
	left.Text = if seconds <= 1 then "Almost rested!" else `{seconds} s more to sleep`
	fill.Size = UDim2.fromScale(math.clamp(1 - fatigue / startFatigue, 0, 1), 1)
	-- Slow "breathing" of the title while asleep.
	title.TextTransparency = 0.15 + 0.15 * math.sin(os.clock() * 2)
end)
