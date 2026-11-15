--!strict
-- EventDirector: plays the mission events from Shared.MB_Events.Schedule at their sol and hour
-- (MB_BaseState.Sol / ClockTime, set by MB_ResourceServer) and sends them to the MB scripts
-- through ServerStorage.MB_EventCommand (MB_Missions: dust, quake, launch window;
-- MB_ResourceServer: solar storm, oxygen generator). "Play again" (ServerStorage.MB_ResetMission)
-- starts the schedule over. In Studio, F1..F6 (EventDebugClient) start an event right away.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local MB_Events = require(ReplicatedStorage.Shared.MB_Events)

local CHECK_SECONDS = 1
-- Used by the Studio keys, which have no schedule entry (game values).
local DEBUG_DEFAULTS: { [string]: MB_Events.Entry } = {
	DustStorm = { sol = 0, hour = 0, event = "DustStorm", seconds = 90 },
	DustDevil = { sol = 0, hour = 0, event = "DustDevil", seconds = 20 },
	Quake = { sol = 0, hour = 0, event = "Quake", panels = 2 },
	SolarStorm = { sol = 0, hour = 0, event = "SolarStorm" },
	LaunchWindow = { sol = 0, hour = 0, event = "LaunchWindow" },
	O2Failure = { sol = 0, hour = 0, event = "O2Failure" },
}

local EventDirector = {}

local fired: { [number]: boolean } = {}
local o2Broken = false

local function ensure(parent: Instance, className: string, name: string): Instance
	local inst = parent:FindFirstChild(name)
	if not (inst and inst:IsA(className)) then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
	end
	return inst :: Instance
end

local function run(command: BindableEvent, entry: MB_Events.Entry)
	local e = entry.event
	if e == "DustStorm" then
		command:Fire("dustStorm", entry.seconds)
	elseif e == "DustDevil" then
		command:Fire("dustDevil", entry.seconds)
	elseif e == "Quake" then
		command:Fire("quake", entry.panels)
	elseif e == "SolarStorm" then
		command:Fire("solarStorm", nil, entry.seconds)
	elseif e == "LaunchWindow" then
		command:Fire("launchWindow", true)
	elseif e == "O2Failure" then
		o2Broken = not o2Broken
		command:Fire("o2Failure", o2Broken)
	else
		warn(`[events] unknown event {e}`)
		return
	end
	print(`[events] {e}`)
end

local function due(entry: MB_Events.Entry, sol: number, hour: number): boolean
	return sol > entry.sol or (sol == entry.sol and hour >= entry.hour)
end

function EventDirector.start()
	local command = ensure(ServerStorage, "BindableEvent", "MB_EventCommand") :: BindableEvent

	local function reset()
		table.clear(fired)
		if o2Broken then
			o2Broken = false
			command:Fire("o2Failure", false)
		end
		command:Fire("launchWindow", false)
	end
	local function bindReset(child: Instance)
		if child.Name == "MB_ResetMission" and child:IsA("BindableEvent") then
			-- Run after the MB scripts reset the clock, so sol 1 events can play again.
			child.Event:Connect(function()
				task.defer(reset)
			end)
		end
	end
	for _, child in ServerStorage:GetChildren() do
		bindReset(child)
	end
	ServerStorage.ChildAdded:Connect(bindReset)

	-- Studio only: start any event with F1..F6.
	local debugRemote = ensure(ReplicatedStorage, "RemoteEvent", "MB_EventDebug") :: RemoteEvent
	debugRemote.OnServerEvent:Connect(function(_player, name: unknown)
		if RunService:IsStudio() and type(name) == "string" and DEBUG_DEFAULTS[name] then
			run(command, DEBUG_DEFAULTS[name])
		end
	end)

	task.spawn(function()
		local baseState = ReplicatedStorage:WaitForChild("MB_BaseState")
		while true do
			task.wait(CHECK_SECONDS)
			local sol = baseState:GetAttribute("Sol")
			local hour = baseState:GetAttribute("ClockTime")
			if type(sol) == "number" and type(hour) == "number" and baseState:GetAttribute("Launched") ~= true then
				for i, entry in MB_Events.Schedule do
					if not fired[i] and due(entry, sol, hour) then
						fired[i] = true
						run(command, entry)
					end
				end
			end
		end
	end)
end

return EventDirector
