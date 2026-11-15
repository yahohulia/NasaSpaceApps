--!strict
-- MissionDirector (server): the five-sol mission on top of the existing systems.
-- Design: docs/superpowers/specs/2026-11-15-five-sol-mission-design.md. Sols and rules: Shared.MissionPlan.
--   * Each sol has 2-3 crew objectives. They tick from game state (polled every second) and from
--     ServerStorage.MB_ObjectiveDone:Fire(player?, id) (Crops, WaterPump, Sparky). Only ids of the
--     current sol count, and each counts once.
--   * The briefing "arrives from Earth" after the real round-trip signal delay (Horizons).
--   * When a sol ends, the finished sol gets a debrief (done / missed objectives, emergencies, fact).
--   * Failure (MissionPlan.failureReason) stops the mission until the crew picks:
--     "supplies" -> MB_EventCommand "emergencySupplies" (costs game hours), "restart" -> MB_ResetMission.
--   * On sol 2 at PUMP_BREAK_HOUR the water pump breaks (WaterPump.breakNow).
-- Clients read ReplicatedStorage.MissionState@Payload (JSON) and answer through RemoteEvent MissionChoice.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Horizons = require(script.Parent.Horizons)
local MissionPlan = require(ReplicatedStorage.Shared.MissionPlan)
local WaterPump = require(script.Parent.WaterPump)

local PUMP_BREAK_HOUR = 13 -- game value, TODO balance: sol 2, after the morning dust storm
local DIRTY_PANELS = 0.9 -- PanelEfficiency below this = the dust storm left the panels dirty

local MissionDirector = {}

type Debrief = {
	sol: number,
	done: { string },
	missed: { string },
	emergencies: number,
	fact: string,
	factEvent: string?,
}

