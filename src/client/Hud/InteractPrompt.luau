--!strict
-- Bottom-centre prompt "[E] Fix the pump". Draws every ProximityPrompt in the HUD style
-- (prompts are switched to Custom style locally) and works by tap on touch screens.
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Strings = require(ReplicatedStorage.Shared.Strings)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local KEY_SIZE = 22

local InteractPrompt = {}

local function useCustomStyle(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		instance.Style = Enum.ProximityPromptStyle.Custom
	end
end

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string?
	if inputType == Enum.ProximityPromptInputType.Keyboard then
		return prompt.KeyboardKeyCode.Name
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return (string.gsub(prompt.GamepadKeyCode.Name, "^Button", ""))
	end
	return nil -- touch: the whole prompt is the button
end

function InteractPrompt.new(parent: Instance, lang: Strings.Lang)
	for _, d in workspace:GetDescendants() do
		useCustomStyle(d)
	end
	workspace.DescendantAdded:Connect(useCustomStyle)

	local button = Instance.new("TextButton")
	button.Name = "Prompt"
	button.Text = ""
	button.AutoButtonColor = false
	button.AutomaticSize = Enum.AutomaticSize.XY
	button.Size = UDim2.new()
	button.BackgroundColor3 = Theme.Panel
	button.BackgroundTransparency = Theme.PanelTransparency
	button.BorderSizePixel = 0
	button.Visible = false
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = button
	Widgets.row(button, 10)

	local key = Instance.new("Frame")
	key.Name = "Key"
	key.LayoutOrder = 1
	key.BorderSizePixel = 0
	key.BackgroundColor3 = Theme.Key
	key.Size = UDim2.fromOffset(KEY_SIZE, KEY_SIZE)
	key.Parent = button
	local keyLabel = Widgets.label("KeyText", Theme.KeyText)
	keyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	keyLabel.Position = UDim2.fromScale(0.5, 0.5)
	keyLabel.Parent = key

	local action = Widgets.label("Action", Theme.Text)
	action.LayoutOrder = 2
	action.Parent = button

	-- Hold progress: a thin line along the bottom edge.
	local progress = Instance.new("Frame")
	progress.Name = "Progress"
	progress.BorderSizePixel = 0
	progress.BackgroundColor3 = Theme.Key
	progress.AnchorPoint = Vector2.new(0, 1)
	progress.Position = UDim2.new(0, -6, 1, 6)
	progress.Size = UDim2.fromOffset(0, 2)
	progress.ZIndex = 2
	progress.Parent = button

	button.Parent = parent

	local shown: { ProximityPrompt } = {}
	local current: ProximityPrompt? = nil
	local currentInput = Enum.ProximityPromptInputType.Keyboard
	local holdTween: Tween? = nil

	local function resetProgress()
		if holdTween then
			holdTween:Cancel()
			holdTween = nil
		end
		progress.Size = UDim2.fromOffset(0, 2)
	end

	local function render()
		current = shown[#shown]
		resetProgress()
		local prompt = current
		if not prompt then
			button.Visible = false
			return
		end
		local text = keyText(prompt, currentInput)
		key.Visible = text ~= nil
		keyLabel.Text = text or ""
		action.Text = if prompt.ObjectText ~= ""
			then Strings.get("hud.prompt.withObject", lang, { action = prompt.ActionText, object = prompt.ObjectText })
			else prompt.ActionText
		button.Visible = true
	end

	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		currentInput = inputType
		table.insert(shown, prompt)
		render()
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local index = table.find(shown, prompt)
		if index then
			table.remove(shown, index)
			render()
		end
	end)

	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if prompt == current and prompt.HoldDuration > 0 then
			resetProgress()
			local tween = TweenService:Create(
				progress,
				TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear),
				{ Size = UDim2.new(1, 18, 0, 2) }
			)
			holdTween = tween
			tween:Play()
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		if prompt == current then
			resetProgress()
		end
	end)

	-- Mouse and touch: pressing the prompt holds its button.
	button.MouseButton1Down:Connect(function()
		if current then
			current:InputHoldBegin()
		end
	end)
	local function release()
		if current then
			current:InputHoldEnd()
		end
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

return InteractPrompt
