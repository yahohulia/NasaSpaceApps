--!strict
-- 3D models of the crops, built from parts so they live in git:
--  * CropModels.build(id, growth 0..1, seed, height): the plant on a rack. It grows in stages: a
--    sprout, then the plant gets bigger, fruit / roots / ears show up near the end.
--  * CropModels.produce(id, seed): the harvest in the inventory (a lettuce head, radishes...).
--  * CropModels.packet(id): a seed packet.
-- Every model is built at the origin (the base of a plant at (0, 0, 0), up along +Y); the caller
-- moves it with PivotTo. Shapes follow what NASA grew (kb/data/space-crops.md). The look aims at
-- "real plants" rather than toys: muted natural colours that vary from leaf to leaf, darker leaf
-- undersides, thin wooden stems, glossy fruit.
local CropConfig = require(script.Parent.CropConfig)

local CropModels = {}

local function smooth(a: number): number
	local x = math.clamp(a, 0, 1)
	return x * x * (3 - 2 * x)
end

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, math.clamp(t, 0, 1))
end

-- A natural colour: random brightness and a small hue shift per leaf.
local function vary(c: Color3, rng: Random, amount: number): Color3
	local h, s, v = c:ToHSV()
	h = (h + (rng:NextNumber() - 0.5) * amount * 0.08) % 1
	s = math.clamp(s * (1 + (rng:NextNumber() - 0.5) * amount), 0, 1)
	v = math.clamp(v * (1 + (rng:NextNumber() - 0.5) * amount), 0, 1)
	return Color3.fromHSV(h, s, v)
end

local function part(
	model: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	reflectance: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.SmoothPlastic
	p.Reflectance = reflectance or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(math.max(size.X, 0.02), math.max(size.Y, 0.02), math.max(size.Z, 0.02))
	p.CFrame = cf
	p.Color = color
	p.Parent = model
	return p
end

-- An ellipsoid (leaf, fruit, root): a part with a sphere mesh that fills the part's size.
local function blob(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, gloss: number?): Part
	local p = part(model, name, size, cf, color, Enum.Material.SmoothPlastic, gloss)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function stick(model: Model, name: string, from: Vector3, to: Vector3, width: number, color: Color3): Part
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	local cf = CFrame.lookAt(mid, to) * CFrame.Angles(math.rad(90), 0, 0)
	return part(model, name, Vector3.new(width, length, width), cf, color, Enum.Material.Wood)
end

-- A leaf from `base`, turned by `yaw` around Y and leaning out by `tilt` (0 = up, pi/2 = flat).
-- A thin darker layer under it reads as the leaf's underside and gives it some depth.
local function leaf(
	model: Model,
	base: Vector3,
	yaw: number,
	tilt: number,
	length: number,
	width: number,
	color: Color3
): Part
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-tilt, 0, 0) * CFrame.new(0, length / 2, 0)
	local top = blob(model, "Leaf", Vector3.new(width, length, math.max(width * 0.08, 0.02)), cf, color)
	local h, s, v = color:ToHSV()
	blob(
		model,
		"LeafUnder",
		Vector3.new(width * 0.92, length * 0.96, math.max(width * 0.06, 0.02)),
		cf * CFrame.new(0, 0, 0.012),
		Color3.fromHSV(h, s * 0.9, v * 0.72)
	)
	return top
end

-- Muted natural colours (not toy-bright).
local LEAF = Color3.fromRGB(78, 116, 56)
local LEAF_DARK = Color3.fromRGB(52, 86, 42)
local LEAF_LIGHT = Color3.fromRGB(116, 150, 78)
local STEM = Color3.fromRGB(104, 118, 70)
local LETTUCE_RED = Color3.fromRGB(112, 42, 54)
local LETTUCE_INNER = Color3.fromRGB(132, 128, 72)
local RADISH = Color3.fromRGB(176, 40, 62)
local TOMATO = Color3.fromRGB(190, 46, 32)
local TOMATO_GREEN = Color3.fromRGB(122, 150, 70)
local PEPPER = Color3.fromRGB(168, 30, 26)
local PEPPER_GREEN = Color3.fromRGB(64, 112, 46)
local WHEAT_GREEN = Color3.fromRGB(118, 146, 74)
local WHEAT_GOLD = Color3.fromRGB(196, 166, 96)

local function sprout(model: Model, h: number, rng: Random)
	local top = Vector3.new(0, h * 0.6, 0)
	stick(model, "Stem", Vector3.zero, top, 0.025, STEM)
	local yaw = rng:NextNumber() * math.pi
	for i = 0, 1 do
		leaf(model, top, yaw + i * math.pi, math.rad(70), h * 0.45, h * 0.3, vary(LEAF_LIGHT, rng, 0.2))
	end
