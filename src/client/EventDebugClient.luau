--!strict
-- Studio only: F1..F6 start a mission event right away (for testing and recording the demo).
-- Keys and events: Shared.MB_Events.DebugKeys. The server (EventDirector) also checks IsStudio.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MB_Events = require(ReplicatedStorage.Shared.MB_Events)

local EventDebugClient = {}

function EventDebugClient.start()
	if not RunService:IsStudio() then
		return
	end
	local remote = ReplicatedStorage:WaitForChild("MB_EventDebug", 30)
	if not (remote and remote:IsA("RemoteEvent")) then
		return
	end
	local keys = {}
	for keyName in MB_Events.DebugKeys do
		table.insert(keys, (Enum.KeyCode :: any)[keyName])
	end
	ContextActionService:BindAction("MB_EventDebug", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			local event = MB_Events.DebugKeys[input.KeyCode.Name]
			if event then
				remote:FireServer(event)
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(keys))
end

return EventDebugClient
