-- Gives every player a crew role (Player attribute "Role"). New players get the
-- least-filled role; a player can switch with the ChooseRole RemoteEvent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roles = require(ReplicatedStorage.Shared.Roles)

local CHANGE_COOLDOWN = 2 -- seconds between role changes per player (anti-spam)

local Crew = {}

local lastChange: { [Player]: number } = {}

local function counts(except: Player?): { [string]: number }
	local result = {}
	for _, player in Players:GetPlayers() do
		local role = player:GetAttribute(Roles.ATTRIBUTE)
		if player ~= except and type(role) == "string" then
			result[role] = (result[role] or 0) + 1
		end
	end
	return result
end

local function setRole(player: Player, role: string)
	player:SetAttribute(Roles.ATTRIBUTE, role)
	print(`[crew] {player.Name} -> {role}`)
end

function Crew.start()
	local choose = Instance.new("RemoteEvent")
	choose.Name = "ChooseRole"
	choose.OnServerEvent:Connect(function(player: Player, role: unknown)
		if not Roles.isValid(role) then
			return
		end
		local now = os.clock()
		if now - (lastChange[player] or 0) < CHANGE_COOLDOWN then
			return
		end
		lastChange[player] = now
		setRole(player, role :: string)
	end)
	choose.Parent = ReplicatedStorage

	local function onJoin(player: Player)
		setRole(player, Roles.leastFilled(counts(player)))
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
	end)
end

return Crew