end

type Builder = (model: Model, h: number, g: number, rng: Random) -> ()

local builders: { [string]: Builder } = {}

-- Red romaine lettuce 'Outredgeous' (Veggie): a rosette of long red leaves, greener inside.
builders.Lettuce = function(model, h, _g, rng)
	local n = 10
	for i = 1, n do
		local yaw = (i / n) * math.pi * 2 + rng:NextNumber() * 0.4
		local outer = i % 2 == 0
		local color = if outer then LETTUCE_RED else lerpColor(LETTUCE_RED, LETTUCE_INNER, 0.55)
		local tilt = math.rad(if outer then 34 + rng:NextNumber() * 12 else 14 + rng:NextNumber() * 8)
		leaf(model, Vector3.zero, yaw, tilt, h * (0.85 + rng:NextNumber() * 0.15), h * 0.4, vary(color, rng, 0.25))
	end
	blob(
		model,
		"Heart",
		Vector3.new(h * 0.22, h * 0.45, h * 0.22),
		CFrame.new(0, h * 0.22, 0),
		vary(LETTUCE_INNER, rng, 0.1)
	)
end

-- Mizuna mustard (Veggie VEG-04): many thin, light green leaves fanning out.
builders.Mizuna = function(model, h, _g, rng)
	local n = 16
	for i = 1, n do
		local yaw = (i / n) * math.pi * 2 + rng:NextNumber() * 0.5
		local tilt = math.rad(15 + rng:NextNumber() * 45)
		leaf(model, Vector3.zero, yaw, tilt, h * (0.75 + rng:NextNumber() * 0.25), h * 0.1, vary(LEAF_LIGHT, rng, 0.3))
	end
end

-- Radish (Plant Habitat-02): broad leaves and a red root that swells near the end.
builders.Radish = function(model, h, g, rng)
	for i = 1, 6 do
		local yaw = (i / 6) * math.pi * 2 + rng:NextNumber() * 0.5
		local tilt = math.rad(25 + rng:NextNumber() * 20)
		leaf(model, Vector3.new(0, h * 0.1, 0), yaw, tilt, h * 0.78, h * 0.3, vary(LEAF_DARK, rng, 0.25))
	end
	local r = h * (0.08 + 0.22 * smooth((g - 0.4) / 0.6))
	blob(model, "Root", Vector3.new(r * 2, r * 1.9, r * 2), CFrame.new(0, r * 0.8, 0), vary(RADISH, rng, 0.1), 0.08)
	blob(
		model,
		"RootTip",
		Vector3.new(r * 0.45, r * 0.9, r * 0.45),
		CFrame.new(0, r * 0.05, 0),
		Color3.fromRGB(222, 214, 200)
	)
end

local function ear(model: Model, top: Vector3, dir: Vector3, size: number, color: Color3)
	local cf = CFrame.lookAt(top, top + dir) * CFrame.Angles(math.rad(90), 0, 0)
	blob(model, "Ear", Vector3.new(0.06, size, 0.06), cf, color)
	-- little bristles (awns) make it read as wheat, not as a stick
	for k = -1, 1, 2 do
		local tip = cf * CFrame.new(k * 0.03, size * 0.5, 0)
		stick(model, "Awn", tip.Position, (tip * CFrame.new(k * 0.03, size * 0.35, 0)).Position, 0.01, color)
	end
end

-- Dwarf wheat 'Apogee' (Advanced Plant Habitat): thin stalks, ears at the top that turn golden.
builders.Wheat = function(model, h, g, rng)
	local golden = smooth((g - 0.75) / 0.25)
	local stalk = lerpColor(WHEAT_GREEN, WHEAT_GOLD, golden)
	for _ = 1, 9 do
		local base = Vector3.new((rng:NextNumber() - 0.5) * h * 0.25, 0, (rng:NextNumber() - 0.5) * h * 0.25)
		local lean = Vector3.new((rng:NextNumber() - 0.5) * h * 0.35, 0, (rng:NextNumber() - 0.5) * h * 0.35)
		local top = base + lean + Vector3.new(0, h * (0.85 + rng:NextNumber() * 0.15), 0)
		local s = stick(model, "Stalk", base, top, 0.03, vary(stalk, rng, 0.12))
		s.Material = Enum.Material.Fabric
		if g > 0.55 then
			ear(model, top, (top - base).Unit, h * 0.22 * smooth((g - 0.55) / 0.3) + 0.02, vary(stalk, rng, 0.1))
		end
	end
	for i = 1, 4 do
		leaf(model, Vector3.new(0, h * 0.15, 0), i * 1.6, math.rad(35), h * 0.55, 0.05, vary(stalk, rng, 0.15))
	end
