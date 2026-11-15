-- MB_Tutorial (StarterPlayerScripts): five training steps with a short checked NASA fact each.
--   1 go outside  2 clean a solar panel  3 collect a sample  4 eat or drink  5 rest on the bunk
-- Steps and facts live in MB_Config.Tutorial. A small hint sits in the MB_HUD centre column (top of the
-- screen), so the lower half stays free for touch controls. Progress is per player, for this session.
-- (The team's checkpoint script waits for Workspace.Checkpoints, which does not exist - the part is named
-- with a Cyrillic "С" - so the steps are detected from game events instead.)
-- Copy of the script that lives in the team place (studio/MB in the repo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MB_Config"))
local notify = ReplicatedStorage:WaitForChild("MB_Notify")
local STEPS = Config.Tutorial
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if not STEPS or #STEPS == 0 then
	return
end

local FONT = Font.fromEnum(Enum.Font.BuilderSans)
local BOLD = Font.new(FONT.Family, Enum.FontWeight.Bold)

local hud = playerGui:WaitForChild("MB_HUD", 15)
local center = hud and hud:WaitForChild("Center", 5)
if not center then
	return
end

local pill = Instance.new("Frame")
pill.Name = "Tutorial"
pill.LayoutOrder = 6
pill.AutomaticSize = Enum.AutomaticSize.XY
pill.Size = UDim2.new()
pill.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
pill.BackgroundTransparency = 0.5
pill.Parent = center
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = pill
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 14)
pad.PaddingRight = UDim.new(0, 14)
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 7)
pad.Parent = pill
local list = Instance.new("UIListLayout")
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 2)
list.Parent = pill

local function label(order: number, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.new()
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.Parent = pill
	return l
end
local task1 = label(1, BOLD, 15, Color3.fromRGB(245, 240, 235))
local fact = label(2, FONT, 13, Color3.fromRGB(150, 200, 255))

local step = 1

local function show()
	local s = STEPS[step]
	if s then
		task1.Text = `{step}/{#STEPS}  {s.Text}`
		fact.Text = s.Fact
		pill.Visible = true
	end
end

local function advance(id: string)
	local s = STEPS[step]
	if not s or s.Id ~= id then
		return
	end
	step += 1
	if step > #STEPS then
		task1.Text = "Training complete!"
		fact.Text = `Survive {Config.Victory.SolsToSurvive} sols and collect all samples to fly home.`
		task.delay(8, function()
			pill.Visible = false
		end)
	else
		show()
	end
end

-- Step detection ---------------------------------------------------------------------------------
local function num(name: string): number
	local v = player:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

player:GetAttributeChangedSignal("IsInside"):Connect(function()
	if player:GetAttribute("IsInside") == false then
		advance("outside")
	end
end)

notify.OnClientEvent:Connect(function(key: string)
	if key == "panel_clean" then
		advance("clean")
	elseif key == "sample_got" then
		advance("sample")
	end
end)

local lastFood, lastWater, lastFatigue = num("Food"), num("Water"), num("Fatigue")
player:GetAttributeChangedSignal("Food"):Connect(function()
	local v = num("Food")
	if v > lastFood + 5 then
		advance("eat")
	end
	lastFood = v
end)
player:GetAttributeChangedSignal("Water"):Connect(function()
	local v = num("Water")
	if v > lastWater + 5 then
		advance("eat")
	end
	lastWater = v
end)
player:GetAttributeChangedSignal("Fatigue"):Connect(function()
	local v = num("Fatigue")
	if v < lastFatigue - 10 then
		advance("rest")
	end
	lastFatigue = v
end)

-- New mission ("Play again"): start the training from the first step again.
notify.OnClientEvent:Connect(function(key: string)
	if key == "new_mission" then
		step = 1
		show()
	end
end)

show()
-- If the player starts outside, step 1 is already done.
task.delay(3, function()
	if player:GetAttribute("IsInside") == false then
		advance("outside")
	end
end)
