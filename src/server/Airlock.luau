--!strict
-- Airlock doors. The two airlock doors are sliding doors (Models tagged "SlidingDoor"
-- with a "Requires" attribute, built in Studio: Workspace.MarsBaseFixes.AirlockDoors):
--   OuterDoor (to Mars), Requires = "Suit": opens only for a player in the space suit
--     who is not kept inside by the medic (Radiation sets "OutsideBlocked").
--   InnerDoor (airlock <-> base), Requires = "NoSuit": opens only after the suit is off.
-- The suit locker is inside the airlock, between the two doors (Suit.luau).
-- Opening and blocking happen on the clients (Client.DoorClient). Here the server only
-- tells a player who stands at a shut door what to do.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Notice = require(script.Parent.Notice)

local TAG = "SlidingDoor"
local HINT_DISTANCE = 5 -- studs from the door centre
local HINT_COOLDOWN = 6 -- seconds between two hints for the same player
local CHECK_SECONDS = 0.5

local Airlock = {}

local lastHint: { [Player]: number } = {}

-- The i18n key that explains why `player` may not pass, or nil if they may.
local function blockedReason(player: Player, rule: any): string?
	local suitOn = player:GetAttribute("SuitOn") == true
	if rule == "Suit" then
		if not suitOn then
			return "suit.need"
		elseif player:GetAttribute("OutsideBlocked") == true then
			return "radiation.blocked"
		end
	elseif rule == "NoSuit" and suitOn then
		return "suit.take_off_first"
	end
	return nil
end

local function check()
	local now = os.clock()
	for _, door in CollectionService:GetTagged(TAG) do
		local rule = door:GetAttribute("Requires")
		if rule ~= nil and door:IsA("Model") then
			local centre = door:GetPivot().Position
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local offset = root.Position - centre
					local near = Vector3.new(offset.X, 0, offset.Z).Magnitude < HINT_DISTANCE
					local reason = if near then blockedReason(player, rule) else nil
					if reason and (lastHint[player] or 0) + HINT_COOLDOWN < now then
						lastHint[player] = now
						Notice.send(player, reason, if reason == "radiation.blocked" then "alert" else "warn")
					end
				end
			end
		end
	end
end

function Airlock.start()
	Players.PlayerRemoving:Connect(function(player)
		lastHint[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			check()
		end
	end)
end

return Airlock
