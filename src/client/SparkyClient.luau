-- Sparky's dialog window (bottom of the screen, portrait on the left, typewriter text),
-- shown in the player's language. While it is open the mouse cursor is free (first person
-- locks it otherwise); "Next" asks the server for another line, "Bye" / Esc / walking away
-- ends the talk. Clicking the text shows the whole line at once. Layout and colours follow the mock-up (image.png in the repo root):
-- two separate panels with a grey pixel bevel, teal fill, white mono text and a blinking ▼.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Strings = require(ReplicatedStorage.Shared.Strings)

local CHARS_PER_SECOND = 40
local TALK_DISTANCE = 14 -- the dialog closes when the player walks further away (server: 16)

-- Palette sampled from image.png: teal-green panels, grey pixel bevel, dark outline.
local FILL = Color3.fromRGB(33, 55, 53)
local BEVEL = Color3.fromRGB(105, 105, 105)
local OUTLINE = Color3.fromRGB(8, 9, 11)
local TEXT = Color3.fromRGB(242, 247, 250)

local HEIGHT = 150 -- whole dialog
local GAP = 6 -- between portrait and text panels
local OUTLINE_PX = 2
local BEVEL_PX = 4

local SparkyClient = {}

type Dialog = {
	gui: ScreenGui,
	label: TextLabel,
	arrow: TextLabel,
	box: TextButton,
	nextButton: TextButton,
	byeButton: TextButton,
}

local function round(frame: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
end

-- One panel from the mock-up: dark outline -> grey bevel -> teal fill.
-- Returns the inner fill frame, where content goes.
local function panel(parent: Instance, name: string, size: UDim2, position: UDim2): Frame
	local outline = Instance.new("Frame")
	outline.Name = name
	outline.Size = size
	outline.Position = position
	outline.BackgroundColor3 = OUTLINE
	outline.BorderSizePixel = 0
	round(outline, 7)
	outline.Parent = parent

	local bevel = Instance.new("Frame")
	bevel.Name = "Bevel"
	bevel.Size = UDim2.new(1, -2 * OUTLINE_PX, 1, -2 * OUTLINE_PX)
	bevel.Position = UDim2.fromOffset(OUTLINE_PX, OUTLINE_PX)
	bevel.BackgroundColor3 = BEVEL
	bevel.BorderSizePixel = 0
	round(bevel, 6)
	bevel.Parent = outline

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, -2 * BEVEL_PX, 1, -2 * BEVEL_PX)
	fill.Position = UDim2.fromOffset(BEVEL_PX, BEVEL_PX)
	fill.BackgroundColor3 = FILL
	fill.BorderSizePixel = 0
	round(fill, 3)
	-- Thin dark line just inside the bevel, as in the mock-up.
	local inner = Instance.new("UIStroke")
	inner.Color = OUTLINE
	inner.Thickness = 1
	inner.Transparency = 0.3
	inner.Parent = fill
	fill.Parent = bevel
	return fill
end

local function makePortrait(parent: Instance, rover: Model)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Portrait"
	viewport.Size = UDim2.new(1, -6, 1, -6)
	viewport.Position = UDim2.fromOffset(3, 3)
	viewport.BackgroundTransparency = 1
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

	-- Whole rover, head to wheels, like the sprite in the mock-up.
	local cf, size = copy:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local focus = cf.Position
	local distance = size.Y * 2.1
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(size.X * 0.25, size.Y * 0.15, -distance), focus)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- Small button in the dialog's style (bevel + fill), text in the player's language.
local function dialogButton(parent: Instance, text: string, order: number): TextButton
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.AutoButtonColor = true
	b.Size = UDim2.fromOffset(0, 32)
	b.AutomaticSize = Enum.AutomaticSize.X
	b.BackgroundColor3 = Color3.fromRGB(58, 92, 88)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.RobotoMono
	b.TextColor3 = TEXT
	b.TextSize = 18
	b.Text = text
	round(b, 5)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = BEVEL
	stroke.Thickness = 2
	stroke.Parent = b
	b.Parent = parent
	return b
end

