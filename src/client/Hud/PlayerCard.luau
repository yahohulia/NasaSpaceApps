--!strict
-- Bottom-left card: role badge, role name, personal radiation dose. Data: the local Player's attributes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(ReplicatedStorage.Shared.Strings)
local PixelIcon = require(script.Parent.PixelIcon)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local WIDTH = 214
local BADGE = 28

local PlayerCard = {}

function PlayerCard.new(parent: Instance, lang: Strings.Lang, player: Player)
	local panel = Widgets.panel("PlayerCard", Theme.Card)
	Widgets.row(panel, 10)

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.LayoutOrder = 1
	badge.BorderSizePixel = 0
	badge.Size = UDim2.fromOffset(BADGE, BADGE)
	badge.BackgroundColor3 = Theme.Border
	badge.Parent = panel

	local info = Instance.new("Frame")
	info.Name = "Info"
	info.LayoutOrder = 2
	info.BackgroundTransparency = 1
	info.Size = UDim2.fromOffset(WIDTH - BADGE - 10, BADGE)
	info.Parent = panel

	local roleName = Widgets.label("Role", Theme.Text)
	roleName.Parent = info

	local doseLabel = Widgets.label("DoseLabel", Theme.MutedText, Theme.SmallTextSize)
	doseLabel.AnchorPoint = Vector2.new(1, 0)
	doseLabel.Position = UDim2.fromScale(1, 0)
	doseLabel.Text = Strings.get("hud.dose", lang)
	doseLabel.Parent = info

	local cells = Config.Hud.Segments
	local cellWidth = math.floor((info.Size.X.Offset - (cells - 1) * 2) / cells)
	local bar = Widgets.segmentBar("DoseBar", cells, cellWidth, 6)
	bar.frame.AnchorPoint = Vector2.new(0, 1)
	bar.frame.Position = UDim2.fromScale(0, 1)
	bar.frame.Parent = info

	panel.Parent = parent

	local icon: PixelIcon.Icon? = nil
	local function updateRole()
		local role = player:GetAttribute(Config.PlayerAttributes.Role)
		local known = typeof(role) == "string" and table.find(Config.Roles, role :: any) ~= nil
		if icon then
			icon.frame:Destroy()
			icon = nil
		end
		if known then
			local r = role :: string
			roleName.Text = Strings.get(`hud.role.{r}`, lang)
			badge.BackgroundColor3 = Theme.RoleColors[r]
			local newIcon = PixelIcon.new(r, 3, Theme.Text)
			newIcon.frame.AnchorPoint = Vector2.new(0.5, 0.5)
			newIcon.frame.Position = UDim2.fromScale(0.5, 0.5)
			newIcon.frame.Parent = badge
			icon = newIcon
		else
			roleName.Text = Strings.get("hud.role.none", lang)
			badge.BackgroundColor3 = Theme.Border
		end
	end

	local function updateDose()
		local dose = player:GetAttribute(Config.PlayerAttributes.Dose)
		local value = if typeof(dose) == "number" then dose else 0
		bar.set(value / Config.Dose.Limit, Theme.Dose)
	end

	player:GetAttributeChangedSignal(Config.PlayerAttributes.Role):Connect(updateRole)
	player:GetAttributeChangedSignal(Config.PlayerAttributes.Dose):Connect(updateDose)
	updateRole()
	updateDose()
end

return PlayerCard
