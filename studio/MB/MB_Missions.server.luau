-- MB_Missions (ServerScriptService): the jobs outside and the way home.
--   Solar field (Workspace.MB_SolarField, tag MB_Panel): dust settles on the panels, dusty panels give
--     less power (MB_BaseState.PanelEfficiency, used by MB_ResourceServer). "Clean" wipes a panel.
--   Science samples (Workspace.MB_Samples, tag MB_Sample): "Collect sample" -> MB_BaseState.SamplesCollected.
--   Radar (Workspace.MB_RadarAntenna): breaks now and then (MB_BaseState.RadarOK = false);
--     "Repair radar" at the antenna fixes it.
--   Victory: survive Config.Victory.SolsToSurvive sols AND collect all samples -> RocketReady.
--     "Launch" at Workspace.MB_LaunchConsole -> everyone sees the launch and "Mission complete".
--     "Play again" (RemoteEvent MB_Mission) restarts the whole mission.
-- Copy of the script that lives in the team place (studio/MB in the repo).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("MB_Config"))
local baseState = ReplicatedStorage:WaitForChild("MB_BaseState")
local notify = ReplicatedStorage:WaitForChild("MB_Notify") :: RemoteEvent
local resetMission = ServerStorage:WaitForChild("MB_ResetMission") :: BindableEvent
local rng = Random.new()
local EventsConfig = (require(ReplicatedStorage:WaitForChild("MB_Events")) :: any).Config
local dustStormUntil, devilUntil = 0, 0 -- set by MB_EventDirector (DustStorm / DustDevil)

local mission = ReplicatedStorage:FindFirstChild("MB_Mission")
if not mission then
	mission = Instance.new("RemoteEvent")
	mission.Name = "MB_Mission"
	mission.Parent = ReplicatedStorage
end

local function award(player: Player, id: string)
	local event = ServerStorage:FindFirstChild("MB_AwardAchievement")
	if event and event:IsA("BindableEvent") then
		event:Fire(player, id)
	end
end

local function prompt(parent: Instance, action: string, object: string, hold: number): ProximityPrompt
	local p = parent:FindFirstChild("MB_Prompt")
	if p and p:IsA("ProximityPrompt") then
		return p
	end
	local np = Instance.new("ProximityPrompt")
	np.Name = "MB_Prompt"
	np.ActionText = action
	np.ObjectText = object
	np.HoldDuration = hold
	np.MaxActivationDistance = Config.PromptDistance
	np.RequiresLineOfSight = false
	np.KeyboardKeyCode = Enum.KeyCode.E
	np.Parent = parent
	return np
end

-- Solar field ---------------------------------------------------------------------------------------
local PANEL = Config.Panels
local panels: { Model } = {}

local function paintDust(panel: Model)
	local dust = panel:GetAttribute("Dust") or 0
	local layer = panel:FindFirstChild("Dust")
	if layer and layer:IsA("BasePart") then
		layer.Transparency = 1 - math.clamp(dust, 0, 1) * 0.85
	end
	local deck = panel.PrimaryPart
	local p = deck and deck:FindFirstChild("MB_Prompt")
	if p and p:IsA("ProximityPrompt") then
		p.Enabled = dust > 0.15 and panel:GetAttribute("Broken") ~= true -- a broken panel shows only "Repair panel"
	end
end

-- Where the "Repair panel" prompt goes: Frame in the first panel models, Back in the new ones.
local function repairPart(panel: Model): Instance?
	return panel:FindFirstChild("Frame") or panel:FindFirstChild("Back") or panel.PrimaryPart
end

-- Marsquake damage: a broken panel glows red, gives no power and has a "Repair panel" prompt.
local function setPanelBroken(panel: Model, broken: boolean)
	panel:SetAttribute("Broken", broken)
	-- Red glow over the whole panel (the new panel models have an invisible Deck, so recolouring it shows nothing).
	local glow = panel:FindFirstChild("MB_BrokenGlow")
	if broken and not glow then
		local h = Instance.new("Highlight")
		h.Name = "MB_BrokenGlow"
		h.FillColor = Color3.fromRGB(220, 50, 40)
		h.FillTransparency = 0.45
		h.OutlineColor = Color3.fromRGB(255, 90, 70)
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = panel
	elseif not broken and glow then
		glow:Destroy()
	end
	local frame = repairPart(panel)
	local r = frame and frame:FindFirstChild("MB_RepairPrompt")
	if r and r:IsA("ProximityPrompt") then
		r.Enabled = broken
	end
	paintDust(panel) -- switches "Clean" off while broken, back on after the repair if there is dust

	-- The team's wipe mini-game (MB_PanelCleaning) has its own "Clean" prompt on the deck. Both use E in the
	-- same spot and Roblox shows only one, so it is off while the panel is broken; after the repair it follows
	-- MB_PanelCleaning's rule again (on only while the panel is Dirty).
	local deck = panel.PrimaryPart
	local wipe = deck and deck:FindFirstChild("MB_CleanPrompt")
	if wipe and wipe:IsA("ProximityPrompt") then
		wipe.Enabled = not broken and panel:GetAttribute("Dirty") == true
	end
