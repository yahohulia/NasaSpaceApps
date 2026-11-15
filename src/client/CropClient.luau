--!strict
-- Greenhouse crops on the client (server: Crops.luau). Read-only view:
--  * the seed crate picker (6 crops with a 3D model, NASA days and food),
--  * the "Eat" button (key G) for harvest in the crop bag (the bag itself is in CraftClient),
--  * labels over planted racks (growth, "needs care", "ready"),
--  * the greenhouse journal board: which crop grows best on our Mars base,
--  * prompt texts in the player's language.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CropConfig = require(ReplicatedStorage.Shared.CropConfig)
local CropModels = require(ReplicatedStorage.Shared.CropModels)
local Strings = require(ReplicatedStorage.Shared.Strings)

local CropClient = {}

local BG = Color3.fromRGB(18, 22, 32)
local CARD = Color3.fromRGB(30, 36, 52)
local TEXT = Color3.fromRGB(232, 236, 244)
local DIM = Color3.fromRGB(170, 178, 196)
local ACCENT = Color3.fromRGB(255, 220, 120)
local GOOD = Color3.fromRGB(140, 235, 150)
local WARN = Color3.fromRGB(255, 170, 90)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = color or TEXT
	l.TextWrapped = true
	l.Text = ""
	l.Parent = parent
	return l
end

