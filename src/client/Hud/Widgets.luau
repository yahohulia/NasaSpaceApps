--!strict
-- Small building blocks for the HUD: panels, labels, segmented bars.
local Theme = require(script.Parent.Theme)

local Widgets = {}

-- Dark panel with a 2 px border that grows to fit its children.
function Widgets.panel(name: string, border: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.new()
	frame.BackgroundColor3 = Theme.Panel
	frame.BackgroundTransparency = Theme.PanelTransparency
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = border
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = frame
	return frame
end

function Widgets.row(parent: Instance, gap: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
	return layout
end

function Widgets.label(name: string, color: Color3, size: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.new()
	label.BackgroundTransparency = 1
	label.FontFace = Theme.Font
	label.TextSize = size or Theme.TextSize
	label.TextColor3 = color
	label.Text = ""
	return label
end

export type Bar = {
	frame: Frame,
	set: (fraction: number, color: Color3) -> (),
}

-- Row of cells; set(0.35, colour) fills 4 of 10 cells (any amount above zero shows at least one cell).
function Widgets.segmentBar(name: string, count: number, cellWidth: number, cellHeight: number): Bar
	local gap = 2
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(count * cellWidth + (count - 1) * gap, cellHeight)

	local cells: { Frame } = {}
	for i = 1, count do
		local cell = Instance.new("Frame")
		cell.Name = `Cell{i}`
		cell.BorderSizePixel = 0
		cell.BackgroundColor3 = Theme.EmptyCell
		cell.Size = UDim2.fromOffset(cellWidth, cellHeight)
		cell.Position = UDim2.fromOffset((i - 1) * (cellWidth + gap), 0)
		cell.Parent = frame
		cells[i] = cell
	end

	return {
		frame = frame,
		set = function(fraction: number, color: Color3)
			local f = math.clamp(fraction, 0, 1)
			local filled = if f <= 0 then 0 else math.max(1, math.round(f * count))
			for i, cell in cells do
				cell.BackgroundColor3 = if i <= filled then color else Theme.EmptyCell
			end
		end,
	}
end

return Widgets