end

local function bush(model: Model, h: number, rng: Random, leafColor: Color3, clusters: number): { Vector3 }
	local top = Vector3.new(0, h * 0.85, 0)
	stick(model, "Stem", Vector3.zero, top, 0.045, STEM)
	local spots = {}
	for i = 1, clusters do
		local y = h * (0.25 + 0.6 * (i / clusters))
		local yaw = i * 2.4 + rng:NextNumber() * 0.5
		local out = Vector3.new(math.cos(yaw), 0, math.sin(yaw)) * h * 0.22
		local at = Vector3.new(0, y, 0) + out
		stick(model, "Branch", Vector3.new(0, y - h * 0.08, 0), at, 0.025, STEM)
		for k = 0, 2 do
			leaf(model, at, yaw + (k - 1) * 0.7, math.rad(65), h * 0.28, h * 0.15, vary(leafColor, rng, 0.25))
		end
		table.insert(spots, at)
	end
	return spots
end

-- Dwarf tomato 'Red Robin' (Veggie VEG-05): a small bush with cherry tomatoes, green then red.
builders.Tomato = function(model, h, g, rng)
	local spots = bush(model, h, rng, LEAF_DARK, 5)
	if g > 0.55 then
		local ripe = smooth((g - 0.8) / 0.2)
		local size = 0.06 + 0.07 * smooth((g - 0.55) / 0.3)
		for i, at in spots do
			if i > 1 then
				for k = 0, 1 do
					local p = at
						+ Vector3.new(
							(rng:NextNumber() - 0.5) * 0.12,
							-0.08 - k * 0.07,
							(rng:NextNumber() - 0.5) * 0.12
						)
					local color = vary(lerpColor(TOMATO_GREEN, TOMATO, ripe), rng, 0.12)
					blob(model, "Fruit", Vector3.new(size, size * 0.92, size), CFrame.new(p), color, 0.15)
				end
			end
		end
	end
end

-- Chile pepper 'Española Improved' (Plant Habitat-04): a glossy bush with long peppers that redden.
builders.Pepper = function(model, h, g, rng)
	local spots = bush(model, h, rng, PEPPER_GREEN, 5)
	if g > 0.55 then
		local ripe = smooth((g - 0.85) / 0.15)
		local len = 0.08 + 0.16 * smooth((g - 0.55) / 0.3)
		for i, at in spots do
			if i > 1 then
				local p = at
					+ Vector3.new((rng:NextNumber() - 0.5) * 0.1, -len / 2 - 0.04, (rng:NextNumber() - 0.5) * 0.1)
				local cf = CFrame.new(p) * CFrame.Angles(0, 0, math.rad((rng:NextNumber() - 0.5) * 30))
				local color = vary(lerpColor(PEPPER_GREEN, PEPPER, ripe), rng, 0.1)
				blob(model, "Fruit", Vector3.new(0.065, len, 0.065), cf, color, 0.2)
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

-- Harvest models (inventory) -------------------------------------------------------------------------

local produce: { [string]: Builder } = {}

-- a head of red lettuce
produce.Lettuce = function(model, _h, _g, rng)
	for i = 1, 9 do
		local yaw = (i / 9) * math.pi * 2
		local color = if i % 2 == 0 then LETTUCE_RED else lerpColor(LETTUCE_RED, LETTUCE_INNER, 0.5)
		leaf(model, Vector3.zero, yaw, math.rad(12 + (i % 3) * 8), 0.75, 0.38, vary(color, rng, 0.2))
	end
	stick(model, "Stalk", Vector3.new(0, -0.08, 0), Vector3.new(0, 0.05, 0), 0.12, Color3.fromRGB(200, 196, 160))
end

-- a bunch of mizuna, tied at the bottom
produce.Mizuna = function(model, _h, _g, rng)
	for i = 1, 12 do
		leaf(
			model,
			Vector3.zero,
			i * 0.52,
			math.rad(8 + rng:NextNumber() * 18),
			0.85,
			0.08,
			vary(LEAF_LIGHT, rng, 0.25)
		)
	end
	part(
		model,
		"Tie",
		Vector3.new(0.14, 0.06, 0.14),
		CFrame.new(0, 0.08, 0),
		Color3.fromRGB(150, 120, 80),
		Enum.Material.Fabric
	)
end

-- three radishes with their leaves
produce.Radish = function(model, _h, _g, rng)
	for i = 1, 3 do
		local a = i * 2.1
		local at = Vector3.new(math.cos(a) * 0.1, 0, math.sin(a) * 0.1)
		blob(model, "Root", Vector3.new(0.24, 0.22, 0.24), CFrame.new(at), vary(RADISH, rng, 0.1), 0.08)
		blob(
			model,
			"RootTip",
			Vector3.new(0.05, 0.14, 0.05),
			CFrame.new(at + Vector3.new(0, -0.15, 0)),
			Color3.fromRGB(222, 214, 200)
		)
		leaf(model, at + Vector3.new(0, 0.08, 0), a, math.rad(15), 0.45, 0.16, vary(LEAF_DARK, rng, 0.2))
	end
