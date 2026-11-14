-- Runs weather events built from NASA snapshots and replicates the current one
-- to clients as JSON in ReplicatedStorage.WeatherState@Payload ("" = calm).
-- Until the sol loop exists, a demo loop plays every event in ORDER.
-- Studio test: ServerStorage.WeatherDebug:Fire("<id>") or :Fire("clear").
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataMapping = require(ReplicatedStorage.Shared.DataMapping)
local WeatherEvents = require(ReplicatedStorage.Shared.WeatherEvents)

local remsSnapshot = require(script.Parent.data["rems-2018"]) :: any
local remsRecent = require(script.Parent.data["rems-recent"]) :: any
local radlab = require(script.Parent.data["radlab-2024-05"]) :: any
local flrSnapshot = require(script.Parent.data["donki-flr"]) :: any
local enlilSnapshot = require(script.Parent.data["donki-enlil-mars"]) :: any
local Donki = require(script.Parent.Donki)

-- Live DONKI rows, filled once at start; nil = use the snapshot.
local LIVE_DAYS = 30
local liveFlares: { WeatherEvents.FlareRow }? = nil
local liveEnlil: { WeatherEvents.EnlilRow }? = nil

-- Prefer live data; fall back to the snapshot if live is missing or yields nothing.
local function liveOrSnapshot(
	build: (WeatherEvents.Header, any, WeatherEvents.Label) -> WeatherEvents.Payload?,
	liveRows: any,
	snapshot: any
): WeatherEvents.Payload?
	if liveRows and #liveRows > 0 then
		local payload = build(Donki.header, liveRows, "LIVE")
		if payload then
			return payload
		end
	end
	return build(snapshot.header, snapshot.rows, "ARCHIVED")
end

local DEMO_LOOP = true

-- Event id -> builder. Add one event at a time; each id needs weather.<id>.* strings.
local BUILDERS: { [string]: () -> WeatherEvents.Payload? } = {
	dust = function()
		return WeatherEvents.dustStorm(remsSnapshot.header, remsSnapshot.rows)
	end,
	cold = function()
		return WeatherEvents.coldNight(remsRecent.header, remsRecent.rows)
	end,
	radiation = function()
		return WeatherEvents.radiationStorm(radlab.header, radlab.rows)
	end,
	flare = function()
		return liveOrSnapshot(WeatherEvents.solarFlare, liveFlares, flrSnapshot)
	end,
	cme = function()
		return liveOrSnapshot(WeatherEvents.cmeToMars, liveEnlil, enlilSnapshot)
	end,
}
local ORDER = { "dust", "cold", "radiation", "flare", "cme" }

local Weather = {}

local state: Folder

function Weather.set(id: string): boolean
	local build = BUILDERS[id]
	if not build then
		warn(`[weather] unknown event "{id}"`)
		return false
	end
	local ok, payload = pcall(build)
	if not ok or payload == nil then
		warn(`[weather] could not build "{id}": {payload}`)
		return false
	end
	state:SetAttribute("Payload", HttpService:JSONEncode(payload))
	print(`[weather] {id} on ({payload.label} · {payload.date})`)
	return true
end

function Weather.clear()
	state:SetAttribute("Payload", "")
	print("[weather] calm")
end

function Weather.start()
	state = Instance.new("Folder")
	state.Name = "WeatherState"
	state:SetAttribute("Payload", "")
	state.Parent = ReplicatedStorage

	task.spawn(function()
		local flares = Donki.get("FLR", LIVE_DAYS)
		liveFlares = if flares then WeatherEvents.flareRows(flares) else nil
		local enlil = Donki.get("WSAEnlilSimulations", LIVE_DAYS)
		liveEnlil = if enlil then WeatherEvents.enlilMarsRows(enlil) else nil
	end)

	if RunService:IsStudio() then
		local debug = Instance.new("BindableEvent")
		debug.Name = "WeatherDebug"
		debug.Event:Connect(function(id: string)
			if id == "clear" then
				Weather.clear()
			else
				Weather.set(id)
			end
		end)
		debug.Parent = ServerStorage
	end

	if DEMO_LOOP then
		task.spawn(function()
			while true do
				for _, id in ORDER do
					task.wait(DataMapping.demoCalmSeconds)
					Weather.set(id)
					task.wait(DataMapping.demoEventSeconds)
					Weather.clear()
				end
			end
		end)
	end
end

return Weather