local function ensure(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = parent
	return made
end

local function num(inst: Instance, name: string): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

-- Game minutes -> real seconds (a sol is 24 game hours of Config.SolSeconds real seconds).
local function gameMinutes(minutes: number): number
	return minutes * 60 * Config.SolSeconds / (24 * 60 * 60)
end

function MissionDirector.start()
	local baseState = ReplicatedStorage:WaitForChild("MB_BaseState")
	local state = ensure(ReplicatedStorage, "Folder", "MissionState")
	local choice = ensure(ReplicatedStorage, "RemoteEvent", "MissionChoice") :: RemoteEvent
	local objectiveDone = ensure(ServerStorage, "BindableEvent", "MB_ObjectiveDone") :: BindableEvent
	local command = ensure(ServerStorage, "BindableEvent", "MB_EventCommand") :: BindableEvent
	local resetMission = ensure(ServerStorage, "BindableEvent", "MB_ResetMission") :: BindableEvent

	-- Mission state (rebuilt by reset()).
	local sol = 0
	local briefAt = 0
	local done: { [string]: boolean } = {}
	local broken: { [string]: boolean } = {} -- "keep" objectives that failed this sol
	local emergencies = 0
	local debrief: Debrief? = nil
	local failed: string? = nil
	local pumpBroken = false
	-- What was seen during the sol, for "fix it again" objectives.
	local panelsWereDirty, radarWasBroken, o2WasBroken = false, false, false
	local samplesAtStart = 0
	local iceSeen: { [Player]: number } = {}

	local function current(): MissionPlan.Sol?
		return MissionPlan.sols[sol]
	end

	local function inSol(id: string): boolean
		local s = current()
		if not s then
			return false
		end
		for _, o in s.objectives do
			if o.id == id then
				return true
			end
		end
		return false
	end

	local function publish()
		local list = {}
		for id in done do
			table.insert(list, id)
		end
		state:SetAttribute(
			"Payload",
			HttpService:JSONEncode({
				sol = sol,
				briefAt = briefAt,
				done = list,
				debrief = debrief,
				failed = failed,
			})
		)
	end

	local function mark(id: string)
		if inSol(id) and not done[id] then
			done[id] = true
			print("[mission] done " .. id)
			publish()
		end
	end

	-- The debrief of the sol that just ended ("keep" objectives are judged now).
	local function closeSol()
		local s = current()
		if not s then
			return
		end
		local d: Debrief =
			{ sol = s.sol, done = {}, missed = {}, emergencies = emergencies, fact = s.fact, factEvent = s.factEvent }
		for _, o in s.objectives do
			local ok = if o.kind == "keep" then not broken[o.id] else done[o.id] == true
			table.insert(if ok then d.done else d.missed, o.id)
		end
		debrief = d
	end

	local function openSol(n: number)
		sol = n
		table.clear(done)
		table.clear(broken)
		emergencies = 0
		panelsWereDirty, radarWasBroken, o2WasBroken = false, false, false
		samplesAtStart = num(baseState, "SamplesCollected")
		table.clear(iceSeen)
		for _, player in Players:GetPlayers() do
			iceSeen[player] = num(player, "Ice")
		end
		-- The briefing comes from Earth: there and back at today's real light time.
		local ok, delay = pcall(Horizons.get)
		local minutes = if ok and delay then delay.minutes else Config.CommDelayMinutes
		briefAt = workspace:GetServerTimeNow() + gameMinutes(2 * minutes)
		print(string.format("[mission] sol %d board", n))
		publish()
	end

	local function reset()
		debrief = nil
		failed = nil
		pumpBroken = false
		openSol(num(baseState, "Sol") > 0 and num(baseState, "Sol") or 1)
	end

	-- Signals from other scripts.
	objectiveDone.Event:Connect(function(_player: Player?, id: string)
		if typeof(id) ~= "string" then
			return
		end
		if id == "pump" and not pumpBroken then
			return -- a random break fixed before the sol-2 break does not count
		end
		mark(id)
	end)
	resetMission.Event:Connect(function()
		task.defer(reset) -- after MB_ResourceServer has set Sol back to the start
	end)
	choice.OnServerEvent:Connect(function(_player, pick: unknown)
		if not failed then
			return
		end
		if pick == "supplies" then
			failed = nil
			emergencies += 1
			command:Fire("emergencySupplies")
			publish()
		elseif pick == "restart" then
			failed = nil
			resetMission:Fire()
			for _, player in Players:GetPlayers() do
				task.spawn(function()
					player:LoadCharacter()
				end)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		iceSeen[player] = nil
	end)

	reset()

	-- One check per second: sol change, objectives, the pump, failure.
	while true do
		task.wait(1)
		local nowSol = num(baseState, "Sol")
		if nowSol > sol and nowSol <= #MissionPlan.sols then
			closeSol()
			openSol(nowSol)
		end
		local clock = num(baseState, "ClockTime")

		-- Objectives from state.
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("SuitOn") == true and player:GetAttribute("IsInside") == false then
				mark("outside")
			end
			local ice = num(player, "Ice")
			if iceSeen[player] and ice > iceSeen[player] then
				mark("ice")
			end
			iceSeen[player] = ice
			if
				baseState:GetAttribute("StormActive") == true
				and player:GetAttribute("OutsideBlocked") == true
				and inSol("storm")
			then
				broken.storm = true
			end
		end
		local efficiency = baseState:GetAttribute("PanelEfficiency")
		if typeof(efficiency) == "number" then
			if efficiency < DIRTY_PANELS then
				panelsWereDirty = true
			elseif panelsWereDirty then
				mark("panels")
			end
		end
		if num(baseState, "Power") <= 0 and inSol("power") then
			broken.power = true
		end
		if num(baseState, "SamplesCollected") - samplesAtStart >= MissionPlan.SOL3_SAMPLES then
			mark("samples")
		end
		if baseState:GetAttribute("RadarOK") == false then
			radarWasBroken = true
		elseif radarWasBroken then
			mark("radar")
		end
		if baseState:GetAttribute("O2Broken") == true then
			o2WasBroken = true
		elseif o2WasBroken then
			mark("oxygen")
		end
		local total = num(baseState, "SamplesTotal")
		if total > 0 and num(baseState, "SamplesCollected") >= total then
			mark("allSamples")
		end
		if baseState:GetAttribute("Launched") == true then
			mark("launch")
		end

		-- Sol 2: the pump breaks once.
		if sol == 2 and clock >= PUMP_BREAK_HOUR and not pumpBroken then
			pumpBroken = true
			WaterPump.breakNow()
		end

		-- Failure.
		-- Only players whose resources are already set count (a player who just joined has none yet).
		local air = baseState:GetAttribute("BaseAir")
		if not failed and typeof(air) == "number" then
			local crew = {}
			for _, player in Players:GetPlayers() do
				local water, food = player:GetAttribute("Water"), player:GetAttribute("Food")
				if typeof(water) == "number" and typeof(food) == "number" then
					table.insert(crew, { water = water, food = food })
				end
			end
			local reason = MissionPlan.failureReason(air, crew)
			if reason and #crew > 0 then
				failed = reason
				print("[mission] failed " .. reason)
				publish()
			end
		end
	end
end

return MissionDirector
