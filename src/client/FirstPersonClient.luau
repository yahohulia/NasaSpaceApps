-- First-person only camera with gentle movement feel: head bob that dips on each
-- footfall, a small tilt when strafing or turning, a dip after landing, idle
-- breathing, and your own body visible when you look down. The cursor is hidden. Effects are kept soft for kids (no motion sickness); tune below.
-- The default Roblox camera rebuilds its CFrame every frame, so we add our offset
-- right after it (render priority Camera + 1) without accumulating.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BOB_HEIGHT = 0.2 -- studs the view dips on each footfall at full walk speed
local BOB_SIDE = 0.05 -- studs left/right per step
local BOB_ROLL = math.rad(0.5) -- camera roll per step
local STEP_RATE = 0.2 -- fallback only: bob cycles per stud when no walk track plays
local STRAFE_TILT = math.rad(1) -- roll when moving sideways
local LAND_DIP = 0.2 -- studs the view drops when landing
local SMOOTH = 10 -- how fast effects fade in and out (per second)
local CAMERA_FORWARD = -1.1 -- studs forward from the head, so you never see your own neck
local BREATH_HEIGHT = 0.025 -- studs of idle breathing
local BREATH_SECONDS = 4 -- one breath
local TURN_SWAY = 0.003 -- roll (radians) per radian/second of turning
local TURN_SWAY_MAX = math.rad(0.8)
local STEP_TRACKS = { WalkAnim = true, RunAnim = true } -- Animate script track names

-- The walk/run track that is playing strongest now (its cycle = two footfalls).
local function stepTrack(humanoid: Humanoid): AnimationTrack?
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local best: AnimationTrack? = nil
	for _, track in animator:GetPlayingAnimationTracks() do
		if STEP_TRACKS[track.Animation and track.Animation.Name or ""] and track.WeightCurrent > 0.1 then
			if best == nil or track.WeightCurrent > best.WeightCurrent then
				best = track
			end
		end
	end
	return best
end

local FirstPersonClient = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Only the body itself is shown (arms, legs, torso). The head and every accessory
-- (hats, capes, shoulder pads...) stay hidden: up close they block the view.
local function isShownPart(part: BasePart): boolean
	return part.Name ~= "Head" and part.Name ~= "HumanoidRootPart" and part:FindFirstAncestorOfClass("Accessory") == nil
end

function FirstPersonClient.start()
	local player = Players.LocalPlayer
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	-- The mouse is locked to the centre in first person, so the arrow cursor is only
	-- in the way. Docs: hide it with MouseIconEnabled, not a transparent image.
	UserInputService.MouseIconEnabled = false

	local humanoid: Humanoid? = nil
	local bodyParts: { BasePart } = {}
	local phase = 0
	local amount = 0 -- 0..1, how much the bob is on (fades with speed)
	local tilt = 0
	local dip = 0
	local sway = 0
	local breath = 0
	local lastYaw: number? = nil

	local function onCharacter(character: Model)
		humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.CameraOffset = Vector3.new(0, 0, CAMERA_FORWARD)
			humanoid.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Landed then
					dip = LAND_DIP
				end
			end)
		end
		bodyParts = {}
		local function add(d: Instance)
			if d:IsA("BasePart") and isShownPart(d) then
				table.insert(bodyParts, d)
			end
		end
		for _, d in character:GetDescendants() do
			add(d)
		end
		character.DescendantAdded:Connect(function(d)
			task.defer(add, d)
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	RunService:BindToRenderStep("FirstPersonFeel", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		local h = humanoid
		if not camera or not h or not h.RootPart then
			return
		end

		-- Show your own body (the camera hides it in first person).
		for _, part in bodyParts do
			part.LocalTransparencyModifier = part.Transparency
		end

		local root = h.RootPart :: BasePart
		local velocity = root.AssemblyLinearVelocity
		local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local onGround = h.FloorMaterial ~= Enum.Material.Air
		local walkShare = if h.WalkSpeed > 0 then math.clamp(flatSpeed / h.WalkSpeed, 0, 1.5) else 0
		local k = math.clamp(dt * SMOOTH, 0, 1)

		amount = lerp(amount, if onGround then walkShare else 0, k)
		-- Follow the walk animation's own cycle so the dip lands with each foot.
		local track = stepTrack(h)
		if track and track.Length > 0 then
			phase = track.TimePosition / track.Length * 2 * math.pi
		else
			phase += flatSpeed * STEP_RATE * dt * math.pi
		end

		-- Sideways speed relative to where the camera looks -> strafe tilt.
		local right = camera.CFrame.RightVector
		local side = if h.WalkSpeed > 0 then velocity:Dot(right) / h.WalkSpeed else 0
		tilt = lerp(tilt, -math.clamp(side, -1, 1) * STRAFE_TILT, k)
		dip = lerp(dip, 0, math.clamp(dt * 6, 0, 1))

		-- Turning sway: the camera module's own CFrame (before our offset) tells how fast we turn.
		local look = camera.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local yawRate = 0
		if lastYaw then
			local delta = (yaw - lastYaw + math.pi) % (2 * math.pi) - math.pi
			yawRate = if dt > 0 then delta / dt else 0
		end
		lastYaw = yaw
		sway = lerp(sway, math.clamp(yawRate * TURN_SWAY, -TURN_SWAY_MAX, TURN_SWAY_MAX), k)

		-- Footfall: lowest point when a foot lands (|sin| = 0), back up mid-stride.
		local bobY = -(1 - math.abs(math.sin(phase))) * BOB_HEIGHT * amount
		local bobX = math.sin(phase) * BOB_SIDE * amount
		local roll = math.sin(phase) * BOB_ROLL * amount + tilt + sway

		-- Breathing when standing still.
		breath += dt
		local breathY = math.sin(breath * 2 * math.pi / BREATH_SECONDS) * BREATH_HEIGHT * (1 - math.min(amount, 1))

		camera.CFrame = camera.CFrame * CFrame.new(bobX, bobY + breathY - dip, 0) * CFrame.Angles(0, 0, roll)
	end)
end

return FirstPersonClient
