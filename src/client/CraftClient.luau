--!strict
-- Shows the sample bag, carried spare parts, the shared base store and short messages
-- from the server Crafting module. Read-only view: the server owns the numbers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CraftConfig = require(ReplicatedStorage.Shared.CraftConfig)
local CropModels = require(ReplicatedStorage.Shared.CropModels)
local WaterBottle = require(ReplicatedStorage.Shared.WaterBottle)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Style = require(ReplicatedStorage.Shared.NoticeStyle)

local CraftClient = {}

local TOAST_SECONDS = 3.5
local SLOT = 54 -- inventory slot size, pixels

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
	toast.Position = UDim2.new(0.5, 0, 1, -114)
	toast.Size = UDim2.fromOffset(560, 34)
	toast.AutomaticSize = Enum.AutomaticSize.Y -- long messages wrap onto more lines
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = toast
	toast.BackgroundColor3 = Color3.fromRGB(34, 40, 58)
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	toast.FontFace = Style.Bold
	toast.TextSize = Style.TextSize
	toast.TextWrapped = true
	toast.TextColor3 = Style.TextColor
	toast.Parent = gui
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 6)
	toastCorner.Parent = toast

	-- Inventory: one slot per bag place, each shows a 3D copy of the picked sample -----------
	local inv = Instance.new("Frame")
	inv.Name = "Inventory"
	inv.AnchorPoint = Vector2.new(0.5, 1)
	inv.Position = UDim2.new(0.5, 0, 1, -50)
	inv.Size = UDim2.fromOffset(0, SLOT)
	inv.AutomaticSize = Enum.AutomaticSize.X
	inv.BackgroundTransparency = 1
	inv.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = inv

	local spinning: { Model } = {}
	RunService.RenderStepped:Connect(function()
		local rot = CFrame.Angles(0, os.clock() * 0.8, 0)
		for _, m in spinning do
			m:PivotTo(rot)
		end
	end)

	-- Puts a 3D copy of item into the viewport and returns it.
	local function fillViewport(vf: ViewportFrame, item: Instance): Model
		local model = Instance.new("Model")
		local copy = item:Clone()
		copy.Parent = model
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local cf, size = model:GetBoundingBox()
		model:PivotTo(model:GetPivot() - cf.Position)
		model.WorldPivot = CFrame.identity -- spin around the centre of the sample
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		local dist = size.Magnitude * 1.9
		cam.CFrame = CFrame.lookAt(Vector3.new(dist * 0.7, dist * 0.5, dist * 0.7), Vector3.zero)
		cam.Parent = vf
		vf.CurrentCamera = cam
		model.Parent = vf
		return model
	end

	local function showInSlot(vf: ViewportFrame, item: Instance)
		table.insert(spinning, fillViewport(vf, item))
	end

	local function partIcon(vf: ViewportFrame)
		local board = Instance.new("Part")
		board.Size = Vector3.new(0.9, 0.12, 0.6)
		board.Color = Color3.fromRGB(25, 70, 40)
		local chip = Instance.new("Part")
		chip.Size = Vector3.new(0.3, 0.08, 0.3)
		chip.Material = Enum.Material.Neon
		chip.Color = Color3.fromRGB(90, 255, 140)
		chip.CFrame = CFrame.new(0.1, 0.1, 0)
		chip.Parent = board
		showInSlot(vf, board)
	end

	local function slot(order: number, filled: boolean, tint: Color3?): ViewportFrame
		local vf = Instance.new("ViewportFrame")
		vf.LayoutOrder = order
		vf.Size = UDim2.fromOffset(SLOT, SLOT)
		vf.BackgroundColor3 = tint or Color3.fromRGB(22, 26, 38)
		vf.BackgroundTransparency = if filled then 0.1 else 0.55
		vf.Ambient = Color3.fromRGB(160, 160, 165)
		vf.LightColor = Color3.new(1, 1, 1)
		vf.LightDirection = Vector3.new(-1, -1.5, -0.6)
		vf.Parent = inv
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = vf
		local s = Instance.new("UIStroke")
		s.Color = if filled then Color3.fromRGB(150, 160, 185) else Color3.fromRGB(70, 78, 96)
		s.Parent = vf
		return vf
	end

	local bagView: Instance? = nil
	local cropView: Instance? = nil
	local function renderInventory()
		table.clear(spinning)
		for _, child in inv:GetChildren() do
			if child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end
		-- One bag of CraftConfig.BagSize places: samples first, then seed packets and harvest from
		-- the greenhouse (Player.CropBag, server: Crops.luau). The server keeps the total <= BagSize.
		local items: { Instance } = if bagView then bagView:GetChildren() else {}
		local crops: { Instance } = {}
		if cropView then
			for _, item in cropView:GetChildren() do
				if item:IsA("StringValue") then
					table.insert(crops, item)
				end
			end
			table.sort(crops, function(a, b)
				return num(a, "Order") < num(b, "Order")
			end)
		end
		for i = 1, CraftConfig.BagSize do
			local sample = items[i]
			local crop = if sample then nil else crops[i - #items]
			if sample then
				showInSlot(slot(i, true), sample)
			elseif crop and crop:IsA("StringValue") and crop.Name == WaterBottle.KIND then
				showInSlot(slot(i, true, Color3.fromRGB(26, 44, 66)), WaterBottle.model()) -- ice melter bottle
			elseif crop and crop:IsA("StringValue") then
				local seed = crop.Name == "Seed"
				local tint = if seed then Color3.fromRGB(44, 40, 30) else Color3.fromRGB(32, 50, 34)
				local model = if seed then CropModels.packet(crop.Value) else CropModels.produce(crop.Value, i)
				showInSlot(slot(i, true, tint), model)
			else
				slot(i, false)
			end
		end
		for i = 1, num(player, "CarryParts") do
			partIcon(slot(100 + i, true, Color3.fromRGB(30, 44, 70)))
		end
	end
	player:GetAttributeChangedSignal("CarryParts"):Connect(renderInventory)
	renderInventory()
	task.spawn(function()
		local folder = player:WaitForChild("SampleBag", 30)
		if folder then
			bagView = folder
			folder.ChildAdded:Connect(renderInventory)
			folder.ChildRemoved:Connect(renderInventory)
			renderInventory()
		end
	end)

	local function cropCount(): number
		return if cropView then #cropView:GetChildren() else 0
	end

	local function render()
		local parts = {
			t("craft.hud.bag", { n = num(player, "BagSamples") + cropCount(), max = CraftConfig.BagSize }),
			t("craft.hud.parts", { n = num(player, "CarryParts") }),
			t("craft.hud.store", {
				iron = num(store, "Iron"),
				nickel = num(store, "Nickel"),
				manganese = num(store, "Manganese"),
				parts = num(store, "Parts"),
			}),
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
	for _, key in { "Iron", "Nickel", "Manganese", "Parts" } do
		store:GetAttributeChangedSignal(key):Connect(render)
	end
	render()
	task.spawn(function()
		local folder = player:WaitForChild("CropBag", 60)
		if folder then
			cropView = folder
			local function changed()
				renderInventory()
				render()
			end
			folder.ChildAdded:Connect(changed)
			folder.ChildRemoved:Connect(changed)
			changed()
		end
	end)

	local toastId = 0
	local fade = TweenInfo.new(0.25)
	notify.OnClientEvent:Connect(function(key: string, vars: { [string]: string | number }?)
		toastId += 1
		local id = toastId
		-- a crop id in vars ("Lettuce") becomes its name in the player's language
		if vars and typeof(vars.crop) == "string" then
			local named = table.clone(vars)
			named.crop = t("crop.name." .. vars.crop)
			vars = named
		end
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
