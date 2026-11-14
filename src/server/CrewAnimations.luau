-- Gives every character the crew's movement animations (Roblox's Rthro pack: walk,
-- run, jump, idle...).
-- Follows "Replace default animations" in https://create.roblox.com/docs/animation/using:
-- set the AnimationIds in the character's Animate script and stop tracks already playing.
-- Asset ids come from src/shared/Assets.luau.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)

-- Animate script path (child.grandchild) -> asset key.
local SLOTS = {
	{ "walk", "WalkAnim", "CrewWalk" },
	{ "run", "RunAnim", "CrewRun" },
	{ "jump", "JumpAnim", "CrewJump" },
	{ "idle", "Animation1", "CrewIdle" },
	{ "idle", "Animation2", "CrewIdle2" },
	{ "fall", "FallAnim", "CrewFall" },
	{ "climb", "ClimbAnim", "CrewClimb" },
	{ "swim", "Swim", "CrewSwim" },
	{ "swimidle", "SwimIdle", "CrewSwimIdle" },
}

local CrewAnimations = {}

local function apply(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local animate = character:WaitForChild("Animate", 10)
	if not humanoid or not animate or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return -- the pack is R15-only
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end
	for _, slot in SLOTS do
		local folder = animate:FindFirstChild(slot[1])
		local animation = folder and folder:FindFirstChild(slot[2])
		if animation and animation:IsA("Animation") then
			animation.AnimationId = Assets[slot[3]].id
		end
	end
end

function CrewAnimations.start()
	local function onPlayer(player: Player)
		player.CharacterAppearanceLoaded:Connect(apply)
		if player.Character and player:HasAppearanceLoaded() then
			task.spawn(apply, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CrewAnimations
