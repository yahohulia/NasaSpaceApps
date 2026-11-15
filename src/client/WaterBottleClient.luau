--!strict
-- "Drink water [V]" button (above CropClient's "Eat" button, bottom right) while the bag holds a bottle
-- of water from the ice melter (Player.CropBag items named WaterBottle.KIND). Server: WaterBottles.luau.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Strings = require(ReplicatedStorage.Shared.Strings)
local WaterBottle = require(ReplicatedStorage.Shared.WaterBottle)

local WaterBottleClient = {}

function WaterBottleClient.start()
	local player = Players.LocalPlayer
	local lang = Strings.langFromLocale(player.LocaleId)
	local remote = ReplicatedStorage:WaitForChild("WaterDrink", 60)
	if not (remote and remote:IsA("RemoteEvent")) then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "WaterDrink"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -16, 1, -62) -- just above the "Eat" button
	button.Size = UDim2.fromOffset(0, 38)
	button.AutomaticSize = Enum.AutomaticSize.X
	button.BackgroundColor3 = Color3.fromRGB(34, 70, 110)
	button.BackgroundTransparency = 0.1
	button.Font = Enum.Font.GothamBold
	button.TextSize = 17
	button.TextColor3 = Color3.fromRGB(240, 246, 250)
	button.Visible = false
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(110, 170, 230)
	stroke.Parent = button

	local bag: Instance? = nil
	local function count(): number
		local n = 0
		if bag then
			for _, item in bag:GetChildren() do
				if item:IsA("StringValue") and item.Name == WaterBottle.KIND then
					n += 1
				end
			end
		end
		return n
	end
	local function refresh()
		local n = count()
		button.Visible = n > 0
		button.Text = Strings.get("water.drink", lang, { n = n, key = WaterBottle.KEY.Name })
	end
	local function drink()
		if count() > 0 then
			(remote :: RemoteEvent):FireServer()
		end
	end
	button.Activated:Connect(drink)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == WaterBottle.KEY then
			drink()
		end
	end)

	local folder = player:WaitForChild("CropBag", 60)
	if folder then
		bag = folder
		folder.ChildAdded:Connect(refresh)
		folder.ChildRemoved:Connect(refresh)
		refresh()
	end
end

return WaterBottleClient
