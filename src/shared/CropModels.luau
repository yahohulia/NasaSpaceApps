--!strict
-- 3D models of the crops, built from parts so they live in git and grow in stages:
-- a sprout, then the plant gets bigger, and fruit / roots / ears show up near the end.
-- CropModels.build(id, growth 0..1, seed, height) returns a Model at the origin: the base of the
-- plant is at (0, 0, 0), it grows up along +Y. The caller moves it with PivotTo.
-- Shapes follow what NASA grew (kb/data/space-crops.md); sizes and colours are game art.
local CropModels = {}

local function smooth(a: number): number
	local x = math.clamp(a, 0, 1)
	return x * x * (3 - 2 * x)
end

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, math.clamp(t, 0, 1))
end

local function tint(c: Color3, rng: Random, amount: number): Color3
	local k = 1 + (rng:NextNumber() - 0.5) * amount
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(math.max(size.X, 0.02), math.max(size.Y, 0.02), math.max(size.Z, 0.02))
	p.CFrame = cf
	p.Color = color
	p.Parent = model
	return p
end

-- An ellipsoid (leaf, fruit, root): a part with a sphere mesh that fills the part's size.
local function blob(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = part(model, name, size, cf, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function stick(model: Model, name: string, from: Vector3, to: Vector3, width: number, color: Color3): Part
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local cf = CFrame.lookAt(mid, to) * CFrame.Angles(math.rad(90), 0, 0)
	return part(model, name, Vector3.new(width, length, width), cf, color)
end

-- A leaf that starts at `base`, points at yaw `yaw` (radians around Y) and leans out by `tilt`
-- (0 = straight up, pi/2 = flat). Its long side is `length`, `width` across, `thick` thin.
local function leaf(
	model: Model,
	base: Vector3,
	yaw: number,
	tilt: number,
	length: number,
	width: number,
	thick: number,
	color: Color3
): Part
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-tilt, 0, 0) * CFrame.new(0, length / 2, 0)
	return blob(model, "Leaf", Vector3.new(width, length, thick), cf, color)
end

local GREEN = Color3.fromRGB(86, 160, 64)
local DARK_GREEN = Color3.fromRGB(46, 112, 44)
local STEM = Color3.fromRGB(96, 140, 60)

local function sprout(model: Model, h: number, rng: Random)
	local top = Vector3.new(0, h * 0.6, 0)
	stick(model, "Stem", Vector3.zero, top, 0.03, STEM)
	local yaw = rng:NextNumber() * math.pi
	for i = 0, 1 do
		leaf(model, top, yaw + i * math.pi, math.rad(70), h * 0.45, h * 0.3, 0.02, GREEN)
	end
end

type Builder = (model: Model, h: number, g: number, rng: Random) -> ()

local builders: { [string]: Builder } = {}

-- Red romaine lettuce 'Outredgeous' (Veggie): a rosette of long red leaves, greener inside.
builders.Lettuce = function(model, h, _g, rng)
	local n = 8
	for i = 1, n do
		local yaw = (i / n) * math.pi * 2 + rng:NextNumber() * 0.4
		local outer = i % 2 == 0
		local color = if outer then Color3.fromRGB(128, 28, 52) else Color3.fromRGB(150, 96, 70)
		leaf(
			model,
			Vector3.zero,
			yaw,
			math.rad(if outer then 38 else 18),
			h * 0.95,
			h * 0.42,
			0.04,
			tint(color, rng, 0.2)
		)
	end
	blob(
		model,
		"Heart",
		Vector3.new(h * 0.25, h * 0.5, h * 0.25),
		CFrame.new(0, h * 0.25, 0),
		Color3.fromRGB(120, 150, 60)
	)
end

-- Mizuna mustard (Veggie VEG-04): many thin, light green leaves fanning out.
builders.Mizuna = function(model, h, _g, rng)
	local n = 14
	for i = 1, n do
		local yaw = (i / n) * math.pi * 2 + rng:NextNumber() * 0.5
		local tilt = math.rad(15 + rng:NextNumber() * 45)
		leaf(
			model,
			Vector3.zero,
			yaw,
			tilt,
			h * (0.75 + rng:NextNumber() * 0.25),
			h * 0.12,
			0.03,
			tint(GREEN, rng, 0.25)
		)
	end
end

-- Radish (Plant Habitat-02): broad leaves and a red root that swells near the end.
builders.Radish = function(model, h, g, rng)
	for i = 1, 5 do
		local yaw = (i / 5) * math.pi * 2 + rng:NextNumber() * 0.5
		leaf(
			model,
			Vector3.new(0, h * 0.1, 0),
			yaw,
			math.rad(25 + rng:NextNumber() * 20),
			h * 0.8,
			h * 0.32,
			0.03,
			tint(DARK_GREEN, rng, 0.2)
		)
	end
	local r = h * (0.08 + 0.22 * smooth((g - 0.4) / 0.6))
	blob(model, "Root", Vector3.new(r * 2, r * 2, r * 2), CFrame.new(0, r * 0.8, 0), Color3.fromRGB(206, 36, 70))
	blob(
		model,
		"RootTip",
		Vector3.new(r * 0.5, r * 0.9, r * 0.5),
		CFrame.new(0, r * 0.05, 0),
		Color3.fromRGB(240, 236, 230)
	)
end

-- Dwarf wheat 'Apogee' (Advanced Plant Habitat): thin stalks, ears at the top that turn golden.
builders.Wheat = function(model, h, g, rng)
	local golden = smooth((g - 0.75) / 0.25)
	local stalk = lerpColor(Color3.fromRGB(110, 170, 70), Color3.fromRGB(214, 180, 90), golden)
	for _ = 1, 9 do
		local base = Vector3.new((rng:NextNumber() - 0.5) * h * 0.25, 0, (rng:NextNumber() - 0.5) * h * 0.25)
		local lean = Vector3.new((rng:NextNumber() - 0.5) * h * 0.35, 0, (rng:NextNumber() - 0.5) * h * 0.35)
		local top = base + lean + Vector3.new(0, h * (0.85 + rng:NextNumber() * 0.15), 0)
		stick(model, "Stalk", base, top, 0.035, tint(stalk, rng, 0.1))
		if g > 0.55 then
			local ear = smooth((g - 0.55) / 0.3)
			local dir = (top - base).Unit
			local cf = CFrame.lookAt(top, top + dir) * CFrame.Angles(math.rad(90), 0, 0)
			blob(
				model,
				"Ear",
				Vector3.new(0.07, h * 0.22 * ear + 0.02, 0.07),
				cf,
				lerpColor(Color3.fromRGB(150, 190, 80), Color3.fromRGB(232, 196, 100), golden)
			)
		end
	end
	for i = 1, 4 do
		leaf(
			model,
			Vector3.new(0, h * 0.15, 0),
			i * 1.6,
			math.rad(35),
			h * 0.55,
			0.05,
			0.02,
			Color3.fromRGB(100, 160, 70)
		)
	end
end

local function bush(model: Model, h: number, rng: Random, leafColor: Color3, clusters: number): { Vector3 }
	local top = Vector3.new(0, h * 0.85, 0)
	stick(model, "Stem", Vector3.zero, top, 0.05, STEM)
	local spots = {}
	for i = 1, clusters do
		local y = h * (0.25 + 0.6 * (i / clusters))
		local yaw = i * 2.4 + rng:NextNumber() * 0.5
		local out = Vector3.new(math.cos(yaw), 0, math.sin(yaw)) * h * 0.22
		local at = Vector3.new(0, y, 0) + out
		stick(model, "Branch", Vector3.new(0, y - h * 0.08, 0), at, 0.03, STEM)
		for k = 0, 2 do
			leaf(model, at, yaw + (k - 1) * 0.7, math.rad(65), h * 0.3, h * 0.16, 0.03, tint(leafColor, rng, 0.2))
		end
		table.insert(spots, at)
	end
	return spots
end

-- Dwarf tomato 'Red Robin' (Veggie VEG-05): a small bush with cherry tomatoes, green then red.
builders.Tomato = function(model, h, g, rng)
	local spots = bush(model, h, rng, Color3.fromRGB(52, 120, 46), 5)
	if g > 0.55 then
		local ripe = smooth((g - 0.8) / 0.2)
		local size = 0.06 + 0.07 * smooth((g - 0.55) / 0.3)
		local color = lerpColor(Color3.fromRGB(120, 180, 70), Color3.fromRGB(222, 40, 30), ripe)
		for i, at in spots do
			if i > 1 then
				for k = 0, 1 do
					local p = at
						+ Vector3.new(
							(rng:NextNumber() - 0.5) * 0.12,
							-0.08 - k * 0.07,
							(rng:NextNumber() - 0.5) * 0.12
						)
					blob(model, "Fruit", Vector3.new(size, size, size), CFrame.new(p), tint(color, rng, 0.1))
				end
			end
		end
	end
end

-- Chile pepper 'Española Improved' (Plant Habitat-04): a glossy bush with long peppers that redden.
builders.Pepper = function(model, h, g, rng)
	local spots = bush(model, h, rng, Color3.fromRGB(36, 128, 52), 5)
	if g > 0.55 then
		local ripe = smooth((g - 0.85) / 0.15)
		local len = 0.08 + 0.16 * smooth((g - 0.55) / 0.3)
		local color = lerpColor(Color3.fromRGB(60, 150, 50), Color3.fromRGB(200, 28, 28), ripe)
		for i, at in spots do
			if i > 1 then
				local p = at
					+ Vector3.new((rng:NextNumber() - 0.5) * 0.1, -len / 2 - 0.04, (rng:NextNumber() - 0.5) * 0.1)
				local cf = CFrame.new(p) * CFrame.Angles(0, 0, math.rad((rng:NextNumber() - 0.5) * 30))
				blob(model, "Fruit", Vector3.new(0.07, len, 0.07), cf, tint(color, rng, 0.08))
			end
		end
	end
end

-- Builds the plant `id` at `growth` (0..1). `seed` keeps each plant's random look stable.
function CropModels.build(id: string, growth: number, seed: number, height: number): Model
	local model = Instance.new("Model")
	model.Name = id
	local rng = Random.new(seed)
	local g = math.clamp(growth, 0, 1)
	local h = height * (0.2 + 0.8 * smooth(g))
	local builder = builders[id]
	if g < 0.12 or not builder then
		sprout(model, height * 0.35, rng)
	else
		builder(model, h, g, rng)
	end
	model.WorldPivot = CFrame.identity
	return model
end

-- Growth stage shown to players: 1 sprout, 2 growing, 3 ready to harvest.
function CropModels.stage(growth: number): number
	if growth >= 1 then
		return 3
	elseif growth < 0.12 then
		return 1
	end
	return 2
end

return CropModels
