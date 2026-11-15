-- MB_AirlockLamp (ServerScriptService): the lamp above the "AIRLOCK" sign (tag MB_AirlockLamp).
-- Green = safe to go outside. Red = a solar flare is coming or going on: stay inside.
-- Reads ReplicatedStorage.MB_BaseState (set by MB_ResourceServer); the server sets the colour so everyone
-- sees the same lamp.
-- Copy of the script that lives in the team place (studio/MB in the repo).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GREEN = Color3.fromRGB(60, 230, 110)
local RED = Color3.fromRGB(255, 60, 50)
local TAG = "MB_AirlockLamp"

local baseState = ReplicatedStorage:WaitForChild("MB_BaseState")

local function isDanger(): boolean
	local startsAt = baseState:GetAttribute("StormStartsAt")
	return baseState:GetAttribute("StormActive") == true or (typeof(startsAt) == "number" and startsAt > 0)
end

local function paint(lamp: Instance)
	if not lamp:IsA("BasePart") then
		return
	end
	local color = if isDanger() then RED else GREEN
	lamp.Color = color
	lamp:SetAttribute("State", if isDanger() then "red" else "green")
	local glow = lamp:FindFirstChildOfClass("PointLight")
	if glow then
		glow.Color = color
	end
end

local function paintAll()
	for _, lamp in CollectionService:GetTagged(TAG) do
		paint(lamp)
	end
end

baseState:GetAttributeChangedSignal("StormActive"):Connect(paintAll)
baseState:GetAttributeChangedSignal("StormStartsAt"):Connect(paintAll)
CollectionService:GetInstanceAddedSignal(TAG):Connect(paint)
paintAll()
