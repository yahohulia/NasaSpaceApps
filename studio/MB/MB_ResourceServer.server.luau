-- MB_ResourceServer (ServerScriptService): the only source of truth for all resources.
-- Ticks every Config.TickSeconds. Personal resources -> Player attributes,
-- shared base resources -> attributes on ReplicatedStorage.MB_BaseState. Clients only read them.
-- Radiation storms use real NASA DONKI flares from ReplicatedStorage.MB_SolarEvents.
-- ServerStorage.MB_ResetMission (BindableEvent) restarts the mission ("Play again").
-- Copy of the script that lives in the team place (studio/MB in the repo).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("MB_Config"))
local SolarEvents = require(ReplicatedStorage:WaitForChild("MB_SolarEvents"))
local EventsConfig = (require(ReplicatedStorage:WaitForChild("MB_Events")) :: any).Config
local P, B, S = Config.Player, Config.Base, Config.Storm
local SOL = if Config.DEBUG_FAST then 60 else Config.SolSeconds -- real seconds per sol
local rng = Random.new()

-- Shared state + channels --------------------------------------------------------------------------
local function ensure(parent: Instance, className: string, name: string): Instance
	local inst = parent:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
	end
	return inst :: Instance
end
local baseState = ensure(ReplicatedStorage, "Folder", "MB_BaseState")
local notify = ensure(ReplicatedStorage, "RemoteEvent", "MB_Notify") :: RemoteEvent
local resetEvent = ensure(ServerStorage, "BindableEvent", "MB_ResetMission") :: BindableEvent

local power, baseAir = B.StartPower, B.StartBaseAir
local elapsed = 0
local stormStart = 0 -- elapsed time when the next flare begins
local stormPhase = "none" -- "none" | "warning" | "active"
local stormEvent = SolarEvents.Events[1]

local function clamp100(v: number): number
	return math.clamp(v, 0, 100)
end

-- Solar storms are started only by MB_EventDirector (MB_Events.Schedule / F2) via ServerStorage.MB_EventCommand.
local stormWarning, stormDuration = S.WarningSeconds, S.DurationSeconds
local o2Broken = false -- MB_Events O2Failure: the oxygen generator is broken until repaired
local function scheduleStorm(_first: boolean)
	stormStart = math.huge -- no storm until the event director starts one
end
local function startSolarStorm(warning: number?, duration: number?)
	stormWarning = warning or S.WarningSeconds
	stormDuration = duration or S.DurationSeconds
	stormStart = elapsed + stormWarning
end

local function resetBase()
	power, baseAir, elapsed, stormPhase = B.StartPower, B.StartBaseAir, 0, "none"
	baseState:SetAttribute("Power", power)
	baseState:SetAttribute("BaseAir", baseAir)
	baseState:SetAttribute("Sol", Config.StartSol)
	baseState:SetAttribute("ClockTime", Config.StartClockTime)
	baseState:SetAttribute("StormActive", false)
	baseState:SetAttribute("StormStartsAt", 0) -- workspace:GetServerTimeNow() when the flare starts (0 = none)
	baseState:SetAttribute("StormEndsAt", 0)
	baseState:SetAttribute("StormClass", "")
	baseState:SetAttribute("CrewInside", 0)
	baseState:SetAttribute("SolSeconds", SOL)
	if baseState:GetAttribute("PanelEfficiency") == nil then
		baseState:SetAttribute("PanelEfficiency", 1)
	end
	o2Broken = false
	baseState:SetAttribute("O2Broken", false)
	scheduleStorm(true)
end
resetBase()

-- Players -------------------------------------------------------------------------------------------
local function setupPlayer(player: Player)
	player:SetAttribute("Food", P.StartFood)
	player:SetAttribute("Water", P.StartWater)
	player:SetAttribute("Fatigue", P.StartFatigue)
	player:SetAttribute("SuitO2", P.StartSuitO2)
	player:SetAttribute("Ice", 0)
	player:SetAttribute("IsInside", false)
end
Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

resetEvent.Event:Connect(function()
	resetBase()
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end)

-- Commands from MB_EventDirector.
local eventCommand = ensure(ServerStorage, "BindableEvent", "MB_EventCommand") :: BindableEvent
eventCommand.Event:Connect(function(command: string, a: any, b: any)
	if command == "solarStorm" then
		startSolarStorm(a, b)
	elseif command == "addPower" then
		power = clamp100(power + (a or 0))
		baseState:SetAttribute("Power", power)
	elseif command == "o2Failure" then
		o2Broken = a == true
		baseState:SetAttribute("O2Broken", o2Broken)
	end
end)

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function rescueSpot(): CFrame?
	local habitat = workspace:FindFirstChild("Base") and workspace.Base:FindFirstChild("Habitat")
	local airlock = habitat and habitat:FindFirstChild("Airlock")
	local spot = (airlock and airlock:FindFirstChild("InsideSpot")) or (habitat and habitat:FindFirstChild("BaseSpawn"))
	return if spot and spot:IsA("BasePart") then spot.CFrame + Vector3.new(0, 3, 0) else nil
