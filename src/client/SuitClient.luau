--!strict
-- Suit locker prompt text in the player's own language: "Put on suit" while the
-- suit is off, "Take off suit" while it is on (Server.Suit makes the prompts).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage.Shared.Strings)

local LOCKER_TAG = "SuitLocker"

local SuitClient = {}

function SuitClient.start()
	local player = Players.LocalPlayer
	local lang = Strings.langFromLocale(player.LocaleId)

	local function refresh(prompt: ProximityPrompt)
		local key = if player:GetAttribute("SuitOn") == true then "suit.prompt.take_off" else "suit.prompt.put_on"
		prompt.ActionText = Strings.get(key, lang)
		prompt.ObjectText = Strings.get("suit.object", lang)
	end

	local prompts: { ProximityPrompt } = {}
	local function bind(locker: Instance)
		task.spawn(function()
			local prompt = locker:WaitForChild("SuitPrompt", 30)
			if prompt and prompt:IsA("ProximityPrompt") then
				table.insert(prompts, prompt)
				refresh(prompt)
			end
		end)
	end
	for _, locker in CollectionService:GetTagged(LOCKER_TAG) do
		bind(locker)
	end
	CollectionService:GetInstanceAddedSignal(LOCKER_TAG):Connect(bind)

	player:GetAttributeChangedSignal("SuitOn"):Connect(function()
		for _, prompt in prompts do
			refresh(prompt)
		end
	end)
end

return SuitClient
