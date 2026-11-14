-- Airlock teleport pads.
-- Any BasePart tagged "TeleportPad" with a string attribute "Target" moves a player
-- who steps on it to the sibling part with that name (its CFrame is the landing spot).
-- The pads and landing spots are built in Studio (Workspace.Base.Habitat.Airlock).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local TAG = "TeleportPad"
local COOLDOWN_SECONDS = 1.5

local Airlock = {}

local lastUse: { [Player]: number } = {}

local function onTouched(pad: BasePart, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local now = os.clock()
	if (lastUse[player] or 0) + COOLDOWN_SECONDS > now then
		return
	end

	local targetName = pad:GetAttribute("Target")
	local container = pad.Parent
	local target = if typeof(targetName) == "string" and container then container:FindFirstChild(targetName) else nil
	if not (target and target:IsA("BasePart")) then
		warn(`[Airlock] {pad:GetFullName()} has no valid Target`)
		return
	end

	lastUse[player] = now
	character:PivotTo(target.CFrame)
end

local function bind(instance: Instance)
	if instance:IsA("BasePart") then
		local pad = instance
		pad.Touched:Connect(function(hit)
			onTouched(pad, hit)
		end)
	end
end

function Airlock.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		bind(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return Airlock
