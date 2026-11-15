-- Sparky's dialog window (bottom of the screen, portrait on the left, typewriter text),
-- shown in the player's language. Sparky is the radio link to Earth: the player types a
-- question (or taps a quick question), Sparky checks it, sends it, and Earth's answer comes
-- back after the signal delay (a countdown in game minutes). While the window is open the
-- mouse cursor is free (first person locks it otherwise). "Bye" / Esc / walking away ends
-- the talk. Clicking the text shows the whole line at once. Earth's AI answers get a small note.
-- Layout and colours follow the mock-up (image.png in the repo root): two panels with a grey
-- pixel bevel, teal fill and white mono text.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local SparkyQuestions = require(ReplicatedStorage.Shared.SparkyQuestions)
local Strings = require(ReplicatedStorage.Shared.Strings)

local CHARS_PER_SECOND = 40
local TALK_DISTANCE = 14 -- the dialog closes when the player walks further away (server: 16)
local MAX_CHARS = 120 -- same limit as the server

-- Palette sampled from image.png: teal-green panels, grey pixel bevel, dark outline.
local FILL = Color3.fromRGB(33, 55, 53)
local BEVEL = Color3.fromRGB(105, 105, 105)
local OUTLINE = Color3.fromRGB(8, 9, 11)
local TEXT = Color3.fromRGB(242, 247, 250)

local HEIGHT = 230 -- whole dialog
local PORTRAIT = 160 -- square portrait panel
local SHOWN_QUESTIONS = 2 -- quick question buttons (Ukrainian ones are long)
local GAP = 6 -- between portrait and text panels
local OUTLINE_PX = 2
local BEVEL_PX = 4

local SparkyClient = {}