local function minutes(seconds: number): string
	local s = math.floor(seconds + 0.5)
	return string.format("%d:%02d", s // 60, s % 60)
end

function CropClient.start()
	local player = Players.LocalPlayer
	local lang = Strings.langFromLocale(player.LocaleId)
	local function t(key: string, vars: { [string]: string | number }?): string
		return Strings.get(key, lang, vars)
	end
	local function cropName(id: string): string
		return t("crop.name." .. id)
	end
	local pick = ReplicatedStorage:WaitForChild("CropPick") :: RemoteEvent
	local playerGui = player:WaitForChild("PlayerGui")

	-- Spinning 3D models in viewports --------------------------------------------------------
	local spinning: { Model } = {}
	local spinOn = false -- only while the picker is open: six 3D plants every frame cost a lot
	RunService.RenderStepped:Connect(function()
		if not spinOn then
			return
		end
		local rot = CFrame.Angles(0, os.clock() * 0.7, 0)
		for _, m in spinning do
			if m.Parent then
				m:PivotTo(rot)
			end
		end
	end)

	local function cropViewport(parent: Instance, id: string): ViewportFrame
		local vf = Instance.new("ViewportFrame")
		vf.BackgroundTransparency = 1
		vf.Ambient = Color3.fromRGB(170, 170, 175)
		vf.LightColor = Color3.new(1, 1, 1)
		vf.LightDirection = Vector3.new(-1, -1.5, -0.6)
		vf.Parent = parent
		local model = CropModels.build(id, 1, 7, 1)
		local cf, size = model:GetBoundingBox()
		model:PivotTo(model:GetPivot() - cf.Position)
		model.WorldPivot = CFrame.identity
		model.Parent = vf
		local cam = Instance.new("Camera")
		cam.FieldOfView = 32
		local d = size.Magnitude * 1.7
		cam.CFrame = CFrame.lookAt(Vector3.new(d * 0.7, d * 0.45, d * 0.7), Vector3.zero)
		cam.Parent = vf
		vf.CurrentCamera = cam
		table.insert(spinning, model)
		return vf
	end

	-- Seed crate picker ----------------------------------------------------------------------
	local pickGui = Instance.new("ScreenGui")
	pickGui.Name = "CropPicker"
	pickGui.ResetOnSpawn = false
	pickGui.Enabled = false
	pickGui.DisplayOrder = 16
	pickGui.Parent = playerGui

	local win = Instance.new("Frame")
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.fromScale(0.5, 0.5)
	win.Size = UDim2.fromOffset(780, 470)
	win.BackgroundColor3 = BG
	win.BackgroundTransparency = 0.04
	win.Parent = pickGui
	corner(win, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 100, 120)
	stroke.Parent = win
	local scale = Instance.new("UIScale")
	scale.Parent = win
	local function fit()
		local cam = workspace.CurrentCamera
		local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.min(1, (vp.X - 24) / 780, (vp.Y - 24) / 470)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	local title = label(win, 24, ACCENT)
	title.Font = Enum.Font.GothamBold
	title.Position = UDim2.fromOffset(20, 12)
	title.Size = UDim2.new(1, -180, 0, 32)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = t("crop.pick.title")

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(20, 54)
	grid.Size = UDim2.new(1, -40, 0, 350)
	grid.Parent = win
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(236, 168)
	layout.CellPadding = UDim2.fromOffset(10, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grid

	local pickMode = "take" -- "take": all crops from the crate; "plant": the seeds in the bag
	local pickRack: Instance? = nil
	local cards: { [string]: TextButton } = {}

	local function closePicker()
		pickGui.Enabled = false
		spinOn = false
		pickRack = nil
		UserInputService.MouseIconEnabled = false -- first person hides the cursor
	end

	for i, crop in CropConfig.Crops do
		local card = Instance.new("TextButton")
		card.LayoutOrder = i
		card.Text = ""
		card.AutoButtonColor = true
		card.BackgroundColor3 = CARD
		card.Parent = grid
		corner(card, 8)
		local band = Instance.new("Frame")
		band.BackgroundColor3 = crop.color
		band.BorderSizePixel = 0
		band.Size = UDim2.new(0, 6, 1, 0)
		band.Parent = card
		corner(band, 3)
		local vf = cropViewport(card, crop.id)
		vf.Position = UDim2.fromOffset(10, 8)
		vf.Size = UDim2.fromOffset(110, 150)
		local name = label(card, 19)
		name.Font = Enum.Font.GothamBold
		name.Position = UDim2.fromOffset(122, 12)
		name.Size = UDim2.new(1, -128, 0, 26)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = cropName(crop.id)
		local days = label(card, 14, DIM)
		days.Position = UDim2.fromOffset(122, 44)
		days.Size = UDim2.new(1, -128, 0, 40)
		days.TextXAlignment = Enum.TextXAlignment.Left
		days.TextYAlignment = Enum.TextYAlignment.Top
		days.Text = t("crop.pick.days", { days = crop.realDays })
		local food = label(card, 14, GOOD)
		food.Position = UDim2.fromOffset(122, 88)
		food.Size = UDim2.new(1, -128, 0, 20)
		food.TextXAlignment = Enum.TextXAlignment.Left
		food.Text = t("crop.pick.food", { food = crop.food })
		local care = label(card, 13, DIM)
		care.Position = UDim2.fromOffset(122, 112)
		care.Size = UDim2.new(1, -128, 0, 40)
		care.TextXAlignment = Enum.TextXAlignment.Left
		care.TextYAlignment = Enum.TextYAlignment.Top
		care.Text = t("crop.pick.care", { n = #crop.carePoints })
		card.Activated:Connect(function()
			if pickMode == "plant" then
				if pickRack then
					pick:FireServer("plant", pickRack, crop.id)
				end
			else
				pick:FireServer("take", crop.id)
			end
			closePicker()
		end)
		cards[crop.id] = card
	end

	local note = label(win, 14, DIM)
	note.Position = UDim2.fromOffset(20, 414)
	note.Size = UDim2.new(1, -190, 0, 44)
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.Text = t("crop.pick.note")

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -16, 0, 418)
	close.Size = UDim2.fromOffset(140, 36)
	close.BackgroundColor3 = Color3.fromRGB(44, 52, 74)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 18
	close.TextColor3 = TEXT
	close.Text = t("crop.pick.close")
	close.Modal = true -- frees the first-person mouse while the window is open
	close.Parent = win
	corner(close, 6)
	close.Activated:Connect(closePicker)

	local function openPicker(mode: string, kinds: { string }?)
		pickMode = mode
		local allowed: { [string]: boolean } = {}
		for _, id in kinds or {} do
			allowed[id] = true
		end
		for id, card in cards do
			card.Visible = kinds == nil or allowed[id] == true
		end
		title.Text = if mode == "plant" then t("crop.pick.plantTitle") else t("crop.pick.title")
		pickGui.Enabled = true
		spinOn = true
		UserInputService.MouseIconEnabled = true
	end

	pick.OnClientEvent:Connect(function(action: string, data: any)
		if action == "open" then
			pickRack = nil
			openPicker("take", nil)
		elseif action == "plant" and typeof(data) == "table" then
			pickRack = data.rack
			openPicker("plant", data.kinds)
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if pickGui.Enabled and input.KeyCode == Enum.KeyCode.Escape then
			closePicker()
		end
	end)

	-- The crop bag (Player.CropBag): seed packets and harvest. CraftClient shows them in the
	-- inventory bar; here: the "Eat" button (key G) and which seeds the planting prompt offers.
	local bag: Instance? = nil
	local function bagItems(kind: string): { StringValue }
		local list = {}
		if bag then
			for _, item in bag:GetChildren() do
				if item:IsA("StringValue") and item.Name == kind then
					table.insert(list, item)
				end
			end
		end
		table.sort(list, function(a, b)
			local x, y = a:GetAttribute("Order"), b:GetAttribute("Order")
			return (if typeof(x) == "number" then x else 0) < (if typeof(y) == "number" then y else 0)
		end)
		return list
	end

	local eatGui = Instance.new("ScreenGui")
	eatGui.Name = "CropEat"
	eatGui.ResetOnSpawn = false
	eatGui.Parent = playerGui
	local eatButton = Instance.new("TextButton")
	eatButton.AnchorPoint = Vector2.new(1, 1)
	eatButton.Position = UDim2.new(1, -16, 1, -16)
	eatButton.Size = UDim2.fromOffset(0, 38)
	eatButton.AutomaticSize = Enum.AutomaticSize.X
	eatButton.BackgroundColor3 = Color3.fromRGB(40, 70, 46)
	eatButton.BackgroundTransparency = 0.1
	eatButton.Font = Enum.Font.GothamBold
	eatButton.TextSize = 17
	eatButton.TextColor3 = TEXT
	eatButton.Visible = false
	eatButton.Parent = eatGui
	corner(eatButton, 8)
	local eatPad = Instance.new("UIPadding")
	eatPad.PaddingLeft = UDim.new(0, 14)
	eatPad.PaddingRight = UDim.new(0, 14)
	eatPad.Parent = eatButton
	local eatStroke = Instance.new("UIStroke")
	eatStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	eatStroke.Color = Color3.fromRGB(110, 180, 110)
	eatStroke.Parent = eatButton

	local function eat()
		if #bagItems("Produce") > 0 then
			pick:FireServer("eat")
		end
	end
	eatButton.Activated:Connect(eat)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.G then
			eat()
		end
	end)

	-- Prompt texts in the player's language ----------------------------------------------------
	local function seedKinds(): { string }
		local kinds: { string } = {}
		local seen: { [string]: boolean } = {}
		for _, item in bagItems("Seed") do
			if not seen[item.Value] then
				seen[item.Value] = true
				table.insert(kinds, item.Value)
			end
		end
		return kinds
	end

	local function relabel(prompt: ProximityPrompt)
		local mode = prompt:GetAttribute("CropMode")
		if mode == "crate" then
			prompt.ActionText = t("crop.prompt.take")
			prompt.ObjectText = t("crop.object.crate")
		elseif mode == "plant" then
			local kinds = seedKinds()
			prompt.ActionText = if #kinds == 1
				then t("crop.prompt.plant", { crop = cropName(kinds[1]) })
				else t("crop.prompt.plantAny")
			prompt.ObjectText = t("crop.object.rack")
			-- only players with seed packets see the planting prompt (fewer prompts in the rows)
			local want = #kinds > 0
			if prompt.Enabled ~= want then
				prompt.Enabled = want
			end
		elseif mode == "harvest" then
			prompt.ActionText = t("crop.prompt.harvest")
			prompt.ObjectText = t("crop.object.rack")
		end
	end

	local prompts: { ProximityPrompt } = {}
	local function track(inst: Instance)
		if inst:IsA("ProximityPrompt") and (inst.Name == "CropPrompt" or inst.Name == "CropCratePrompt") then
			table.insert(prompts, inst)
			inst:GetAttributeChangedSignal("CropMode"):Connect(function()
				relabel(inst)
			end)
			inst:GetPropertyChangedSignal("ActionText"):Connect(function()
				relabel(inst)
			end)
			inst:GetPropertyChangedSignal("Enabled"):Connect(function()
				if inst:GetAttribute("CropMode") == "plant" then
					relabel(inst)
				end
			end)
			relabel(inst)
		end
	end
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt:GetAttribute("CropMode") ~= nil then
			relabel(prompt)
		end
	end)

	local function onBag()
		local produce = bagItems("Produce")
		eatButton.Visible = #produce > 0
		if #produce > 0 then
			eatButton.Text = t("crop.eat", { crop = cropName(produce[1].Value) })
		end
		for _, prompt in prompts do
			if prompt.Parent then
				relabel(prompt)
			end
		end
	end
	task.spawn(function()
		local folder = player:WaitForChild("CropBag", 60)
		if folder then
			bag = folder
			folder.ChildAdded:Connect(onBag)
			folder.ChildRemoved:Connect(onBag)
			onBag()
		end
	end)

	-- Labels over planted racks --------------------------------------------------------------
	local function rackLabel(model: Model)
		local frame = model:WaitForChild(CropConfig.RackFramePart, 10)
		local at = frame and frame:WaitForChild("CropInfoAt", 30)
		if not (at and at:IsA("Attachment")) then
			return
		end
		local board = Instance.new("BillboardGui")
		board.Name = "CropInfo_" .. model.Name
		board.Adornee = at
		board.Size = UDim2.fromOffset(170, 52)
		board.MaxDistance = 28
		board.LightInfluence = 0
		board.Enabled = false
		board.Parent = playerGui
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = BG
		bg.BackgroundTransparency = 0.25
		bg.Parent = board
		corner(bg, 6)
		local name = label(bg, 15)
		name.Font = Enum.Font.GothamBold
		name.Position = UDim2.fromOffset(6, 2)
		name.Size = UDim2.new(1, -12, 0, 20)
		local barBack = Instance.new("Frame")
		barBack.Position = UDim2.fromOffset(8, 24)
		barBack.Size = UDim2.new(1, -16, 0, 7)
		barBack.BackgroundColor3 = Color3.fromRGB(50, 56, 72)
		barBack.Parent = bg
		corner(barBack, 3)
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(0, 1)
		bar.BackgroundColor3 = GOOD
		bar.Parent = barBack
		corner(bar, 3)
		local status = label(bg, 13, DIM)
		status.Position = UDim2.fromOffset(6, 33)
		status.Size = UDim2.new(1, -12, 0, 16)

		local function update()
			local crop = model:GetAttribute("Crop")
			if typeof(crop) ~= "string" then
				board.Enabled = false
				return
			end
			board.Enabled = true
			local growth = model:GetAttribute("Growth")
			local g = if typeof(growth) == "number" then growth else 0
			bar.Size = UDim2.fromScale(math.clamp(g, 0, 1), 1)
			name.Text = t("crop.info.growing", { crop = cropName(crop), pct = math.floor(g * 100) })
			if model:GetAttribute("Ready") == true then
				status.Text = t("crop.info.ready")
				status.TextColor3 = GOOD
				bar.BackgroundColor3 = GOOD
			elseif model:GetAttribute(CropConfig.CareAttribute) == true then
				status.Text = t("crop.info.care")
				status.TextColor3 = WARN
				bar.BackgroundColor3 = WARN
			else
				local health = model:GetAttribute("Health")
				local h = if typeof(health) == "number" then health else 1
				status.Text = t("crop.info.health", { pct = math.floor(h * 100) })
				status.TextColor3 = DIM
				bar.BackgroundColor3 = GOOD
			end
		end
		for _, key in { "Crop", "Growth", "Ready", "Health", CropConfig.CareAttribute } do
			model:GetAttributeChangedSignal(key):Connect(update)
		end
		update()
	end

	task.spawn(function()
		local folder = workspace:WaitForChild(CropConfig.RackFolder, 60)
		if not folder then
			return
		end
		for _, model in folder:GetChildren() do
			if model:IsA("Model") then
				task.spawn(rackLabel, model)
			end
		end
		for _, d in folder:GetDescendants() do
			track(d)
		end
		folder.DescendantAdded:Connect(track)
	end)
	for _, crate in CollectionService:GetTagged(CropConfig.SeedCrateTag) do
		for _, d in crate:GetDescendants() do
			track(d)
		end
		crate.DescendantAdded:Connect(track)
	end
	CollectionService:GetInstanceAddedSignal(CropConfig.SeedCrateTag):Connect(function(crate)
		for _, d in crate:GetDescendants() do
			track(d)
		end
		crate.DescendantAdded:Connect(track)
	end)

	-- Greenhouse journal board ---------------------------------------------------------------
	local stats = ReplicatedStorage:WaitForChild("CropStats", 30)
	local function journal(part: Instance)
		if not part:IsA("BasePart") or not stats then
			return
		end
		local sg = Instance.new("SurfaceGui")
		sg.Name = "CropJournal"
		sg.Adornee = part
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.CanvasSize = Vector2.new(900, 900 * part.Size.Y / part.Size.X)
		sg.LightInfluence = 0
		sg.Parent = playerGui
		local root = Instance.new("Frame")
		root.Size = UDim2.fromScale(1, 1)
		root.BackgroundColor3 = BG
		root.Parent = sg
		local head = label(root, 34, ACCENT)
		head.Font = Enum.Font.GothamBold
		head.Position = UDim2.fromOffset(24, 14)
		head.Size = UDim2.new(1, -48, 0, 44)
		head.Text = t("crop.journal.title")

		local cols = { 0.03, 0.31, 0.47, 0.62, 0.77 }
		local headers = {
			"crop.journal.crop",
			"crop.journal.nasa",
			"crop.journal.harvests",
			"crop.journal.time",
			"crop.journal.food",
		}
		local top = 70
		for i, key in headers do
			local h = label(root, 20, DIM)
			h.Position = UDim2.new(cols[i], 0, 0, top)
			h.Size = UDim2.new(0.18, 0, 0, 44)
			h.TextXAlignment = Enum.TextXAlignment.Left
			h.Text = t(key)
		end
		local rows: { { TextLabel } } = {}
		local rowH = 52
		for i, crop in CropConfig.Crops do
			local y = top + 48 + (i - 1) * rowH
			local swatch = Instance.new("Frame")
			swatch.Position = UDim2.new(cols[1], 0, 0, y + 14)
			swatch.Size = UDim2.fromOffset(16, 22)
			swatch.BackgroundColor3 = crop.color
			swatch.Parent = root
			corner(swatch, 3)
			local cells: { TextLabel } = {}
			for c = 1, 5 do
				local cell = label(root, 24)
				cell.Position = UDim2.new(cols[c], if c == 1 then 26 else 0, 0, y)
				cell.Size = UDim2.new(0.2, 0, 0, rowH)
				cell.TextXAlignment = Enum.TextXAlignment.Left
				cells[c] = cell
			end
			cells[1].Text = cropName(crop.id)
			cells[2].Text = tostring(crop.realDays)
			rows[i] = cells
		end
		local best = label(root, 22, GOOD)
		best.Font = Enum.Font.GothamBold
		best.Position = UDim2.fromOffset(24, top + 48 + #CropConfig.Crops * rowH + 6)
		best.Size = UDim2.new(1, -48, 0, 34)
		local foot = label(root, 18, DIM)
		foot.Position = UDim2.fromOffset(24, top + 48 + #CropConfig.Crops * rowH + 44)
		foot.Size = UDim2.new(1, -48, 0, 60)
		foot.Text = t("crop.journal.note")

		local function refresh()
			local bestId: string? = nil
			local bestRate = 0
			for i, crop in CropConfig.Crops do
				local n = stats:GetAttribute(crop.id .. "_Harvests")
				local harvests = if typeof(n) == "number" then n else 0
				local secondsV = stats:GetAttribute(crop.id .. "_Seconds")
				local foodV = stats:GetAttribute(crop.id .. "_Food")
				local seconds = if typeof(secondsV) == "number" then secondsV else 0
				local food = if typeof(foodV) == "number" then foodV else 0
				local cells = rows[i]
				cells[3].Text = tostring(harvests)
				if harvests > 0 then
					cells[4].Text = minutes(seconds / harvests)
					cells[5].Text = tostring(math.floor(food / harvests + 0.5))
					local rate = if seconds > 0 then food / seconds else 0
					if rate > bestRate then
						bestRate = rate
						bestId = crop.id
					end
				else
					cells[4].Text = t("crop.journal.none")
					cells[5].Text = t("crop.journal.none")
				end
			end
			best.Text = if bestId then t("crop.journal.best", { crop = cropName(bestId) }) else t("crop.journal.empty")
		end
		stats.AttributeChanged:Connect(refresh)
		refresh()
	end
	for _, part in CollectionService:GetTagged(CropConfig.JournalTag) do
		journal(part)
	end
	CollectionService:GetInstanceAddedSignal(CropConfig.JournalTag):Connect(journal)
end

return CropClient
