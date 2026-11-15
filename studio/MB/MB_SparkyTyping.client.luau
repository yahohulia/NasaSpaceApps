-- MB_SparkyTyping (StarterPlayerScripts): typewriter sound while Sparky's dialog text is being typed.
-- Watches the SparkyDialog ScreenGui made by the Rojo client (SparkyClient) without changing it:
-- it types by raising Text.MaxVisibleGraphemes and sets it to -1 when the line is complete.
-- The sound plays only while letters are appearing and stops as soon as typing ends or the box closes.
-- Copy of the script that lives in the team place (studio/MB in the repo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("MB_Config"))
local T = Config.SparkyTyping
if not T or T.SoundId == "" then
	warn("[MB_SparkyTyping] set MB_Config.SparkyTyping.SoundId")
	return
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local random = Random.new()

local sound = Instance.new("Sound")
sound.Name = "MB_SparkyTyping"
sound.SoundId = T.SoundId
sound.Looped = true
sound.Volume = T.Volume
sound.Parent = SoundService

local function watch(gui: ScreenGui)
	local label = gui:FindFirstChild("Text", true)
	if not (label and label:IsA("TextLabel")) then
		return
	end

	local function update()
		local shown = label.MaxVisibleGraphemes
		local total = utf8.len(label.Text) or #label.Text
		local typing = gui.Enabled and shown >= 0 and shown < total
		if typing and not sound.IsPlaying then
			-- Start somewhere in the recording so every line sounds a little different.
			sound.TimePosition = random:NextNumber(0, math.max(0, sound.TimeLength - 3))
			sound:Play()
		elseif not typing and sound.IsPlaying then
			sound:Stop()
		end
	end

	label:GetPropertyChangedSignal("MaxVisibleGraphemes"):Connect(update)
	label:GetPropertyChangedSignal("Text"):Connect(update)
	gui:GetPropertyChangedSignal("Enabled"):Connect(update)
	gui.AncestryChanged:Connect(function(_, parent)
		if not parent then
			sound:Stop()
		end
	end)
	update()
end

local existing = playerGui:FindFirstChild("SparkyDialog")
if existing and existing:IsA("ScreenGui") then
	watch(existing)
end
playerGui.ChildAdded:Connect(function(child)
	if child.Name == "SparkyDialog" and child:IsA("ScreenGui") then
		task.defer(watch, child) -- let SparkyClient finish building the box first
	end
end)
