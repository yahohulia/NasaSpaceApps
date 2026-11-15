-- MB_MissionClient (StarterPlayerScripts): the rocket launch and the "Mission complete" screen.
-- Listens to ReplicatedStorage.MB_Mission (from MB_Missions):
--   "launch" - the rocket (Workspace.RocketModel) flies up on this screen, then "Mission complete".
--   "reset"  - the rocket is back on the pad and the screen closes ("Play again").
-- The rocket only moves on each player's screen; the model in the place is never changed.
-- Copy of the script that lives in the team place (studio/MB in the repo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local mission = ReplicatedStorage:WaitForChild("MB_Mission")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local FONT = Font.fromEnum(Enum.Font.BuilderSans)
local HEAVY = Font.new(FONT.Family, Enum.FontWeight.Heavy)
local BOLD = Font.new(FONT.Family, Enum.FontWeight.Bold)
local GOLD = Color3.fromRGB(240, 196, 70)
local TEXT = Color3.fromRGB(245, 240, 235)

-- Mission complete screen ---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "MB_MissionComplete"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.45
dim.Parent = gui

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.fromScale(0.5, 0.16)
card.AutomaticSize = Enum.AutomaticSize.XY
card.Size = UDim2.new()
card.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
card.BackgroundTransparency = 0.1
card.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = card
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Thickness = 3
stroke.Parent = card
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 36)
pad.PaddingRight = UDim.new(0, 36)
pad.PaddingTop = UDim.new(0, 24)
pad.PaddingBottom = UDim.new(0, 24)
pad.Parent = card
local list = Instance.new("UIListLayout")
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 12)
list.Parent = card
local scale = Instance.new("UIScale")
scale.Parent = card

local function label(order: number, text: string, font: Font, size: number, color: Color3)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.new()
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	l.Parent = card
	return l
end
label(1, "Mission complete!", HEAVY, 34, GOLD)
label(2, "Your crew survived on Mars and is flying home.", BOLD, 18, TEXT)
local starsLabel = label(3, "Great teamwork, astronauts!", FONT, 18, GOLD)

local again = Instance.new("TextButton")
again.LayoutOrder = 4
again.Size = UDim2.fromOffset(200, 48)
again.BackgroundColor3 = GOLD
again.FontFace = HEAVY
again.TextSize = 20
again.TextColor3 = Color3.fromRGB(30, 25, 10)
again.Text = "Play again"
again.Parent = card
local againCorner = Instance.new("UICorner")
againCorner.CornerRadius = UDim.new(1, 0)
againCorner.Parent = again

again.Activated:Connect(function()
	mission:FireServer("playAgain")
end)

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

-- Rocket launch ---------------------------------------------------------------------------------------
local rocket = workspace:FindFirstChild("RocketModel")
local homePivot: CFrame? = if rocket and rocket:IsA("Model") then rocket:GetPivot() else nil
local flight: RBXScriptConnection? = nil
local flame: Part? = nil

local function stopFlight()
	if flight then
		flight:Disconnect()
		flight = nil
	end
	if flame then
		flame:Destroy()
		flame = nil
	end
end

local function launch(stars: number?)
	-- 3 stars = all samples brought home (MB_Missions / MB_Events LaunchWindow).
	local n = math.clamp(stars or 3, 1, 3)
	starsLabel.Text = string.rep("★", n) .. string.rep("☆", 3 - n) .. "  Great teamwork, astronauts!"
	if not (rocket and rocket:IsA("Model") and homePivot) then
		gui.Enabled = true
		return
	end
	stopFlight()
	local start = homePivot :: CFrame
	local _, size = rocket:GetBoundingBox()
	local f = Instance.new("Part")
	f.Name = "MB_LaunchFlame"
	f.Anchored = true
	f.CanCollide = false
	f.CanQuery = false
	f.Material = Enum.Material.Neon
	f.Color = Color3.fromRGB(255, 160, 60)
	f.Shape = Enum.PartType.Ball
	f.Size = Vector3.new(10, 10, 10)
	f.Parent = workspace
	flame = f
	local t = 0
	flight = RunService.RenderStepped:Connect(function(dt)
		t += dt
		local height = 3 * t * t -- speeds up like a real launch
		local pivot = start + Vector3.new(0, height, 0)
		rocket:PivotTo(pivot)
		f.CFrame = CFrame.new(pivot.Position - Vector3.new(0, size.Y / 2 + 2, 0))
		f.Size = Vector3.new(8, 8, 8) * (1 + 0.15 * math.sin(t * 30))
		if t > 9 then
			stopFlight()
		end
	end)
	task.delay(5, function()
		gui.Enabled = true
	end)
end

local function reset()
	stopFlight()
	if rocket and rocket:IsA("Model") and homePivot then
		rocket:PivotTo(homePivot)
	end
	gui.Enabled = false
end

mission.OnClientEvent:Connect(function(action: string, stars: number?)
	if action == "launch" then
		launch(stars)
	elseif action == "reset" then
		reset()
	end
end)
