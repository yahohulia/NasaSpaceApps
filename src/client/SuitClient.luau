-- Suit locker prompts in the player's own language: "Put on suit" / "Take off suit"
-- depending on whether this player wears the suit (Player attribute "SuitOn").
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage.Shared.Strings)

local SuitClient = {}

function SuitClient.start()
	local me = Players.LocalPlayer
	local lang = Strings.langFromLocale(me.LocaleId)

	local function label(prompt: ProximityPrompt)
		local key = if me:GetAttribute("SuitOn") == true then "suit.prompt.take_off" else "suit.prompt.put_on"
		prompt.ActionText = Strings.get(key, lang)
		prompt.ObjectText = Strings.get("suit.object", lang)
	end

	local function refreshAll()
		for _, part in CollectionService:GetTagged("SuitLocker") do
			local prompt = part:FindFirstChild("SuitPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				label(prompt)
			end
		end
	end

	local function watch(part: Instance)
		local prompt = part:WaitForChild("SuitPrompt", 30)
		if prompt and prompt:IsA("ProximityPrompt") then
			label(prompt)
		end
	end

	for _, part in CollectionService:GetTagged("SuitLocker") do
		task.spawn(watch, part)
	end
	CollectionService:GetInstanceAddedSignal("SuitLocker"):Connect(function(part)
		task.spawn(watch, part)
	end)
	me:GetAttributeChangedSignal("SuitOn"):Connect(refreshAll)
end

return SuitClient
