-- MB_ResourceServer (ServerScriptService): the only source of truth for all resources.
-- Ticks every Config.TickSeconds. Personal resources -> Player attributes,
-- shared base resources -> attributes on ReplicatedStorage.MB_BaseState. Clients only read them.
-- Radiation storms use real NASA DONKI flares from ReplicatedStorage.MB_SolarEvents.
-- ServerStorage.MB_ResetMission (BindableEvent) restarts the mission ("Play again").
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("MB_Config"))
local SolarEvents = require(ReplicatedStorage:WaitForChild("MB_SolarEvents"))
local MissionClock = require(ReplicatedStorage.Shared.MissionClock)
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
local startedAt = 0
local lastTickAt = 0
local harvestReadyAt = 0
local stormStart = 0 -- server timestamp when the next flare begins
local stormPhase = "none" -- "none" | "warning" | "active"
local stormEvent = SolarEvents.Events[1]

local function clamp100(v: number): number
	return math.clamp(v, 0, 100)
end

local function scheduleStorm(now: number, first: boolean)
	local wait = if first then S.FirstAfterSeconds else rng:NextNumber(S.MinSols, S.MaxSols) * SOL
	if Config.DEBUG_FAST then
		wait = math.min(wait, 45)
	end
	stormStart = now + wait + S.WarningSeconds
end

local function resetBase()
	startedAt = workspace:GetServerTimeNow()
	lastTickAt = startedAt
	harvestReadyAt = 0
	power, baseAir, stormPhase = B.StartPower, B.StartBaseAir, "none"
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
	baseState:SetAttribute("MissionStartedAt", startedAt)
	scheduleStorm(startedAt, true)
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
local function zoneAt(pos: Vector3): BasePart?
	for _, zone in CollectionService:GetTagged(Config.InsideZoneTag) do
		if zone:IsA("BasePart") then
			local p = zone.CFrame:PointToObjectSpace(pos)
			local h = zone.Size / 2
			if math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z then
				return zone
			end
		end
	end
	return nil
end

-- The zone boxes reach above the roof, so a player standing on the roof was "inside" and got
-- free base air. Not inside if: the player stands (or jumps) on the roof (MB_RoofColliders), or
-- nothing covers them and they are higher than a jump above the zone floor.
local ROOF_FOLDER = "MB_RoofColliders"
local MAX_UNCOVERED_HEIGHT = 7 -- game value: root height above the zone floor still counted as inside

local function isUnderRoof(root: BasePart, zone: BasePart): boolean
	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	if zone.Parent then
		table.insert(ignore, zone.Parent)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	-- Standing or jumping on the roof?
	local below = workspace:Raycast(root.Position, Vector3.new(0, -30, 0), params)
	if below then
		local roofs = workspace:FindFirstChild(ROOF_FOLDER)
		if roofs and below.Instance:IsDescendantOf(roofs) then
			return false
		end
	end
	-- Anything above the head (roof, ceiling or the base mesh)?
	if workspace:Raycast(root.Position, Vector3.new(0, 60, 0), params) then
		return true
	end
	-- Open spots in the roof (doorways, gaps): inside only near the floor.
	local floorY = zone.Position.Y - zone.Size.Y / 2
	return root.Position.Y - floorY <= MAX_UNCOVERED_HEIGHT
end

-- The zone boxes do not cover every room edge (a strip along the central corridor wall, the rim of
-- the farm dome, ...). There a player is still under the base: a base mesh (Workspace.MarsBase) is
-- right above the head. Without this, running along a wall made the player "outside" for seconds
-- and the suit rescue (Suit.luau) teleported them to the airlock.
local BASE_MODEL = "MarsBase"
local COVER_HEIGHT = 40 -- studs to look up for the base ceiling

local function coveredByBase(root: BasePart): boolean
	local base = workspace:FindFirstChild(BASE_MODEL)
	if not base then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { base }
	return workspace:Raycast(root.Position, Vector3.new(0, COVER_HEIGHT, 0), params) ~= nil
end

local function playersInside(): { [Player]: boolean }
	local inside = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local zone = root and zoneAt(root.Position)
		if root and zone and isUnderRoof(root, zone) then
			inside[player] = true
		elseif root and not zone and coveredByBase(root) then
			inside[player] = true
		end
	end
	return inside
end

-- Radiation storm schedule (real NASA DONKI flare each time) ---------------------------------------
local function updateStorm(now: number): boolean
	local warnAt = stormStart - S.WarningSeconds
	local endAt = stormStart + S.DurationSeconds
	local phase = if now >= endAt
		then "none"
		elseif now >= stormStart then "active"
		elseif now >= warnAt then "warning"
		else "none"
	if phase ~= stormPhase then
		local previous = stormPhase
		stormPhase = phase
		if previous == "none" then
			stormEvent = SolarEvents.random(rng)
			baseState:SetAttribute("StormClass", stormEvent.Class)
			baseState:SetAttribute("StormEndsAt", endAt)
			baseState:SetAttribute("StormStartsAt", stormStart)
		end
		if phase == "warning" then
			notify:FireAllClients("storm_warning")
		elseif phase == "active" then
			baseState:SetAttribute("StormActive", true)
			notify:FireAllClients("storm_start")
		else
			baseState:SetAttribute("StormActive", false)
			baseState:SetAttribute("StormStartsAt", 0)
			baseState:SetAttribute("StormEndsAt", 0)
			if previous == "active" then
				-- One line with the real event behind this storm.
				notify:FireAllClients("storm_fact", SolarEvents.factLine(stormEvent))
			end
		end
	end
	if now >= endAt then
		scheduleStorm(now, false)
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
local function tick()
	local now = workspace:GetServerTimeNow()
	local dt = now - lastTickAt
	lastTickAt = now

	-- Clock and sol.
	local clock, sol = MissionClock.sample(now, startedAt, SOL, Config.StartClockTime, Config.StartSol)
	baseState:SetAttribute("Sol", sol)
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
	if power > 0 and baseAir < 100 then
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
		task.wait(Config.TickSeconds)
		local ok, err = pcall(tick)
		if not ok then
			warn("[MB_ResourceServer] tick failed: " .. tostring(err))
		end
	end
end)

print("[MB_ResourceServer] started" .. (if Config.DEBUG_FAST then " (DEBUG_FAST: 1 sol = 60 s)" else ""))
