-- MB_Atmosphere (ServerScriptService): Mars gravity, night lights around the base, the airlock lamp.
--   Workspace.Gravity = Config.Atmosphere.Gravity (Mars is 0.380 of Earth: NASA Mars Fact Sheet).
--   Lamps tagged MB_NightLight (Workspace.MB_BaseLights) shine from LightsOnHour to LightsOffHour.
--   The lamp above the "AIRLOCK" sign (tag MB_AirlockLamp): green = safe to go out,
--   red = a solar storm is coming or going on.
-- Reads ReplicatedStorage.MB_BaseState (set by MB_ResourceServer).
-- Copy of the script that lives in the team place (studio/MB in the repo).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("MB_Config"))
local A = Config.Atmosphere
local baseState = ReplicatedStorage:WaitForChild("MB_BaseState")

workspace.Gravity = A.Gravity

-- Night lights ------------------------------------------------------------------------------------
local ON_COLOR = Color3.fromRGB(255, 220, 160)
local OFF_COLOR = Color3.fromRGB(90, 85, 75)
local lightsOn: boolean? = nil

local function updateLights()
	local clock = baseState:GetAttribute("ClockTime")
	local c = if typeof(clock) == "number" then clock else 12
	local night = c >= A.LightsOnHour or c < A.LightsOffHour
	if night == lightsOn then
		return
	end
	lightsOn = night
	for _, bulb in CollectionService:GetTagged("MB_NightLight") do
		if bulb:IsA("BasePart") then
			bulb.Color = if night then ON_COLOR else OFF_COLOR
			bulb.Material = if night then Enum.Material.Neon else Enum.Material.SmoothPlastic
			local glow = bulb:FindFirstChildOfClass("PointLight")
			if glow then
				glow.Enabled = night
			end
		end
	end
end
baseState:GetAttributeChangedSignal("ClockTime"):Connect(updateLights)
updateLights()

-- Airlock lamp ------------------------------------------------------------------------------------
local GREEN = Color3.fromRGB(60, 230, 110)
local RED = Color3.fromRGB(255, 60, 50)

local function isDanger(): boolean
	local startsAt = baseState:GetAttribute("StormStartsAt")
	return baseState:GetAttribute("StormActive") == true or (typeof(startsAt) == "number" and startsAt > 0)
end

local function paintLamp(lamp: Instance)
	if not lamp:IsA("BasePart") then
		return
	end
	local danger = isDanger()
	lamp.Color = if danger then RED else GREEN
	lamp:SetAttribute("State", if danger then "red" else "green")
	local glow = lamp:FindFirstChildOfClass("PointLight")
	if glow then
		glow.Color = lamp.Color
	end
end

local function paintLamps()
	for _, lamp in CollectionService:GetTagged("MB_AirlockLamp") do
		paintLamp(lamp)
	end
end
baseState:GetAttributeChangedSignal("StormActive"):Connect(paintLamps)
baseState:GetAttributeChangedSignal("StormStartsAt"):Connect(paintLamps)
CollectionService:GetInstanceAddedSignal("MB_AirlockLamp"):Connect(paintLamp)
paintLamps()

print(
	("[MB_Atmosphere] gravity %.1f, %d night lights"):format(
		workspace.Gravity,
		#CollectionService:GetTagged("MB_NightLight")
	)
)
