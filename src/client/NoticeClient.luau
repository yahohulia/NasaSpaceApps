-- Toasts sent by the server through the Notice RemoteEvent (key + kind + vars).
-- One toast at a time, above Sparky's dialog; a new one replaces the old.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Strings = require(ReplicatedStorage.Shared.Strings)

local SHOW_SECONDS = 5
local KIND_COLOR = {
	info = Color3.fromRGB(110, 170, 240),
	warn = Color3.fromRGB(240, 200, 70),
	alert = Color3.fromRGB(230, 80, 80),
}

local NoticeClient = {}

function NoticeClient.start()
	local me = Players.LocalPlayer
	local lang = Strings.langFromLocale(me.LocaleId)
	local remote = ReplicatedStorage:WaitForChild("Notice") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "Toast"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.Enabled = false

	local box = Instance.new("TextLabel")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -170)
	box.Size = UDim2.fromScale(0.9, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.BackgroundColor3 = Color3.fromRGB(27, 35, 48)
	box.BackgroundTransparency = 0.05
	box.Font = Enum.Font.GothamBold
	box.TextSize = 18
	box.TextColor3 = Color3.fromRGB(240, 244, 248)
	box.TextWrapped = true
	box.Text = ""
	box.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, math.huge)
	limit.Parent = box
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = box
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = box
	gui.Parent = me:WaitForChild("PlayerGui")

	local token = 0
	remote.OnClientEvent:Connect(function(key: string, kind: string, vars: { [string]: string | number })
		token += 1
		local mine = token
		box.Text = Strings.get(key, lang, vars)
		stroke.Color = KIND_COLOR[kind] or KIND_COLOR.info
		box.BackgroundTransparency = 0.05
		box.TextTransparency = 0
		gui.Enabled = true
		task.delay(SHOW_SECONDS, function()
			if mine ~= token then
				return
			end
			local info = TweenInfo.new(0.4)
			TweenService:Create(box, info, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.wait(0.4)
			if mine == token then
				gui.Enabled = false
			end
		end)
	end)
end

return NoticeClient
