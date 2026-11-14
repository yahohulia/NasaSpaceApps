-- Sparky's dialog box (bottom of the screen, portrait on the left, typewriter text),
-- shown in the player's language. Layout follows the team mock-up (image.png in the repo root).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Strings = require(ReplicatedStorage.Shared.Strings)

local CHARS_PER_SECOND = 40
local MIN_SHOW_SECONDS = 4
local SECONDS_PER_CHAR = 0.06 -- extra reading time after typing

local PANEL = Color3.fromRGB(27, 35, 48)
local BORDER = Color3.fromRGB(200, 208, 216)
local TEXT = Color3.fromRGB(225, 232, 238)

local SparkyClient = {}

type Dialog = {
	gui: ScreenGui,
	label: TextLabel,
	arrow: TextLabel,
	box: TextButton,
}

local function framed(parent: Instance, name: string, size: UDim2, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = PANEL
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = BORDER
	stroke.Thickness = 2
	stroke.Parent = frame
	frame.Parent = parent
	return frame
end

local function makePortrait(parent: Instance, rover: Model)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Portrait"
	viewport.Size = UDim2.new(1, -8, 1, -8)
	viewport.Position = UDim2.fromOffset(4, 4)
	viewport.BackgroundColor3 = Color3.fromRGB(40, 52, 70)
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = parent

	rover.Archivable = true
	local copy = rover:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("ProximityPrompt") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	copy:PivotTo(CFrame.new())
	copy.Parent = viewport

	local cf, size = copy:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	-- Face the rover's front (its LookVector is -Z), slightly from above, framing the head.
	local focus = cf.Position + Vector3.new(0, size.Y * 0.12, 0)
	local distance = size.Y * 1.7
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, size.Y * 0.2, -distance), focus)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function makeDialog(rover: Model): Dialog
	local gui = Instance.new("ScreenGui")
	gui.Name = "SparkyDialog"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 10
	gui.Enabled = false

	-- Whole box is a button: click / tap closes it.
	local box = Instance.new("TextButton")
	box.Name = "Box"
	box.Text = ""
	box.AutoButtonColor = false
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -24)
	box.Size = UDim2.new(0.92, 0, 0, 120)
	box.BackgroundColor3 = PANEL
	box.BorderSizePixel = 0
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(680, 120)
	limit.Parent = box
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Color = BORDER
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = box
	box.Parent = gui

	local portraitFrame = framed(box, "PortraitFrame", UDim2.fromOffset(96, 96), UDim2.fromOffset(12, 12))
	makePortrait(portraitFrame, rover)

	local textFrame = framed(box, "TextFrame", UDim2.new(1, -132, 1, -24), UDim2.fromOffset(120, 12))
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 28)
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = textFrame

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.RobotoMono
	label.TextColor3 = TEXT
	label.TextSize = 20
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = textFrame

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Next"
	arrow.AnchorPoint = Vector2.new(1, 1)
	arrow.Position = UDim2.new(1, 20, 1, 4)
	arrow.Size = UDim2.fromOffset(16, 16)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBold
	arrow.Text = "▼"
	arrow.TextColor3 = TEXT
	arrow.TextSize = 14
	arrow.Visible = false
	arrow.Parent = textFrame

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return { gui = gui, label = label, arrow = arrow, box = box }
end

function SparkyClient.start()
	local lang = Strings.langFromLocale(Players.LocalPlayer.LocaleId)

	local base = workspace:WaitForChild("Base", 30)
	local habitat = base and base:WaitForChild("Habitat", 30)
	local rover = habitat and habitat:WaitForChild("Sparky", 30)
	if not (rover and rover:IsA("Model")) then
		return
	end
	-- With StreamingEnabled the model can arrive before its parts.
	local deadline = os.clock() + 30
	while not rover.PrimaryPart and os.clock() < deadline do
		task.wait(0.2)
	end
	local body = rover.PrimaryPart
	if not body then
		warn("[Sparky] rover parts did not stream in")
		return
	end

	-- Local-only text: each player sees the prompt in their own language.
	local prompt = body:WaitForChild("ProximityPrompt", 30)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.ActionText = Strings.get("sparky.prompt.talk", lang)
		prompt.ObjectText = Strings.get("sparky.name", lang)
	end

	local dialog = makeDialog(rover)
	local token = 0

	local function close()
		token += 1
		dialog.gui.Enabled = false
	end
	dialog.box.Activated:Connect(close)

	-- Blink the "next" arrow while it is visible.
	task.spawn(function()
		while dialog.gui.Parent do
			dialog.arrow.TextTransparency = if os.clock() % 1 < 0.5 then 0 else 0.6
			RunService.RenderStepped:Wait()
		end
	end)

	local say = ReplicatedStorage:WaitForChild("SparkySay", 30)
	if not (say and say:IsA("RemoteEvent")) then
		return
	end
	say.OnClientEvent:Connect(function(key: string)
		token += 1
		local myToken = token
		local text = Strings.get(key, lang)
		local length = utf8.len(text) or #text
		dialog.label.Text = text
		dialog.label.MaxVisibleGraphemes = 0
		dialog.arrow.Visible = false
		dialog.gui.Enabled = true

		local shown = 0
		while shown < length and token == myToken do
			shown += 1
			dialog.label.MaxVisibleGraphemes = shown
			task.wait(1 / CHARS_PER_SECOND)
		end
		if token ~= myToken then
			return
		end
		dialog.label.MaxVisibleGraphemes = -1
		dialog.arrow.Visible = true
		task.wait(math.max(MIN_SHOW_SECONDS, length * SECONDS_PER_CHAR))
		if token == myToken then
			close()
		end
	end)
end

return SparkyClient
