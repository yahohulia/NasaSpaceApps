-- EventDirector (server): the ONE source of mission events, driven by Shared.MB_Events.
--   Schedule: MB_Events.Schedule by sol + game hour (MB_BaseState.Sol / ClockTime). F1-F7 start an event
--   in Studio (RemoteEvent MB_EventDebug, keys in EventUI). Every start/end goes to ReplicatedStorage.MB_EventLog.
--   Mechanics are not duplicated - the MB scripts in the place are commanded through ServerStorage.MB_EventCommand:
--     SolarStorm  -> MB_ResourceServer radiation storm (real NASA DONKI flare)        "solarStorm"
--     DustStorm   -> MB_Missions panel dust                                           "dustStorm"
--     DustDevil   -> MB_Missions blows the dust off + MB_ResourceServer power bonus    "dustDevil", "addPower"
--     Marsquake   -> MB_Missions breaks the radar antenna and solar panels             "quake"
--     Conjunction -> MB_BaseState.CommsOffline (radar offline on the HUD)
--     O2Failure   -> MB_ResourceServer stops the oxygen generator until it is repaired  "o2Failure"
--     LaunchWindow-> MB_Missions opens the launch; launch + "Mission complete" = MB_MissionClient
--   Clients get the event list through RemoteEvent MB_EventState (drawn by EventUI).
-- Replaces the first EventDirector (fixed schedule, no UI) so the game has one event system.
-- The place must NOT also run ServerScriptService.MB_EventDirector (its Studio copy): delete that when this is served.
local EventDirector = {}

