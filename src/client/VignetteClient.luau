-- Soft vignette: the screen edges fade to dark, like in horror games but much
-- lighter (kids 7-12). Four edge frames with gradients, no image asset needed.
-- It sits under every other GUI (DisplayOrder -10), so HUDs stay on top.
local Players = game:GetService("Players")

local DARKNESS = 0.55 -- 0 = no effect, 1 = black edges (horror games go ~0.8)
local REACH = 0.36 -- how far the shade reaches in from each edge (share of the screen)
local COLOR = Color3.fromRGB(8, 6, 6)

local VignetteClient = {}

-- One edge: a frame along a side whose shade fades from the edge inward.
local function edge(parent: Instance, name: string, size: UDim2, position: UDim2, rotation: number)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = COLOR
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	-- Dark at the edge (offset 0), clear further in; eased so the fade looks round.
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - DARKNESS),
		NumberSequenceKeypoint.new(0.35, 1 - DARKNESS * 0.45),
		NumberSequenceKeypoint.new(0.7, 1 - DARKNESS * 0.12),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = frame
	frame.Parent = parent
end

function VignetteClient.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Vignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -10

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Active = false
	root.Parent = gui

	edge(root, "Top", UDim2.fromScale(1, REACH), UDim2.fromScale(0, 0), 90)
	edge(root, "Bottom", UDim2.fromScale(1, REACH), UDim2.fromScale(0, 1 - REACH), 270)
	edge(root, "Left", UDim2.fromScale(REACH, 1), UDim2.fromScale(0, 0), 0)
	edge(root, "Right", UDim2.fromScale(REACH, 1), UDim2.fromScale(1 - REACH, 0), 180)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return VignetteClient