end

for _, panel in CollectionService:GetTagged("MB_Panel") do
	if panel:IsA("Model") and panel.PrimaryPart then
		table.insert(panels, panel)
		local p = prompt(panel.PrimaryPart, "Clean", "Solar panel", PANEL.CleanHold)
		p.Triggered:Connect(function(player)
			panel:SetAttribute("Dust", 0)
			paintDust(panel)
			notify:FireClient(player, "panel_clean")
		end)
		paintDust(panel)
		local frame = repairPart(panel)
		if frame then
			local r = Instance.new("ProximityPrompt")
			r.Name = "MB_RepairPrompt"
			r.ActionText = "Repair panel"
			r.ObjectText = "Solar panel"
			r.HoldDuration = EventsConfig.REPAIR_HOLD
			r.MaxActivationDistance = Config.PromptDistance
			r.RequiresLineOfSight = false
			r.Enabled = false
			r.Parent = frame
			r.Triggered:Connect(function(player)
				setPanelBroken(panel, false)
				notify:FireClient(player, "panel_fixed")
			end)
		end
	end
end

-- Samples -------------------------------------------------------------------------------------------
local samples: { BasePart } = {}

local function showSample(rock: BasePart, visible: boolean)
	rock.Transparency = if visible then 0 else 1
	rock.CanCollide = visible
	local ring = rock:FindFirstChild("Ring")
	if ring and ring:IsA("BasePart") then
		ring.Transparency = if visible then 0.35 else 1
	end
	local p = rock:FindFirstChild("MB_Prompt")
	if p and p:IsA("ProximityPrompt") then
		p.Enabled = visible
	end
end

for _, rock in CollectionService:GetTagged("MB_Sample") do
	if rock:IsA("BasePart") then
		table.insert(samples, rock)
		local p = prompt(rock, "Collect sample", "Rock sample", Config.Samples.CollectHold)
		p.Triggered:Connect(function(player)
			if rock.Transparency >= 1 then
				return
			end
			showSample(rock, false)
			local n = (baseState:GetAttribute("SamplesCollected") or 0) + 1
			baseState:SetAttribute("SamplesCollected", n)
			notify:FireClient(player, "sample_got", `{n}/{#samples}`)
			award(player, "FirstSample")
		end)
	end
end

-- Radar -----------------------------------------------------------------------------------------------
local antenna = workspace:FindFirstChild("MB_RadarAntenna")
local statusLight = antenna and antenna:FindFirstChild("StatusLight")
local repairPoint = antenna and antenna:FindFirstChild("RepairPoint")

local function setRadar(ok: boolean)
	baseState:SetAttribute("RadarOK", ok)
	if statusLight and statusLight:IsA("BasePart") then
		statusLight.Color = if ok then Color3.fromRGB(60, 230, 110) else Color3.fromRGB(255, 60, 50)
	end
	local p = repairPoint and repairPoint:FindFirstChild("MB_Prompt")
	if p and p:IsA("ProximityPrompt") then
		p.Enabled = not ok
	end
end

if repairPoint then
	local p = prompt(repairPoint, "Repair radar", "Antenna", Config.Radar.RepairHold)
	p.Triggered:Connect(function(player)
		if baseState:GetAttribute("RadarOK") == false then
			setRadar(true)
			notify:FireAllClients("radar_fixed")
			notify:FireClient(player, "did_repair")
		end
	end)
end

-- Rocket ----------------------------------------------------------------------------------------------
local console = nil
for _, part in CollectionService:GetTagged("MB_LaunchConsole") do
	console = part
end
local launchButton = console and console.Parent and console.Parent:FindFirstChild("LaunchButton")

