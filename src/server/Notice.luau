-- Short on-screen messages for one player (a toast). The server sends an i18n key
-- plus placeholders; the client translates it into the player's language.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Notice = {}

local remote: RemoteEvent? = nil

local function getRemote(): RemoteEvent
	if not remote then
		local created = Instance.new("RemoteEvent")
		created.Name = "Notice"
		created.Parent = ReplicatedStorage
		remote = created
	end
	return remote :: RemoteEvent
end

function Notice.start()
	getRemote()
end

-- `kind` picks the toast colour on the client: "info" | "warn" | "alert".
function Notice.send(player: Player, key: string, kind: string, vars: { [string]: string | number }?)
	getRemote():FireClient(player, key, kind, vars or {})
end

return Notice