end

-- a small sheaf of wheat
produce.Wheat = function(model, _h, _g, rng)
	for i = 1, 7 do
		local a = i * 0.9
		local base = Vector3.new(math.cos(a) * 0.05, 0, math.sin(a) * 0.05)
		local top = Vector3.new(math.cos(a) * 0.14, 0.85, math.sin(a) * 0.14)
		local s = stick(model, "Stalk", base, top, 0.025, vary(WHEAT_GOLD, rng, 0.1))
		s.Material = Enum.Material.Fabric
		ear(model, top, (top - base).Unit, 0.2, vary(WHEAT_GOLD, rng, 0.1))
	end
	part(
		model,
		"Tie",
		Vector3.new(0.16, 0.05, 0.16),
		CFrame.new(0, 0.3, 0),
		Color3.fromRGB(150, 120, 80),
		Enum.Material.Fabric
	)
end

-- a little bunch of cherry tomatoes on a green stem
produce.Tomato = function(model, _h, _g, rng)
	stick(model, "Stem", Vector3.new(-0.2, 0.25, 0), Vector3.new(0.2, 0.25, 0), 0.025, STEM)
	for i = 1, 4 do
		local x = -0.18 + (i - 1) * 0.12
		local p = Vector3.new(x, 0.08 + (i % 2) * 0.04, (rng:NextNumber() - 0.5) * 0.08)
		stick(model, "Stalk", Vector3.new(x, 0.25, 0), p + Vector3.new(0, 0.07, 0), 0.015, STEM)
		blob(model, "Fruit", Vector3.new(0.15, 0.14, 0.15), CFrame.new(p), vary(TOMATO, rng, 0.08), 0.15)
		blob(model, "Calyx", Vector3.new(0.09, 0.02, 0.09), CFrame.new(p + Vector3.new(0, 0.07, 0)), LEAF)
	end
end

-- two red chile peppers
produce.Pepper = function(model, _h, _g, rng)
	for i = 1, 2 do
		local x = (i - 1.5) * 0.18
		local cf = CFrame.new(x, 0.25, 0) * CFrame.Angles(0, 0, math.rad((i - 1.5) * 25))
		blob(model, "Fruit", Vector3.new(0.12, 0.5, 0.12), cf, vary(PEPPER, rng, 0.08), 0.2)
		stick(
			model,
			"Stalk",
			(cf * CFrame.new(0, 0.24, 0)).Position,
			(cf * CFrame.new(0, 0.36, 0)).Position,
			0.03,
			PEPPER_GREEN
		)
	end
end

function CropModels.produce(id: string, seed: number): Model
	local model = Instance.new("Model")
	model.Name = id
	local builder = produce[id]
	if builder then
		builder(model, 1, 1, Random.new(seed))
	else
		sprout(model, 0.5, Random.new(seed))
	end
	model.WorldPivot = CFrame.identity
	return model
end

-- A paper seed packet in the crop's colour, with a light label band.
function CropModels.packet(id: string): Model
	local model = Instance.new("Model")
	model.Name = "Seeds_" .. id
	local crop = CropConfig.get(id)
	local color = if crop then crop.color else Color3.fromRGB(150, 150, 150)
	local h, s, v = color:ToHSV()
	local paper = Color3.fromHSV(h, s * 0.7, v * 0.85) -- printed paper, not plastic
	part(model, "Packet", Vector3.new(0.42, 0.58, 0.05), CFrame.new(0, 0.29, 0), paper, Enum.Material.Fabric)
	part(
		model,
		"Label",
		Vector3.new(0.43, 0.14, 0.055),
		CFrame.new(0, 0.46, 0),
		Color3.fromRGB(226, 220, 204),
		Enum.Material.Fabric
	)
	part(
		model,
		"Fold",
		Vector3.new(0.43, 0.04, 0.06),
		CFrame.new(0, 0.565, 0),
		Color3.fromHSV(h, s * 0.7, v * 0.6),
		Enum.Material.Fabric
	)
	-- a small picture of the plant on the front
	local rng = Random.new(#id)
	for i = 0, 1 do
		leaf(
			model,
			Vector3.new(0, 0.12, -0.03),
			i * math.pi + math.pi / 2,
			math.rad(40),
			0.16,
			0.08,
			vary(LEAF, rng, 0.1)
		)
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