local function samplesLeft(): number
	return math.max(0, #samples - (baseState:GetAttribute("SamplesCollected") or 0))
end

local function updateRocket()
	local ready = baseState:GetAttribute("LaunchWindowOpen") == true -- opened by the LaunchWindow event
	if ready and baseState:GetAttribute("RocketReady") ~= true then
		notify:FireAllClients("rocket_ready")
	end
	baseState:SetAttribute("RocketReady", ready)
	if launchButton and launchButton:IsA("BasePart") then
		launchButton.Color = if ready then Color3.fromRGB(60, 230, 110) else Color3.fromRGB(120, 120, 120)
	end
end

if console then
	local p = prompt(console, "Launch", "Rocket", 1.5)
	p.Triggered:Connect(function(player)
		if baseState:GetAttribute("Launched") == true then
			return
		end
		if baseState:GetAttribute("RocketReady") ~= true then
			notify:FireClient(
				player,
				"rocket_not_ready",
				`wait for the launch window on sol 5 ({samplesLeft()} samples left)`
			)
			return
		end
		baseState:SetAttribute("Launched", true)
		-- 3 stars with all samples (MB_Events LaunchWindow), fewer stars with fewer samples.
		local got = baseState:GetAttribute("SamplesCollected") or 0
		local stars = if got >= #samples then 3 elseif got >= math.ceil(#samples * 2 / 3) then 2 else 1
		baseState:SetAttribute("Stars", stars)
		mission:FireAllClients("launch", stars)
		for _, other in Players:GetPlayers() do
			award(other, "MissionComplete")
		end
	end)
end

-- Reset ("Play again") -------------------------------------------------------------------------------
local function resetAll()
	baseState:SetAttribute("SamplesCollected", 0)
	baseState:SetAttribute("SamplesTotal", #samples)
	baseState:SetAttribute("Launched", false)
	baseState:SetAttribute("RocketReady", false)
	baseState:SetAttribute("LaunchWindowOpen", false)
	baseState:SetAttribute("Stars", 0)
	dustStormUntil, devilUntil = 0, 0
	for _, rock in samples do
		showSample(rock, true)
	end
	for _, panel in panels do
		panel:SetAttribute("Dust", 0)
		paintDust(panel)
		setPanelBroken(panel, false)
	end
	baseState:SetAttribute("PanelEfficiency", 1)
	setRadar(true)
	updateRocket()
end

mission.OnServerEvent:Connect(function(player, action)
	if action == "playAgain" and baseState:GetAttribute("Launched") == true then
		resetMission:Fire()
		resetAll()
		mission:FireAllClients("reset")
		for _, other in Players:GetPlayers() do
			task.spawn(function()
				other:LoadCharacter()
			end)
		end
		notify:FireClient(player, "new_mission")
	end
end)

-- Commands from MB_EventDirector (MB_Events.Schedule / F1-F7). No random events here any more.
local eventCommand = ServerStorage:WaitForChild("MB_EventCommand") :: BindableEvent
eventCommand.Event:Connect(function(command: string, a: any)
	if command == "dustStorm" then
		dustStormUntil = os.clock() + (a or 120)
	elseif command == "dustDevil" then
		devilUntil = os.clock() + (a or 20)
	elseif command == "quake" then
		setRadar(false)
		notify:FireAllClients("radar_broken")
		local candidates = table.clone(panels)
		for _ = 2, (a or 2) do
			if #candidates == 0 then
				break
			end
			setPanelBroken(table.remove(candidates, rng:NextInteger(1, #candidates)) :: Model, true)
		end
	elseif command == "launchWindow" then
		baseState:SetAttribute("LaunchWindowOpen", a == true)
		updateRocket()
	end
end)

resetAll()

-- Loop: dust, rocket readiness ------------------------------------------------------
task.spawn(function()
	while true do
		local dt = task.wait(1)
		-- Dust only settles during a DustStorm event; a DustDevil event blows it off (MB_EventDirector).
		local now = os.clock()
		local rate = if now < devilUntil
			then -0.1
			elseif now < dustStormUntil then EventsConfig.PANEL_DUST_PER_SEC
			else 0
		local output = 0
		for _, panel in panels do
			local dust = math.clamp((panel:GetAttribute("Dust") or 0) + rate * dt, 0, 1)
			panel:SetAttribute("Dust", dust)
			paintDust(panel)
			if panel:GetAttribute("Broken") ~= true then
				output += PANEL.MinEfficiency + (1 - PANEL.MinEfficiency) * (1 - dust)
			end
		end
		if #panels > 0 then
			baseState:SetAttribute("PanelEfficiency", output / #panels)
		end
		if baseState:GetAttribute("Launched") ~= true then
			updateRocket()
		end
	end
end)

print(
	("[MB_Missions] started: %d panels, %d samples, radar=%s, console=%s"):format(
		#panels,
		#samples,
		tostring(antenna ~= nil),
		tostring(console ~= nil)
	)
)
