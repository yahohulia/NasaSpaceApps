--!strict
-- Shows the sample bag, carried spare parts, the shared base store and short messages
-- from the server Crafting module. Read-only view: the server owns the numbers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CraftConfig = require(ReplicatedStorage.Shared.CraftConfig)
local Strings = require(ReplicatedStorage.Shared.Strings)

local CraftClient = {}

local TOAST_SECONDS = 3.5

local function num(inst: Instance, key: string): number
	local v = inst:GetAttribute(key)
	return if typeof(v) == "number" then v else 0
end

function CraftClient.start()
	local player = Players.LocalPlayer
	local lang = Strings.langFromLocale(player.LocaleId)
	local notify = ReplicatedStorage:WaitForChild("CraftNotify") :: RemoteEvent
	local store = ReplicatedStorage:WaitForChild("MB_BaseState")

	local function t(key: string, vars: { [string]: string | number }?): string
		return Strings.get(key, lang, vars)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CraftHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -12)
	panel.Size = UDim2.fromOffset(460, 30)
	panel.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
	panel.BackgroundTransparency = 0.15
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 100, 120)
	stroke.Parent = panel

	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.Size = UDim2.fromScale(1, 1)
	line.Font = Enum.Font.GothamMedium
	line.TextSize = 15
	line.TextColor3 = Color3.fromRGB(230, 234, 242)
	line.Parent = panel

	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -52)
	toast.Size = UDim2.fromOffset(520, 34)
	toast.BackgroundColor3 = Color3.fromRGB(34, 40, 58)
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 16
	toast.TextWrapped = true
	toast.TextColor3 = Color3.fromRGB(255, 236, 170)
	toast.Parent = gui
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 6)
	toastCorner.Parent = toast

	local function render()
		local parts = {
			t("craft.hud.bag", { n = num(player, "BagSamples"), max = CraftConfig.BagSize }),
			t("craft.hud.parts", { n = num(player, "CarryParts") }),
			t("craft.hud.store", { iron = num(store, "Iron"), parts = num(store, "Parts") }),
		}
		if player:GetAttribute("CarryingDrill") == true then
			table.insert(parts, t("craft.hud.carry"))
		end
		line.Text = table.concat(parts, "   ·   ")
		panel.Size = UDim2.fromOffset(math.max(360, line.TextBounds.X + 32), 30)
	end

	for _, key in { "BagSamples", "CarryParts", "CarryingDrill" } do
		player:GetAttributeChangedSignal(key):Connect(render)
	end
	for _, key in { "Iron", "Parts" } do
		store:GetAttributeChangedSignal(key):Connect(render)
	end
	render()

	local toastId = 0
	local fade = TweenInfo.new(0.25)
	notify.OnClientEvent:Connect(function(key: string, vars: { [string]: string | number }?)
		toastId += 1
		local id = toastId
		toast.Text = t(key, vars)
		TweenService:Create(toast, fade, { TextTransparency = 0, BackgroundTransparency = 0.1 }):Play()
		task.delay(TOAST_SECONDS, function()
			if id == toastId then
				TweenService:Create(toast, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			end
		end)
	end)
end

return CraftClient
