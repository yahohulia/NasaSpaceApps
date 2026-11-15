--!strict
-- Rooms rebuilt from parts inside an old base mesh. From outside the player should see the mesh
-- (the same look as the other base modules); from inside, the new part room. The mesh has its own
-- old furniture inside, so both can't be shown at once.
--
-- Built in Studio: instances tagged "InteriorView" (the new room) and "ExteriorView" (the old mesh
-- parts), both with the attribute ViewGroup (e.g. "Storage"). The InteriorView instance also has
--   ViewZones = "StorageZone,CentralCorridorZone" -- parts in Workspace.Base.Zones where the camera
--                                                   counts as inside (the corridor sees the door)
--   ViewMaxY  = 12.4                              -- above this height (the roof) it is outside
-- ExteriorView parts stay Transparency = 1 in the place (attribute OldTransparency = their look);
-- this client shows them only while the camera is outside. Only the look changes, on this client
-- only; the new room's walls always collide.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local RoomViewClient = {}

local INTERIOR_TAG = "InteriorView"
local EXTERIOR_TAG = "ExteriorView"

type Group = {
	zones: { BasePart },
	maxY: number,
	interior: { Instance },
	exterior: { Instance },
	inside: boolean?,
}

local function inBox(part: BasePart, pos: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

local function setHidden(root: Instance, hidden: boolean)
	local value = if hidden then 1 else 0
	if root:IsA("BasePart") then
		root.LocalTransparencyModifier = value
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = value
		end
	end
end

function RoomViewClient.start()
	local groups: { [string]: Group } = {}

	local function group(name: string): Group
		local g = groups[name]
		if not g then
			g = { zones = {}, maxY = math.huge, interior = {}, exterior = {}, inside = nil }
			groups[name] = g
		end
		return g :: Group
	end

	local function apply(g: Group)
		for _, inst in g.interior do
			setHidden(inst, not g.inside)
		end
		-- The mesh is hidden in the place itself (Transparency 1), so without this script the
		-- inside still looks right. Outside, this client shows it again with its old transparency.
		for _, inst in g.exterior do
			if inst:IsA("BasePart") then
				local old = inst:GetAttribute("OldTransparency")
				inst.Transparency = if g.inside then 1 elseif typeof(old) == "number" then old else 0
			end
		end
	end

	local function addInterior(inst: Instance)
		local name = inst:GetAttribute("ViewGroup")
		if typeof(name) ~= "string" then
			return
		end
		local g = group(name)
		table.insert(g.interior, inst)
		local maxY = inst:GetAttribute("ViewMaxY")
		if typeof(maxY) == "number" then
			g.maxY = maxY
		end
		local zoneNames = inst:GetAttribute("ViewZones")
		local zonesFolder = workspace:WaitForChild("Base", 30)
		zonesFolder = zonesFolder and zonesFolder:WaitForChild("Zones", 30)
		if typeof(zoneNames) == "string" and zonesFolder then
			for zoneName in string.gmatch(zoneNames, "[^,%s]+") do
				local zone = zonesFolder:FindFirstChild(zoneName)
				if zone and zone:IsA("BasePart") then
					table.insert(g.zones, zone)
				end
			end
		end
		-- parts added later (the server fills the seed crate) follow the current state
		inst.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") and g.inside ~= nil then
				d.LocalTransparencyModifier = if g.inside then 0 else 1
			end
		end)
		g.inside = nil
	end

	local function addExterior(inst: Instance)
		local name = inst:GetAttribute("ViewGroup")
		if typeof(name) == "string" then
			table.insert(group(name).exterior, inst)
			group(name).inside = nil
		end
	end

	for _, inst in CollectionService:GetTagged(INTERIOR_TAG) do
		task.spawn(addInterior, inst)
	end
	CollectionService:GetInstanceAddedSignal(INTERIOR_TAG):Connect(addInterior)
	for _, inst in CollectionService:GetTagged(EXTERIOR_TAG) do
		addExterior(inst)
	end
	CollectionService:GetInstanceAddedSignal(EXTERIOR_TAG):Connect(addExterior)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local pos = camera.CFrame.Position
		for _, g in groups do
			local inside = false
			if pos.Y <= g.maxY then
				for _, zone in g.zones do
					if inBox(zone, pos) then
						inside = true
						break
					end
				end
			end
			if inside ~= g.inside then
				g.inside = inside
				apply(g)
			end
		end
	end)
end

return RoomViewClient
