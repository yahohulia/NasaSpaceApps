-- Footprints in the Mars dust. Every client draws them for all players near it
-- (a purely visual effect, nothing goes through the server). A print appears only
-- when the ground under the foot is Terrain, so floors inside the base stay clean.
-- Left and right feet alternate; each print slowly fades and is removed.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local STRIDE = 2.4 -- studs walked between two prints
local FOOT_SIDE = 0.45 -- studs from the body's centre line to a foot
local THICKNESS = 0.04
local SOLE = Vector2.new(0.5, 0.72) -- width, length of the oval sole
local HEEL = Vector2.new(0.42, 0.38) -- width, length of the oval heel
local SOLE_OFFSET = 0.18 -- sole centre, studs forward of the print centre
local HEEL_OFFSET = 0.4 -- heel centre, studs behind the print centre
local LIFETIME = 40 -- seconds before a print starts to fade
local FADE_SECONDS = 6
local MAX_PRINTS = 200 -- oldest prints are removed first
local MAX_DISTANCE = 150 -- only draw for characters this close to the camera
local DARKEN = 0.68 -- print colour = ground colour * this

local FootprintsClient = {}

-- A flat oval lying on the ground: a Part with a cylinder SpecialMesh whose axis
-- (X) points up; the mesh follows the part size, so Y/Z set the oval's width/length.
local function oval(cframe: CFrame, size: Vector2, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = "Print"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Sand
	part.Color = color
	part.Transparency = 0.1
	part.Size = Vector3.new(THICKNESS, size.X, size.Y)
	part.CFrame = cframe * CFrame.Angles(0, 0, math.pi / 2)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Parent = part
	return part
end

type Walker = { last: Vector3?, left: boolean }

function FootprintsClient.start()
	local folder = Instance.new("Folder")
	folder.Name = "Footprints"
	folder.Parent = workspace

	local prints: { BasePart } = {}
	local walkers: { [Model]: Walker } = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }

	local function removeOldest()
		local oldest = table.remove(prints, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	local function place(position: Vector3, forward: Vector3)
		local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), params)
		if not hit or hit.Material == Enum.Material.Water then
			return
		end
		local up = hit.Normal
		local look = (forward - up * forward:Dot(up))
		if look.Magnitude < 1e-3 then
			return
		end
		look = look.Unit
		local ground = workspace.Terrain:GetMaterialColor(hit.Material)
		local color = Color3.new(ground.R * DARKEN, ground.G * DARKEN, ground.B * DARKEN)
		local base = CFrame.lookAlong(hit.Position + up * (THICKNESS / 2), look, up)
		-- Boot print = an oval sole plus a smaller oval heel behind it.
		local part = oval(base * CFrame.new(0, 0, -SOLE_OFFSET), SOLE, color)
		oval(base * CFrame.new(0, 0, HEEL_OFFSET), HEEL, color).Parent = part
		part.Parent = folder
		table.insert(prints, part)
		if #prints > MAX_PRINTS then
			removeOldest()
		end
		task.delay(LIFETIME, function()
			if part.Parent then
				for _, p in { part, part:FindFirstChildOfClass("Part") } do
					if p then
						TweenService:Create(p, TweenInfo.new(FADE_SECONDS), { Transparency = 1 }):Play()
					end
				end
				task.wait(FADE_SECONDS)
				local index = table.find(prints, part)
				if index then
					table.remove(prints, index)
				end
				part:Destroy()
			end
		end)
	end

	local function step(character: Model, walker: Walker)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = humanoid and humanoid.RootPart
		if not humanoid or not root or humanoid.FloorMaterial == Enum.Material.Air then
			walker.last = nil
			return
		end
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - root.Position).Magnitude > MAX_DISTANCE then
			return
		end
		local here = root.Position
		local flat = Vector3.new(here.X, 0, here.Z)
		if walker.last == nil then
			walker.last = flat
			return
		end
		local moved = flat - (walker.last :: Vector3)
		if moved.Magnitude < STRIDE then
			return
		end
		walker.last = flat
		local forward = moved.Unit
		local right = forward:Cross(Vector3.yAxis)
		walker.left = not walker.left
		local side = if walker.left then -FOOT_SIDE else FOOT_SIDE
		local feet = here - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
		place(feet + right * side, forward)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.05 then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				local walker = walkers[character]
				if not walker then
					walker = { last = nil, left = false }
					walkers[character] = walker
					character.Destroying:Connect(function()
						walkers[character] = nil
					end)
				end
				step(character, walker)
			end
		end
	end)
end

return FootprintsClient
