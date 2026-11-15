--!strict
-- Pixel-art icons drawn from small bitmaps with Frames, so the HUD needs no uploaded images.
-- "#" is a filled pixel, "." is empty.

local BITMAPS: { [string]: { string } } = {
	Oxygen = {
		"....##.",
		"......#",
		"######.",
		".......",
		"####...",
		".......",
		"#####..",
	},
	Water = {
		"...#...",
		"..###..",
		".#####.",
		".#####.",
		"#######",
		"#######",
		".#####.",
	},
	Food = {
		"#.....#",
		"##...##",
		".##.##.",
		"..###..",
		"...#...",
		"...#...",
		"...#...",
	},
	Sun = {
		"...#...",
		".#...#.",
		"..###..",
		"#.###.#",
		"..###..",
		".#...#.",
		"...#...",
	},
	Alert = {
		"##",
		"##",
		"##",
		"##",
		"..",
		"##",
	},
	-- Edge arrows. GuiObject.Rotation does not turn the pixel children, so each direction has its own bitmap.
	ChevronLeft = {
		"..#",
		".##",
		"##.",
		".##",
		"..#",
	},
	ChevronRight = {
		"#..",
		"##.",
		".##",
		"##.",
		"#..",
	},
	ChevronUp = {
		"..#..",
		".###.",
		"##.##",
	},
	ChevronDown = {
		"##.##",
		".###.",
		"..#..",
	},
	Engineer = {
		"#.#....",
		"###....",
		".###...",
		"..###..",
		"...###.",
		"....###",
		".....##",
	},
	Botanist = {
		"#.....#",
		"##...##",
		".##.##.",
		"..###..",
		"...#...",
		"...#...",
		"...#...",
	},
	Driller = {
		".#####.",
		"..###..",
		"..###..",
		"..###..",
		"...#...",
		"...#...",
		"...#...",
	},
}

export type Icon = {
	frame: Frame,
	setColor: (Color3) -> (),
}

local PixelIcon = {}

function PixelIcon.new(name: string, pixel: number, color: Color3): Icon
	local rows = BITMAPS[name]
	assert(rows, `unknown icon {name}`)
	local frame = Instance.new("Frame")
	frame.Name = `{name}Icon`
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(#rows[1] * pixel, #rows * pixel)

	local pixels: { Frame } = {}
	for y, row in rows do
		for x = 1, #row do
			if string.sub(row, x, x) == "#" then
				local p = Instance.new("Frame")
				p.BorderSizePixel = 0
				p.BackgroundColor3 = color
				p.Size = UDim2.fromOffset(pixel, pixel)
				p.Position = UDim2.fromOffset((x - 1) * pixel, (y - 1) * pixel)
				p.Parent = frame
				table.insert(pixels, p)
			end
		end
	end

	return {
		frame = frame,
		setColor = function(c: Color3)
			for _, p in pixels do
				p.BackgroundColor3 = c
			end
		end,
	}
end

return PixelIcon
