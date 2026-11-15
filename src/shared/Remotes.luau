--!strict
-- RemoteEvent names and payload types shared by server and client.
-- The server owns all state; clients only show it.
--
-- ResourcesChanged (server -> client): ResourceSnapshot.
--   Fire to all clients whenever a value changes, and to each player when they join.
-- EventChanged (server -> client): EventState. Same rule: on change and on join.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

export type Amount = {
	amount: number,
	capacity: number,
}

export type ResourceSnapshot = {
	sol: number,
	resources: { [Config.ResourceName]: Amount },
}

-- kind is the DONKI event type ("FLR", "SEP", "CME"). endsAt uses workspace:GetServerTimeNow().
export type EventState = {
	active: boolean,
	kind: string?,
	endsAt: number?,
}

local FOLDER = "Remotes"
local NAMES = { "ResourcesChanged", "EventChanged" }

local Remotes = {}

-- Server: creates the folder and events. Client: waits for them.
function Remotes.get(name: string): RemoteEvent
	assert(table.find(NAMES, name), `unknown remote {name}`)
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER
			folder.Parent = ReplicatedStorage
		end
		local remote = (folder :: Instance):FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		return remote :: RemoteEvent
	end
	return ReplicatedStorage:WaitForChild(FOLDER):WaitForChild(name) :: RemoteEvent
end

return Remotes