type Dialog = {
	gui: ScreenGui,
	label: TextLabel,
	note: TextLabel,
	status: TextLabel,
	box: TextButton,
	questionButtons: { TextButton },
	input: TextBox,
	sendButton: TextButton,
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
	b.Size = UDim2.fromOffset(0, 30)
	b.AutomaticSize = Enum.AutomaticSize.X
	b.BackgroundColor3 = Color3.fromRGB(58, 92, 88)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.RobotoMono
	b.TextColor3 = TEXT
	b.TextSize = 16
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
	limit.MaxSize = Vector2.new(760, HEIGHT)
	limit.Parent = box
	box.Parent = gui

	-- Square portrait panel on the left (bottom-aligned), text panel fills the rest.
	local portrait = panel(box, "PortraitFrame", UDim2.fromOffset(PORTRAIT, PORTRAIT), UDim2.new(0, 0, 1, -PORTRAIT))
	makePortrait(portrait, rover)

	local textFill = panel(box, "TextFrame", UDim2.new(1, -(PORTRAIT + GAP), 1, 0), UDim2.fromOffset(PORTRAIT + GAP, 0))
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = textFill

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, 0, 1, -88)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.RobotoMono
	label.TextColor3 = TEXT
	label.TextSize = 18
	label.LineHeight = 1.15
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = textFill

	-- Small grey line above the buttons: the AI note on the left, the countdown on the right.
	local function smallLine(name: string, align: Enum.TextXAlignment): TextLabel
		local t = Instance.new("TextLabel")
		t.Name = name
		t.AnchorPoint = Vector2.new(0, 1)
		t.Position = UDim2.new(0, 0, 1, -68)
		t.Size = UDim2.new(1, 0, 0, 16)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.RobotoMono
		t.Text = ""
		t.TextColor3 = Color3.fromRGB(160, 180, 178)
		t.TextSize = 13
		t.TextXAlignment = align
		t.Visible = false
		t.Parent = textFill
		return t
	end
	local note = smallLine("AiNote", Enum.TextXAlignment.Left)
	note.Text = "🤖 " .. Strings.get("sparky.ai.note", lang)
	local status = smallLine("Status", Enum.TextXAlignment.Right)

	local function buttonRow(name: string, y: number, height: number): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.AnchorPoint = Vector2.new(0, 1)
		frame.Position = UDim2.new(0, 0, 1, y)
		frame.Size = UDim2.new(1, 0, 0, height)
		frame.BackgroundTransparency = 1
		frame.Parent = textFill
		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		row.SortOrder = Enum.SortOrder.LayoutOrder
		row.Padding = UDim.new(0, 6)
		row.Parent = frame
		return frame
	end

	-- Quick questions.
	local quick = buttonRow("Quick", -36, 28)
	local questionButtons = {}
	for i = 1, SHOWN_QUESTIONS do
		local b = dialogButton(quick, "", i)
		b.Size = UDim2.fromOffset(0, 26)
		b.TextSize = 14
		table.insert(questionButtons, b)
	end

	-- Typed question + Send + Bye.
	local inputRow = buttonRow("Input", 0, 30)
	local input = Instance.new("TextBox")
	input.Name = "Question"
	input.LayoutOrder = 1
	input.Size = UDim2.new(1, -230, 0, 30)
	input.BackgroundColor3 = Color3.fromRGB(20, 34, 33)
	input.BorderSizePixel = 0
	input.ClearTextOnFocus = false
	input.Font = Enum.Font.RobotoMono
	input.PlaceholderText = Strings.get("sparky.chat.placeholder", lang)
	input.PlaceholderColor3 = Color3.fromRGB(130, 150, 148)
	input.Text = ""
	input.TextColor3 = TEXT
	input.TextSize = 16
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.TextTruncate = Enum.TextTruncate.AtEnd
	round(input, 5)
	local inputPad = Instance.new("UIPadding")
	inputPad.PaddingLeft = UDim.new(0, 8)
	inputPad.PaddingRight = UDim.new(0, 8)
	inputPad.Parent = input
	local inputStroke = Instance.new("UIStroke")
	inputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	inputStroke.Color = BEVEL
	inputStroke.Thickness = 2
	inputStroke.Parent = input
	input.Parent = inputRow
	local sendButton = dialogButton(inputRow, Strings.get("sparky.chat.send", lang) .. " ▶", 2)
	local byeButton = dialogButton(inputRow, Strings.get("sparky.bye", lang), 3)
	byeButton.Modal = true -- frees the first-person mouse while the dialog is open

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return {
		gui = gui,
		label = label,
		note = note,
		status = status,
		box = box,
		questionButtons = questionButtons,
		input = input,
		sendButton = sendButton,
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
	local checking = false -- Sparky is checking a question
	local answerAt = 0 -- os.clock() when Earth's answer is due (0 = nothing on the way)
	local talk = ReplicatedStorage:WaitForChild("SparkyTalk", 30)

	-- Questions not asked yet come first; an asked one moves to the end of the queue.
	local queue = {}
	for _, q in SparkyQuestions.list do
		table.insert(queue, q)
	end
	local shown: { SparkyQuestions.Question } = {}

	local function canAsk(): boolean
		return not checking and answerAt == 0
	end

	local function refreshButtons()
		table.clear(shown)
		for i, button in dialog.questionButtons do
			local q = queue[i]
			shown[i] = q
			button.Visible = q ~= nil and canAsk()
			if q then
				button.Text = Strings.get(q.question, lang)
			end
		end
		dialog.sendButton.Visible = canAsk()
		dialog.input.TextEditable = canAsk()
	end

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
		dialog.input:ReleaseFocus()
		setOpen(false)
		if talk and talk:IsA("RemoteEvent") then
			talk:FireServer("bye")
		end
	end

	local function send(action: string, value: string)
		if canAsk() and talk and talk:IsA("RemoteEvent") then
			talk:FireServer(action, value)
		end
	end

	local function sendTyped()
		local text = string.sub((string.gsub(dialog.input.Text, "^%s+", "")), 1, MAX_CHARS)
		if text == "" or not canAsk() then
			return
		end
		dialog.input.Text = ""
		send("chat", text)
	end

	dialog.byeButton.Activated:Connect(close)
	dialog.sendButton.Activated:Connect(sendTyped)
	dialog.input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			sendTyped()
		end
	end)
	dialog.input:GetPropertyChangedSignal("Text"):Connect(function()
		if #dialog.input.Text > MAX_CHARS then
			dialog.input.Text = string.sub(dialog.input.Text, 1, MAX_CHARS)
		end
	end)
	for i, button in dialog.questionButtons do
		button.Activated:Connect(function()
			local q = shown[i]
			if not q or not canAsk() then
				return
			end
			local index = table.find(queue, q)
			if index then
				table.remove(queue, index)
				table.insert(queue, q)
			end
			send("ask", q.id)
		end)
	end
	dialog.box.Activated:Connect(function()
		if typingFor == token then
			token += 1 -- finish this line first
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if dialog.gui.Enabled and input.KeyCode == Enum.KeyCode.Escape then
			close()
		end
	end)

	-- Countdown to Earth's answer (game minutes) and closing when the player walks away.
	task.spawn(function()
		while dialog.gui.Parent do
			if answerAt > 0 then
				local left = answerAt - os.clock()
				if left <= 0 then
					answerAt = 0
					dialog.status.Visible = false
					refreshButtons()
				else
					local minutes = math.max(1, math.ceil(left * 24 * 60 / Config.SolSeconds))
					dialog.status.Text = Strings.get("sparky.chat.waiting", lang, { min = minutes })
					dialog.status.Visible = true
				end
			end
			if dialog.gui.Enabled then
				local character = Players.LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not (root and root:IsA("BasePart")) or (root.Position - body.Position).Magnitude > TALK_DISTANCE then
					close()
				end
			end
			task.wait(0.2)
		end
	end)

	local say = ReplicatedStorage:WaitForChild("SparkySay", 30)
	if not (say and say:IsA("RemoteEvent")) then
		return
	end
	-- keyOrText: an i18n key, or plain text (Earth's answers, EventDirector).
	-- kind: nil | "thinking" | "earth" (extra = AI wrote it)
	--   | "sending" (extra = seconds until the answer, info = { min, date, live, source }).
	say.OnClientEvent:Connect(function(keyOrText: string, kind: string?, extra: unknown, info: unknown)
		token += 1
		local myToken = token
		checking = kind == "thinking"
		local text
		if kind == "sending" then
			answerAt = os.clock() + (if typeof(extra) == "number" then extra else 0)
			local delay = if typeof(info) == "table" then info :: any else {}
			text = Strings.get(keyOrText, lang, { min = tostring(delay.min or "?") })
			-- Where today's delay comes from: LIVE only when fetched this session.
			local label = Strings.get(
				if delay.live then "weather.label.live" else "weather.label.archived",
				lang,
				{ date = tostring(delay.date or "") }
			)
			dialog.note.Text = "📡 " .. tostring(delay.source or "") .. " · " .. label
			dialog.note.Visible = true
		elseif kind == "earth" then
			answerAt = 0
			dialog.status.Visible = false
			text = Strings.get("sparky.chat.earth", lang, { text = keyOrText })
			dialog.note.Text = "🤖 " .. Strings.get("sparky.ai.note", lang)
			dialog.note.Visible = extra == true
		else
			text = Strings.get(keyOrText, lang)
			dialog.note.Visible = false
		end
		local length = utf8.len(text) or #text
		dialog.label.Text = text
		refreshButtons()
		setOpen(true)
		if checking then
			dialog.label.MaxVisibleGraphemes = -1
			return
		end

		dialog.label.MaxVisibleGraphemes = 0
		typingFor = myToken
		local shownChars = 0
		while shownChars < length and token == myToken do
			shownChars += 1
			dialog.label.MaxVisibleGraphemes = shownChars
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