end

-- Inside / outside: the player's HumanoidRootPart centre is inside any part tagged Config.InsideZoneTag
-- (Workspace.MB_HabitatZone: boxes over the base floors + copies of the team's BaseZone volumes).
local function isInsideZone(pos: Vector3): boolean
	for _, zone in CollectionService:GetTagged(Config.InsideZoneTag) do
		if zone:IsA("BasePart") then
			local p = zone.CFrame:PointToObjectSpace(pos)
			local h = zone.Size / 2
			if math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z then
				return true
			end
		end
	end
	return false
end

local function playersInside(): { [Player]: boolean }
	local inside = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and isInsideZone(root.Position) then
			inside[player] = true
		end
	end
	return inside
end

-- Radiation storm schedule (real NASA DONKI flare each time) ---------------------------------------
local function updateStorm(now: number): boolean
	local warnAt = stormStart - stormWarning
	local endAt = stormStart + stormDuration
	local phase = if elapsed >= endAt
		then "none"
		elseif elapsed >= stormStart then "active"
		elseif elapsed >= warnAt then "warning"
		else "none"
	if phase ~= stormPhase then
		local previous = stormPhase
		stormPhase = phase
		if phase == "warning" then
			stormEvent = SolarEvents.random(rng)
			baseState:SetAttribute("StormClass", stormEvent.Class)
			baseState:SetAttribute("StormFact", SolarEvents.factLine(stormEvent))
			baseState:SetAttribute("StormStartsAt", now + (stormStart - elapsed))
			notify:FireAllClients("storm_warning")
		elseif phase == "active" then
			baseState:SetAttribute("StormActive", true)
			baseState:SetAttribute("StormEndsAt", now + (endAt - elapsed))
			notify:FireAllClients("storm_start")
		else
			baseState:SetAttribute("StormActive", false)
			baseState:SetAttribute("StormStartsAt", 0)
			baseState:SetAttribute("StormEndsAt", 0)
			if previous == "active" then
				-- The real DONKI flare (MB_BaseState.StormFact) is shown on the event card by MB_EventUI.
				stormStart = math.huge
			end
		end
	end
	return stormPhase == "active"
end

-- One-shot warnings so the HUD does not spam the same message.
local warned: { [string]: boolean } = {}
local function warnOnce(key: string, condition: boolean, send: () -> ())
	if condition and not warned[key] then
		warned[key] = true
		send()
	elseif not condition then
		warned[key] = nil
	end
end

-- Tick ------------------------------------------------------------------------------------------------
local function tick(dt: number)
	elapsed += dt
	local now = workspace:GetServerTimeNow()

	-- Clock and sol.
	local hours = Config.StartClockTime + 24 * elapsed / SOL
	local clock = hours % 24
	baseState:SetAttribute("Sol", Config.StartSol + math.floor(hours / 24))
	baseState:SetAttribute("ClockTime", clock)
	if Config.SyncLighting then
		Lighting.ClockTime = clock
	end

	local stormActive = updateStorm(now)
	local inside = playersInside()
	local crewInside = 0
	for _ in inside do
		crewInside += 1
	end
	baseState:SetAttribute("CrewInside", crewInside)

	-- Base: solar power (dusty panels give less), oxygen generator, crew breathing.
	local day = clock >= Config.DayStartHour and clock < Config.DayEndHour
	local efficiency = baseState:GetAttribute("PanelEfficiency")
	local panels = if typeof(efficiency) == "number" then efficiency else 1
	local solar = if day then B.SolarPower * panels * (if stormActive then S.SolarFactor else 1) else 0
	power = clamp100(power + (solar - B.BaseLoadPower) * dt)
	if o2Broken then
		baseAir -= EventsConfig.BASEAIR_DRAIN * dt -- broken generator: the air runs out
	elseif power > 0 and baseAir < 100 then
		baseAir += B.AirGenerator * dt
		power = clamp100(power - B.GeneratorPower * dt)
	end
	baseAir = clamp100(baseAir - B.AirPerPersonInside * crewInside * dt)
	baseState:SetAttribute("Power", power)
	baseState:SetAttribute("BaseAir", baseAir)
	warnOnce("power", power <= 0, function()
		notify:FireAllClients("power_empty")
	end)
	warnOnce("air", baseAir <= 0, function()
		notify:FireAllClients("base_air_empty")
	end)

	-- Players.
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = rootOf(player)
		if not (humanoid and root) then
			continue
		end
		local isInside = inside[player] == true
		player:SetAttribute("IsInside", isInside)

		local food = clamp100((player:GetAttribute("Food") or 0) - P.FoodDrain * dt)
		local water = clamp100((player:GetAttribute("Water") or 0) - P.WaterDrain * dt)
		local fatigue = clamp100(
			(player:GetAttribute("Fatigue") or 0)
				+ (if isInside then P.FatigueGainInside else P.FatigueGainOutside) * dt
		)
		local suit = player:GetAttribute("SuitO2") or 0
		if isInside and baseAir > 0 then
			suit += P.SuitO2Refill * dt
		elseif isInside then
			suit -= P.SuitO2DrainNoBaseAir * dt
		else
			suit -= P.SuitO2DrainOutside * (if stormActive then S.OutsideSuitDrainMultiplier else 1) * dt
		end
		suit = clamp100(suit)

		-- Storm radiation: only outside; the dome keeps the crew safe. Adds to the team's Player.Dose (μGy).
		if stormActive and not isInside then
			local dose = player:GetAttribute("Dose")
			player:SetAttribute("Dose", (if typeof(dose) == "number" then dose else 0) + S.DoseOutsidePerSecond * dt)
		end

		if suit <= 0 then
			-- No death: the crew brings the player back inside.
			local spot = rescueSpot()
			if spot then
				character:PivotTo(spot)
			end
			suit = P.RescueSuitO2
			fatigue = clamp100(fatigue + P.RescueFatigue)
			notify:FireClient(player, "rescued")
		end
		warnOnce(`suit{player.UserId}`, not isInside and suit < 25, function()
			notify:FireClient(player, "suit_low")
		end)

		player:SetAttribute("Food", food)
		player:SetAttribute("Water", water)
		player:SetAttribute("Fatigue", fatigue)
		player:SetAttribute("SuitO2", suit)

		local slow = food <= 0 or water <= 0 or fatigue >= P.TiredAt
		local speed = if slow then P.SlowWalkSpeed else P.NormalWalkSpeed
		if humanoid.WalkSpeed ~= speed then
			humanoid.WalkSpeed = speed
		end
	end
end

-- Interactions -------------------------------------------------------------------------------------
local harvestReadyAt = 0

local handlers: { [string]: (Player) -> () } = {
	DigIce = function(player)
		local a = Config.Actions.DigIce
		local ice = player:GetAttribute("Ice") or 0
		if ice >= P.MaxIce then
			notify:FireClient(player, "ice_full")
			return
		end
		player:SetAttribute("Ice", ice + a.Ice)
		player:SetAttribute("Fatigue", clamp100((player:GetAttribute("Fatigue") or 0) + a.Fatigue))
		notify:FireClient(player, "ice_got")
	end,
	Drink = function(player)
		local a = Config.Actions.Drink
		local ice = player:GetAttribute("Ice") or 0
		if ice < 1 then
			notify:FireClient(player, "need_ice")
			return
		end
		player:SetAttribute("Ice", ice - 1)
		player:SetAttribute("Water", clamp100((player:GetAttribute("Water") or 0) + a.Water))
	end,
	Harvest = function(player)
		local a = Config.Actions.Harvest
		local now = workspace:GetServerTimeNow()
		if now < harvestReadyAt then
			notify:FireClient(player, "harvest_wait", math.ceil(harvestReadyAt - now))
			return
		end
		harvestReadyAt = now + a.Cooldown
		player:SetAttribute("Food", clamp100((player:GetAttribute("Food") or 0) + a.Food))
	end,
	Rest = function(player)
		local a = Config.Actions.Rest
		player:SetAttribute("Fatigue", clamp100((player:GetAttribute("Fatigue") or 0) + a.Fatigue))
	end,
}

local function bindAction(name: string, part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("MB_Prompt") then
		return
	end
	local a = Config.Actions[name]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MB_Prompt"
	prompt.ActionText = a.Text
	prompt.ObjectText = a.Object
	prompt.HoldDuration = a.Hold
	prompt.MaxActivationDistance = Config.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Triggered:Connect(handlers[name])
	prompt.Parent = part
end

for name, a in Config.Actions do
	for _, part in CollectionService:GetTagged(a.Tag) do
		bindAction(name, part)
	end
	CollectionService:GetInstanceAddedSignal(a.Tag):Connect(function(part)
		bindAction(name, part)
	end)
end

-- Main loop ---------------------------------------------------------------------------------------
task.spawn(function()
	while true do
		local dt = task.wait(Config.TickSeconds)
		local ok, err = pcall(tick, dt)
		if not ok then
			warn("[MB_ResourceServer] tick failed: " .. tostring(err))
		end
	end
end)

print("[MB_ResourceServer] started" .. (if Config.DEBUG_FAST then " (DEBUG_FAST: 1 sol = 60 s)" else ""))
