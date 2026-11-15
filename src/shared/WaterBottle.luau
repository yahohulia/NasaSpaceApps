--!strict
-- A bottle of water: the item the ice melter (the water station, MB_WaterStation) makes from one piece
-- of ice. It sits in the shared bag (Player.CropBag, a StringValue named KIND) and is drunk with
-- WaterBottleClient's "Drink water" button. Server: WaterBottles.luau. The bag icon is built here.
local WaterBottle = {}

WaterBottle.KIND = "Water" -- Name of the bag item (Crops uses "Seed" / "Produce")
WaterBottle.WATER = 35 -- game value, TODO balance: water one bottle gives (the old "melt and drink" gave 35)
WaterBottle.KEY = Enum.KeyCode.V

local function part(model: Model, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, alpha: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = alpha
	p.Anchored = true
	p.CanCollide = false
	p.Parent = model
end

-- A small bottle standing upright, about 1 stud tall (for the bag's viewport icons).
function WaterBottle.model(): Model
	local m = Instance.new("Model")
	m.Name = "WaterBottle"
	local up = CFrame.Angles(0, 0, math.rad(90)) -- cylinders lie along X; stand them up
	part(
		m,
		Vector3.new(0.8, 0.46, 0.46),
		CFrame.new(0, 0.4, 0) * up,
		Color3.fromRGB(190, 225, 245),
		Enum.Material.Glass,
		0.35
	)
	part(
		m,
		Vector3.new(0.6, 0.4, 0.4),
		CFrame.new(0, 0.33, 0) * up,
		Color3.fromRGB(70, 160, 235),
		Enum.Material.SmoothPlastic,
		0.1
	)
	part(
		m,
		Vector3.new(0.14, 0.24, 0.24),
		CFrame.new(0, 0.86, 0) * up,
		Color3.fromRGB(40, 110, 200),
		Enum.Material.SmoothPlastic,
		0
	)
	return m
end

return WaterBottle
