-- Crew roles on the client: a role picker (shown on join and from the HUD chip),
-- a "You: <role>" chip, and a role tag above other players' heads.
-- Tags are built locally so each player sees them in their own language.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roles = require(ReplicatedStorage.Shared.Roles)
local Strings = require(ReplicatedStorage.Shared.Strings)

local PANEL = Color3.fromRGB(27, 35, 48)
local TEXT = Color3.fromRGB(225, 232, 238)
local DIM = Color3.fromRGB(150, 162, 176)

local RoleClient = {}

local function corner(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function text(
	parent: Instance,
	name: string,
	order: number,
	size: number,
	color: Color3,
	bold: boolean
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.LayoutOrder = order
	l.Size = UDim2.fromScale(1, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.Text = ""
	l.Parent = parent
	return l
end

local function roleCounts(): { [string]: number }
	local result = {}
	for _, player in Players:GetPlayers() do
		local role = player:GetAttribute(Roles.ATTRIBUTE)
		if type(role) == "string" then
			result[role] = (result[role] or 0) + 1
		end
	end
	return result
end

function RoleClient.start()
	local me = Players.LocalPlayer
	local lang = Strings.langFromLocale(me.LocaleId)
	local playerGui = me:WaitForChild("PlayerGui") :: PlayerGui
	local choose = ReplicatedStorage:WaitForChild("ChooseRole") :: RemoteEvent

	local function roleName(id: string): string
		return Strings.get(`role.{id}.name`, lang)
	end

	-- Picker -------------------------------------------------------------
	local picker = Instance.new("ScreenGui")
	picker.Name = "RolePicker"
	picker.ResetOnSpawn = false
	picker.DisplayOrder = 20
	picker.Enabled = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.94, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = PANEL
	panel.BorderSizePixel = 0
	panel.Parent = picker
	corner(panel, 6)
	stroke(panel, DIM, 2)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(720, math.huge)
	limit.Parent = panel
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(pad :: any)[side] = UDim.new(0, 14)
	end
	pad.Parent = panel
	local column = Instance.new("UIListLayout")
	column.SortOrder = Enum.SortOrder.LayoutOrder
	column.Padding = UDim.new(0, 10)
	column.Parent = panel

	local title = text(panel, "Title", 1, 24, TEXT, true)
	title.Text = Strings.get("role.pick.title", lang)

	local row = Instance.new("Frame")
	row.Name = "Cards"
	row.LayoutOrder = 2
	row.Size = UDim2.fromScale(1, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.BackgroundTransparency = 1
	row.Parent = panel
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0.015, 0)
	rowLayout.Parent = row

	local cards: { [string]: { stroke: UIStroke, count: TextLabel } } = {}
	for index, id in Roles.ids do
		local role = Roles.byId[id]
		local card = Instance.new("TextButton")
		card.Name = id
		card.LayoutOrder = index
		card.Size = UDim2.fromScale(0.323, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.BackgroundColor3 = Color3.fromRGB(38, 48, 64)
		card.AutoButtonColor = true
		card.Text = ""
		card.Parent = row
		corner(card, 6)
		local cardStroke = stroke(card, role.color, 2)
		local cardPad = Instance.new("UIPadding")
		for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
			(cardPad :: any)[side] = UDim.new(0, 10)
		end
		cardPad.Parent = card
		local cardList = Instance.new("UIListLayout")
		cardList.SortOrder = Enum.SortOrder.LayoutOrder
		cardList.Padding = UDim.new(0, 6)
		cardList.Parent = card

		text(card, "Icon", 1, 34, role.color, true).Text = role.icon
		text(card, "Name", 2, 20, role.color, true).Text = roleName(id)
		text(card, "Duty", 3, 15, TEXT, false).Text = Strings.get(`role.{id}.duty`, lang)
		local count = text(card, "Count", 4, 14, DIM, false)

		card.Activated:Connect(function()
			choose:FireServer(id)
			picker.Enabled = false
		end)
		cards[id] = { stroke = cardStroke, count = count }
	end

	local hint = text(panel, "Hint", 3, 14, DIM, false)
	hint.Text = Strings.get("role.pick.hint", lang)
	picker.Parent = playerGui

	-- HUD chip -------------------------------------------------------------
	local hud = Instance.new("ScreenGui")
	hud.Name = "RoleChip"
	hud.ResetOnSpawn = false
	hud.DisplayOrder = 8
	local chip = Instance.new("TextButton")
	chip.Name = "Chip"
	chip.Position = UDim2.fromOffset(16, 70)
	chip.Size = UDim2.fromOffset(0, 34)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundColor3 = PANEL
	chip.BackgroundTransparency = 0.1
	chip.Font = Enum.Font.GothamBold
	chip.TextSize = 16
	chip.TextColor3 = TEXT
	chip.Text = ""
	chip.Parent = hud
	corner(chip, 6)
	local chipStroke = stroke(chip, DIM, 2)
	local chipPad = Instance.new("UIPadding")
	chipPad.PaddingLeft = UDim.new(0, 12)
	chipPad.PaddingRight = UDim.new(0, 12)
	chipPad.Parent = chip
	chip.Activated:Connect(function()
		picker.Enabled = not picker.Enabled
	end)
	hud.Parent = playerGui

	-- Tags above other players --------------------------------------------
	local tags: { [Player]: BillboardGui } = {}

	local function updateTag(player: Player)
		local old = tags[player]
		if old then
			old:Destroy()
			tags[player] = nil
		end
		local role = Roles.byId[player:GetAttribute(Roles.ATTRIBUTE) :: any]
		local head = player.Character and player.Character:FindFirstChild("Head")
		if player == me or not role or not head then
			return
		end
		local tag = Instance.new("BillboardGui")
		tag.Name = `RoleTag_{player.UserId}`
		tag.Adornee = head :: BasePart
		tag.Size = UDim2.fromOffset(160, 26)
		tag.StudsOffset = Vector3.new(0, 3.4, 0)
		tag.AlwaysOnTop = true
		tag.MaxDistance = 60
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 16
		label.TextColor3 = role.color
		label.TextStrokeTransparency = 0.4
		label.Text = `{role.icon} {roleName(role.id)}`
		label.Parent = tag
		tag.Parent = playerGui
		tags[player] = tag
	end

	-- Refresh everything that depends on roles.
	local shownOnce = false
	local function refresh()
		local counts = roleCounts()
		local mine = me:GetAttribute(Roles.ATTRIBUTE)
		for id, card in cards do
			card.count.Text = Strings.get("role.pick.count", lang, { count = counts[id] or 0 })
			card.stroke.Thickness = if id == mine then 4 else 2
		end
		local role = Roles.byId[mine :: any]
		if role then
			chip.Text = `{role.icon} {Strings.get("role.hud.you", lang, { role = roleName(role.id) })} · {Strings.get(
				"role.hud.change",
				lang
			)}`
			chipStroke.Color = role.color
			if not shownOnce then
				shownOnce = true
				picker.Enabled = true
			end
		end
	end

	local function watch(player: Player)
		player:GetAttributeChangedSignal(Roles.ATTRIBUTE):Connect(function()
			updateTag(player)
			refresh()
		end)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			updateTag(player)
		end)
		if player.Character then
			updateTag(player)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		watch(player)
		refresh()
	end)
	Players.PlayerRemoving:Connect(function(player)
		local tag = tags[player]
		if tag then
			tag:Destroy()
			tags[player] = nil
		end
		task.defer(refresh)
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	refresh()
end

return RoleClient
