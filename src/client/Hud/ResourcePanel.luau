--!strict
-- Top-left panel: "Sol 12" | Oxygen | Water | Food, as segmented bars. Data: Remotes.ResourcesChanged.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local PixelIcon = require(script.Parent.PixelIcon)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local COLORS: { [Config.ResourceName]: Color3 } = {
	Oxygen = Theme.Oxygen,
	Water = Theme.Water,
	Food = Theme.Food,
}

local ResourcePanel = {}

function ResourcePanel.new(parent: Instance, lang: Strings.Lang): (Remotes.ResourceSnapshot) -> ()
	local panel = Widgets.panel("Resources", Theme.Border)
	Widgets.row(panel, 14)

	local sol = Widgets.label("Sol", Theme.Text)
	sol.LayoutOrder = 1
	sol.Text = Strings.get("hud.sol", lang, { n = "-" })
	sol.Parent = panel

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.LayoutOrder = 2
	divider.BorderSizePixel = 0
	divider.BackgroundColor3 = Theme.Border
	divider.Size = UDim2.fromOffset(2, 18)
	divider.Parent = panel

	local slots: { [Config.ResourceName]: { icon: PixelIcon.Icon, bar: Widgets.Bar } } = {}
	for i, name in Config.Resources do
		local group = Instance.new("Frame")
		group.Name = name
		group.LayoutOrder = 2 + i
		group.BackgroundTransparency = 1
		group.AutomaticSize = Enum.AutomaticSize.XY
		group.Size = UDim2.new()
		Widgets.row(group, 6)

		local icon = PixelIcon.new(name, 2, COLORS[name])
		icon.frame.LayoutOrder = 1
		icon.frame.Parent = group
		local bar = Widgets.segmentBar("Bar", Config.Hud.Segments, 5, 10)
		bar.frame.LayoutOrder = 2
		bar.frame.Parent = group
		bar.set(0, COLORS[name])

		group.Parent = panel
		slots[name] = { icon = icon, bar = bar }
	end

	panel.Parent = parent

	return function(snapshot: Remotes.ResourceSnapshot)
		sol.Text = Strings.get("hud.sol", lang, { n = snapshot.sol })
		for name, slot in slots do
			local value = snapshot.resources[name]
			if value and value.capacity > 0 then
				local fraction = value.amount / value.capacity
				local color = if fraction <= Config.Hud.LowFraction then Theme.Warning else COLORS[name]
				slot.bar.set(fraction, color)
				slot.icon.setColor(color)
			end
		end
	end
end

return ResourcePanel