function EventDirector.start()
	local CollectionService = game:GetService("CollectionService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local ServerStorage = game:GetService("ServerStorage")
	local Workspace = game:GetService("Workspace")

	local Events = require(ReplicatedStorage.Shared.MB_Events) :: any
	local Config = require(ReplicatedStorage:WaitForChild("MB_Config"))
	local C = Events.Config
	local baseState = ReplicatedStorage:WaitForChild("MB_BaseState")
	local notify = ReplicatedStorage:WaitForChild("MB_Notify") :: RemoteEvent
	local rng = Random.new()

	local function ensure(parent: Instance, className: string, name: string): Instance
		local inst = parent:FindFirstChild(name)
		if not inst then
			inst = Instance.new(className)
			inst.Name = name
			inst.Parent = parent
		end
		return inst :: Instance
	end
	local command = ensure(ServerStorage, "BindableEvent", "MB_EventCommand") :: BindableEvent
	local stateRemote = ensure(ReplicatedStorage, "RemoteEvent", "MB_EventState") :: RemoteEvent
	local debugRemote = ensure(ReplicatedStorage, "RemoteEvent", "MB_EventDebug") :: RemoteEvent
	local log = ensure(ReplicatedStorage, "Folder", "MB_EventLog")
	local resetMission = ServerStorage:WaitForChild("MB_ResetMission") :: BindableEvent

	-- State -------------------------------------------------------------------------------------------
	type Active = { id: string, phase: string, endsAt: number, fact: string?, token: number }
	local active: { [string]: Active } = {}
	local fired: { [number]: boolean } = {}
	local token = 0
	local logCount = 0

	local function clockText(): string
		local clock = baseState:GetAttribute("ClockTime") or 0
		local h = math.floor(clock)
		return string.format("Sol %d %02d:%02d", baseState:GetAttribute("Sol") or 1, h, math.floor((clock - h) * 60))
	end

	local function addLog(text: string)
		logCount += 1
		local entry = Instance.new("StringValue")
		entry.Name = string.format("%03d", logCount)
		entry.Value = `{clockText()} · {text}`
		entry.Parent = log
		print("[MB_EventDirector] " .. entry.Value)
	end

	local function snapshot(): { any }
		local list = {}
		for _, a in active do
			table.insert(list, { id = a.id, phase = a.phase, endsAt = a.endsAt, fact = a.fact })
		end
		return list
	end

	local function publish()
		stateRemote:FireAllClients(snapshot())
	end
	Players.PlayerAdded:Connect(function(player)
		stateRemote:FireClient(player, snapshot())
	end)

	local function sparky(text: string)
		local say = ReplicatedStorage:FindFirstChild("SparkySay")
		if say and say:IsA("RemoteEvent") then
			say:FireAllClients(text) -- SparkyClient shows unknown keys as plain text
		end
	end

	local function awardAll(def)
		local award = ServerStorage:FindFirstChild("MB_AwardAchievement")
		if def.achievement and award and award:IsA("BindableEvent") then
			for _, player in Players:GetPlayers() do
				award:Fire(player, "Event_" .. def.achievement, def.achievement, def.title)
			end
		end
	end

	-- Seconds of real time until a game hour on a sol (for the LaunchWindow deadline).
	local function secondsUntil(sol: number, hour: number): number
		local solSeconds = baseState:GetAttribute("SolSeconds") or Config.SolSeconds
		local nowHours = ((baseState:GetAttribute("Sol") or 1) - 1) * 24 + (baseState:GetAttribute("ClockTime") or 0)
		return math.max(0, ((sol - 1) * 24 + hour - nowHours) / 24 * solSeconds)
	end

	-- Lifecycle ---------------------------------------------------------------------------------------
	local finish: (id: string, success: boolean, extra: string?) -> ()

	local function setPhase(id: string, phase: string, seconds: number?)
		local a = active[id]
		if a then
			a.phase = phase
			a.endsAt = if seconds then Workspace:GetServerTimeNow() + seconds else 0
			publish()
		end
	end

	-- Calls fn every second while the event with this token is still running; fn returns true to stop.
	local function watch(id: string, my: number, fn: () -> boolean)
		task.spawn(function()
			while active[id] and active[id].token == my do
				if fn() then
					return
				end
				task.wait(1)
			end
		end)
	end

	local handlers: { [string]: (def: any, my: number) -> () } = {
		DustStorm = function(def, my)
			command:Fire("dustStorm", def.duration)
			setPhase("DustStorm", "active", def.duration)
			task.delay(def.duration, function()
				if active.DustStorm and active.DustStorm.token == my then
					finish("DustStorm", true)
				end
			end)
		end,
		DustDevil = function(def, my)
			command:Fire("dustDevil", def.duration)
			command:Fire("addPower", C.DUST_DEVIL_POWER_BONUS)
			setPhase("DustDevil", "active", def.duration)
			-- A spinning dust column crosses the solar field (visual only, removed after the event).
			local field = Workspace:FindFirstChild("MB_SolarField")
			if field and field:IsA("Model") then
				local cf = field:GetBoundingBox()
				local devil = Instance.new("Part")
				devil.Name = "MB_DustDevil"
				devil.Anchored = true
				devil.CanCollide = false
				devil.CanQuery = false
				devil.CastShadow = false
				devil.Shape = Enum.PartType.Cylinder
				devil.Size = Vector3.new(28, 7, 7)
				devil.Material = Enum.Material.Sand
				devil.Color = Color3.fromRGB(190, 120, 70)
				devil.Transparency = 0.45
				devil.Parent = Workspace
				local start = cf.Position + Vector3.new(-40, 12, 10)
				task.spawn(function()
					local t = 0
					while t < def.duration and devil.Parent do
						t += task.wait()
						local p = start + Vector3.new(80 * t / def.duration, 0, -20 * t / def.duration)
						devil.CFrame = CFrame.new(p) * CFrame.Angles(0, t * 8, math.rad(90))
					end
					devil:Destroy()
				end)
			end
			task.delay(def.duration, function()
				if active.DustDevil and active.DustDevil.token == my then
					finish("DustDevil", true)
				end
			end)
		end,
		SolarStorm = function(def, my)
			command:Fire("solarStorm", def.warning, def.duration)
			setPhase("SolarStorm", "warning", def.warning)
			local wasActive = false
			watch("SolarStorm", my, function()
				local on = baseState:GetAttribute("StormActive") == true
				if on and not wasActive then
					wasActive = true
					setPhase("SolarStorm", "active", def.duration)
				elseif not on and wasActive then
					finish("SolarStorm", true, baseState:GetAttribute("StormFact"))
					return true
				end
				return false
			end)
		end,
		Marsquake = function(_def, my)
			command:Fire("quake", rng:NextInteger(C.QUAKE_BREAK_MIN, C.QUAKE_BREAK_MAX))
			setPhase("Marsquake", "active", nil)
			task.wait(2)
			watch("Marsquake", my, function()
				local broken = baseState:GetAttribute("RadarOK") == false
				for _, panel in CollectionService:GetTagged("MB_Panel") do
					if panel:GetAttribute("Broken") == true then
						broken = true
					end
				end
				if not broken then
					finish("Marsquake", true)
					return true
				end
				return false
			end)
		end,
		Conjunction = function(def, my)
			baseState:SetAttribute("CommsOffline", true)
			setPhase("Conjunction", "active", def.duration)
			task.delay(def.duration, function()
				if active.Conjunction and active.Conjunction.token == my then
					baseState:SetAttribute("CommsOffline", false)
					finish("Conjunction", true)
				end
			end)
		end,
		O2Failure = function(_def, my)
			command:Fire("o2Failure", true)
			setPhase("O2Failure", "active", nil)
			task.wait(2) -- BindableEvents are deferred: let MB_ResourceServer set O2Broken first
			watch("O2Failure", my, function()
				if baseState:GetAttribute("O2Broken") ~= true then
					finish("O2Failure", true)
					return true
				end
				return false
			end)
		end,
		LaunchWindow = function(_def, my)
			command:Fire("launchWindow", true)
			setPhase("LaunchWindow", "active", secondsUntil(5, C.LAUNCH_DEADLINE_HOUR))
			local warnedLate = false
			watch("LaunchWindow", my, function()
				if baseState:GetAttribute("Launched") == true then
					finish("LaunchWindow", true)
					return true
				end
				local a = active.LaunchWindow
				if a and not warnedLate and a.endsAt > 0 and Workspace:GetServerTimeNow() > a.endsAt then
					warnedLate = true -- kid-friendly: the window stays open, we just say it is late
					notify:FireAllClients("launch_late")
				end
				return false
			end)
		end,
	}

	local function start(id: string)
		local def = Events.Defs[id]
		if not def or active[id] then
			return
		end
		token += 1
		active[id] = { id = id, phase = "active", endsAt = 0, token = token }
		addLog(id .. " started")
		if not def.silentStart then
			sparky(def.sparky)
		end
		local handler = handlers[id]
		if handler then
			task.spawn(handler, def, token)
		end
		publish()
	end

	finish = function(id: string, success: boolean, extra: string?)
		local a = active[id]
		local def = Events.Defs[id]
		if not a or not def then
			return
		end
		local my = a.token
		addLog(id .. (if success then " done" else " ended"))
		if success then
			awardAll(def)
		end
		a.phase = "done"
		a.endsAt = 0
		a.fact = if extra and extra ~= "" then def.fact .. "\n" .. extra else def.fact
		publish()
		task.delay(C.DONE_FLASH, function()
			if active[id] and active[id].token == my then
				active[id].phase = "fact"
				publish()
				task.delay(C.FACT_TIME, function()
					if active[id] and active[id].token == my then
						active[id] = nil
						publish()
					end
				end)
			end
		end)
	end

	-- Scheduler -----------------------------------------------------------------------------------------
	local function checkSchedule()
		local sol = baseState:GetAttribute("Sol") or 1
		local clock = baseState:GetAttribute("ClockTime") or 0
		for i, entry in Events.Schedule do
			if not fired[i] and sol == entry.sol and clock >= entry.hour then
				fired[i] = true
				local ok = true
				if entry.condition == "panelsDirty" then
					local total, n = 0, 0
					for _, panel in CollectionService:GetTagged("MB_Panel") do
						total += panel:GetAttribute("Dust") or 0
						n += 1
					end
					ok = n > 0 and total / n > 0.3
				end
				if ok then
					start(entry.id)
				end
			end
		end
	end
	baseState:GetAttributeChangedSignal("ClockTime"):Connect(checkSchedule)

	-- F1-F7 in Studio only.
	debugRemote.OnServerEvent:Connect(function(player, id)
		if RunService:IsStudio() and typeof(id) == "string" then
			addLog(`{player.Name} pressed debug key for {id}`)
			start(id)
		end
	end)

	-- Oxygen generator repair point (Workspace.MB_O2RepairPoint, tag MB_O2Repair).
	for _, part in CollectionService:GetTagged("MB_O2Repair") do
		if part:IsA("BasePart") then
			local p = Instance.new("ProximityPrompt")
			p.Name = "MB_Prompt"
			p.ActionText = "Repair generator"
			p.ObjectText = "Oxygen generator"
			p.HoldDuration = C.REPAIR_HOLD
			p.MaxActivationDistance = Config.PromptDistance
			p.RequiresLineOfSight = false
			p.Enabled = false
			p.Parent = part
			p.Triggered:Connect(function()
				command:Fire("o2Failure", false)
				notify:FireAllClients("o2_fixed")
			end)
			baseState:GetAttributeChangedSignal("O2Broken"):Connect(function()
				p.Enabled = baseState:GetAttribute("O2Broken") == true
			end)
		end
	end

	-- "Play again": a new mission starts the schedule from the beginning.
	resetMission.Event:Connect(function()
		table.clear(fired)
		table.clear(active)
		baseState:SetAttribute("CommsOffline", false)
		addLog("mission reset")
		publish()
	end)

	baseState:SetAttribute("CommsOffline", false)
	print("[MB_EventDirector] started: " .. #Events.Schedule .. " scheduled events")
end

return EventDirector
