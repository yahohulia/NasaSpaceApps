--!strict
-- STUDIO-ONLY fake data for testing the HUD before ResourceSystem / StormEvent exist.
-- Every number here is made up. It never runs in a live server, and it stops itself
-- once a real system publishes (set Config.DevHudFeed = false when ResourceSystem lands).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local TICK_SECONDS = 1
local EVENT_EVERY_SECONDS = 90
local EVENT_LENGTH_SECONDS = 45

local DevHudFeed = {}

function DevHudFeed.start()
	if not (Config.DevHudFeed and RunService:IsStudio()) then
		return
	end
	warn("[DevHudFeed] Studio test data is ON (fake numbers). Turn off with Config.DevHudFeed = false.")

	local resourcesChanged = Remotes.get("ResourcesChanged")
	local eventChanged = Remotes.get("EventChanged")

	local t = 0
	local eventState: Remotes.EventState = { active = false }

	local function snapshot(): Remotes.ResourceSnapshot
		-- Slow waves so every bar and the low-warning colour can be seen.
		local function wave(period: number, phase: number): number
			return 0.5 + 0.5 * math.sin(t / period * 2 * math.pi + phase)
		end
		return {
			sol = 1 + t // 30,
			resources = {
				Oxygen = { amount = 100 * wave(40, 1), capacity = 100 },
				Water = { amount = 100 * wave(55, 3), capacity = 100 },
				Food = { amount = 100 * wave(70, 0), capacity = 100 },
			},
		}
	end

	local function setupPlayer(player: Player)
		local index = (#Players:GetPlayers() - 1) % #Config.Roles + 1
		if player:GetAttribute(Config.PlayerAttributes.Role) == nil then
			player:SetAttribute(Config.PlayerAttributes.Role, Config.Roles[index])
		end
		if player:GetAttribute(Config.PlayerAttributes.Dose) == nil then
			player:SetAttribute(Config.PlayerAttributes.Dose, 0)
		end
		resourcesChanged:FireClient(player, snapshot())
		eventChanged:FireClient(player, eventState)
	end
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end

	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			t += TICK_SECONDS
			resourcesChanged:FireAllClients(snapshot())

			local inEvent = (t % EVENT_EVERY_SECONDS) < EVENT_LENGTH_SECONDS and t >= 10
			if inEvent ~= eventState.active then
				eventState = if inEvent
					then { active = true, kind = "FLR", endsAt = workspace:GetServerTimeNow() + EVENT_LENGTH_SECONDS }
					else { active = false }
				eventChanged:FireAllClients(eventState)
			end
			for _, player in Players:GetPlayers() do
				local dose = player:GetAttribute(Config.PlayerAttributes.Dose)
				local value = if typeof(dose) == "number" then dose else 0
				local step = if inEvent then 2 else 0.3
				player:SetAttribute(Config.PlayerAttributes.Dose, (value + step) % Config.Dose.Limit)
			end
		end
	end)
end

return DevHudFeed
