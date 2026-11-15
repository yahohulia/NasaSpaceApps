-- MB_Footsteps (StarterPlayerScripts): footstep sounds for every character, played on this client.
--   Inside the base (parts tagged MB_InsideZone = Workspace.MB_HabitatZone):
--     the walk-on-metal recording loops while walking (Config.Footsteps.MetalId). If MetalId is empty,
--     each step plays a random sample from SoundIds instead (never the same twice in a row).
--   Outside on sand (SandMaterials): the walk-on-sand recording loops while walking (SandId).
--   Outside on any other floor: the normal Roblox footsteps ("Running" sound).
-- Loops follow walking speed (16 studs/s = normal speed) and stop when the character stops or jumps.
-- Copy of the script that lives in the team place (studio/MB in the repo).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("MB_Config"))
local F = Config.Footsteps
if not F then
	warn("[MB_Footsteps] MB_Config.Footsteps is missing")
	return
end
-- MB_SoundConfig can override the walking loops (one place for all sound ids).
local soundConfig = ReplicatedStorage:FindFirstChild("MB_SoundConfig")
if soundConfig and soundConfig:IsA("ModuleScript") then
	local SC = require(soundConfig) :: any
	F = table.clone(F)
	if SC.StepsBase and SC.StepsBase ~= "" then
		F.MetalId = SC.StepsBase
	end
	if SC.StepsSand and SC.StepsSand ~= "" then
		F.SandId = SC.StepsSand
	end
end

local random = Random.new()

-- Floor materials that count as sand (outside), from Config.Footsteps.SandMaterials.
local SAND_MATERIALS: { [Enum.Material]: boolean } = {}
for _, name in F.SandMaterials or {} do
	local ok, material = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	if ok and material then
		SAND_MATERIALS[material] = true
	end
end

local function isInside(pos: Vector3): boolean
	for _, zone in CollectionService:GetTagged(Config.InsideZoneTag) do
		if zone:IsA("BasePart") then
			local p = zone.CFrame:PointToObjectSpace(pos)
			local h = zone.Size / 2
			if math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z then
				return true
			end
		end
	end
	return false
end

local function newSound(parent: Instance, name: string, id: string, looped: boolean, volume: number): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Looped = looped
	s.Volume = volume
	s.RollOffMinDistance = F.LoudWithin
	s.RollOffMaxDistance = F.HearDistance
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.Parent = parent
	return s
end

local function hasId(id: string?): boolean
	return id ~= nil and id ~= ""
end

type Walker = {
	root: BasePart,
	humanoid: Humanoid,
	steps: { Sound }, -- single-step samples (base, when there is no metal loop)
	metal: Sound?, -- walk-on-metal loop (base)
	sand: Sound?, -- walk-on-sand loop (outside)
	running: Sound?, -- default Roblox footsteps
	runningVolume: number,
	last: number,
	travelled: number,
	lastPos: Vector3,
}

local walkers: { [Model]: Walker } = {}

local function track(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not (humanoid and humanoid:IsA("Humanoid") and root and root:IsA("BasePart")) then
		return
	end
	local steps = {}
	if not hasId(F.MetalId) then
		for i, id in F.SoundIds or {} do
			table.insert(steps, newSound(root, `MB_Step{i}`, id, false, F.VolumeMin))
		end
	end
	local w: Walker = {
		root = root,
		humanoid = humanoid,
		steps = steps,
		metal = if hasId(F.MetalId) then newSound(root, "MB_MetalWalk", F.MetalId, true, F.MetalVolume) else nil,
		sand = if hasId(F.SandId) then newSound(root, "MB_SandWalk", F.SandId, true, F.SandVolume) else nil,
		running = nil,
		runningVolume = 0.65,
		last = 0,
		travelled = 0,
		lastPos = root.Position,
	}
	-- The default "Running" sound is created by Roblox's character sounds script; remember its volume.
	local function adopt(child: Instance)
		if child:IsA("Sound") and child.Name == "Running" and not w.running then
			w.running = child
			w.runningVolume = child.Volume
		end
	end
	for _, child in root:GetChildren() do
		adopt(child)
	end
	root.ChildAdded:Connect(adopt)
	walkers[character] = w
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			walkers[character] = nil
		end
	end)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(track)
	if player.Character then
		task.spawn(track, player.Character)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do
	watchPlayer(player)
end

-- Plays a loop while `active`, at a speed that follows walking speed; pauses otherwise.
local function driveLoop(sound: Sound?, active: boolean, speed: number, minSpeed: number, maxSpeed: number)
	if not sound then
		return
	end
	if active then
		sound.PlaybackSpeed = math.clamp(speed / 16, minSpeed, maxSpeed)
		if not sound.IsPlaying then
			sound:Play()
		end
	elseif sound.IsPlaying then
		sound:Pause()
	end
end

local function step(w: Walker)
	local count = #w.steps
	if count == 0 then
		return
	end
	local index = random:NextInteger(1, count)
	if count > 1 and index == w.last then
		index = index % count + 1 -- never the same sample twice in a row
	end
	w.last = index
	local s = w.steps[index]
	s.PlaybackSpeed = random:NextNumber(F.PitchMin, F.PitchMax)
	s.Volume = random:NextNumber(F.VolumeMin, F.VolumeMax)
	s.TimePosition = 0
	s:Play()
end

RunService.Heartbeat:Connect(function()
	for character, w in walkers do
		if not character.Parent then
			walkers[character] = nil
			continue
		end
		local pos = w.root.Position
		local inside = isInside(pos)
		local velocity = w.root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local onFloor = w.humanoid.FloorMaterial ~= Enum.Material.Air and w.humanoid.Health > 0
		local walking = onFloor and speed > 1
		local onSand = not inside and SAND_MATERIALS[w.humanoid.FloorMaterial] == true

		driveLoop(w.metal, inside and walking, speed, F.MetalSpeedMin, F.MetalSpeedMax)
		driveLoop(w.sand, onSand and walking, speed, F.SandSpeedMin, F.SandSpeedMax)
		if w.running then
			-- Roblox steps only outside, and not on sand when we have a sand loop.
			local ours = inside or (onSand and w.sand ~= nil)
			w.running.Volume = if ours then 0 else w.runningVolume
		end

		-- Single-step samples inside the base (only when there is no metal loop).
		local moved = Vector3.new(pos.X - w.lastPos.X, 0, pos.Z - w.lastPos.Z).Magnitude
		w.lastPos = pos
		if #w.steps == 0 or not inside or not onFloor or moved > 10 then -- teleport = no step
			w.travelled = 0
			continue
		end
		w.travelled += moved
		if w.travelled >= F.StrideStuds then
			w.travelled -= F.StrideStuds
			step(w)
		end
	end
end)