local function makeDialog(rover: Model, lang: Strings.Lang): Dialog
	local gui = Instance.new("ScreenGui")
	gui.Name = "SparkyDialog"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 10
	gui.Enabled = false

	-- Invisible holder for the two panels; click / tap on it shows the whole line at once.
	local box = Instance.new("TextButton")
	box.Name = "Box"
	box.Text = ""
	box.AutoButtonColor = false
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -20)
	box.Size = UDim2.new(0.94, 0, 0, HEIGHT)
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(720, HEIGHT)
	limit.Parent = box
	box.Parent = gui

	-- Square portrait panel on the left, text panel fills the rest.
	local portrait = panel(box, "PortraitFrame", UDim2.fromOffset(HEIGHT, HEIGHT), UDim2.fromOffset(0, 0))
	makePortrait(portrait, rover)

	local textFill = panel(box, "TextFrame", UDim2.new(1, -(HEIGHT + GAP), 1, 0), UDim2.fromOffset(HEIGHT + GAP, 0))
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 44)
	padding.Parent = textFill

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.RobotoMono
	label.TextColor3 = TEXT
	label.TextSize = 20
	label.LineHeight = 1.15
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = textFill

	-- White "next" triangle in the bottom-right corner.
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Next"
	arrow.AnchorPoint = Vector2.new(1, 1)
	arrow.Position = UDim2.new(1, 4, 1, 20)
	arrow.Size = UDim2.fromOffset(24, 20)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.Text = "▼"
	arrow.TextColor3 = TEXT
	arrow.TextSize = 28
	arrow.Visible = false
	arrow.Parent = textFill

	-- Buttons in the bottom-right corner of the text panel.
	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.AnchorPoint = Vector2.new(1, 1)
	buttons.Position = UDim2.new(1, 0, 1, 36)
	buttons.Size = UDim2.new(1, 0, 0, 32)
	buttons.BackgroundTransparency = 1
	buttons.Parent = textFill
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Right
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Padding = UDim.new(0, 8)
	row.Parent = buttons
	local nextButton = dialogButton(buttons, Strings.get("sparky.next", lang) .. " ▶", 1)
	local byeButton = dialogButton(buttons, Strings.get("sparky.bye", lang), 2)
	byeButton.Modal = true -- frees the first-person mouse while the dialog is open

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return {
		gui = gui,
		label = label,
		arrow = arrow,
		box = box,
		nextButton = nextButton,
		byeButton = byeButton,
	}
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

	local dialog = makeDialog(rover, lang)
	local token = 0
	local typingFor = 0 -- token of the line being typed (0 = none)
	local talk = ReplicatedStorage:WaitForChild("SparkyTalk", 30)

	local function setOpen(open: boolean)
		dialog.gui.Enabled = open
		UserInputService.MouseIconEnabled = open
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = not open -- local only: hide "Talk" while talking
		end
	end

	local function close()
		if not dialog.gui.Enabled then
			return
		end
		token += 1
		setOpen(false)
		if talk and talk:IsA("RemoteEvent") then
			talk:FireServer("bye")
		end
	end

	dialog.byeButton.Activated:Connect(close)
	dialog.nextButton.Activated:Connect(function()
		if typingFor == token then
			token += 1 -- finish this line first
			return
		end
		if talk and talk:IsA("RemoteEvent") then
			talk:FireServer("next")
		end
	end)
	dialog.box.Activated:Connect(function()
		if typingFor == token then
			token += 1
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if dialog.gui.Enabled and input.KeyCode == Enum.KeyCode.Escape then
			close()
		end
	end)

	-- Blink the "next" arrow while it is visible; close the dialog if the player walks away.
	task.spawn(function()
		while dialog.gui.Parent do
			dialog.arrow.TextTransparency = if os.clock() % 1 < 0.5 then 0 else 0.6
			if dialog.gui.Enabled then
				local character = Players.LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not (root and root:IsA("BasePart")) or (root.Position - body.Position).Magnitude > TALK_DISTANCE then
					close()
				end
			end
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
		setOpen(true)

		typingFor = myToken
		local shown = 0
		while shown < length and token == myToken do
			shown += 1
			dialog.label.MaxVisibleGraphemes = shown
			task.wait(1 / CHARS_PER_SECOND)
		end
		if typingFor == myToken then
			typingFor = 0
		end
		if dialog.gui.Enabled and (token == myToken or token == myToken + 1) then
			dialog.label.MaxVisibleGraphemes = -1 -- typed out, or skipped by a click
		end
	end)
end

return SparkyClient
