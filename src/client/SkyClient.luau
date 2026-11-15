--!strict
-- Owns the look of the sky on this client. Blends three presets by the sun's height
-- (DataMapping.sky: day / sunset / night) and puts the current weather event's look
-- (DataMapping.looks) on top, fading it in and out.
-- The place's Sky uses black skybox faces, so the Atmosphere paints the day sky and
-- the night stays dark with stars (Sky.StarCount).
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataMapping = require(ReplicatedStorage.Shared.DataMapping)
local MissionClock = require(ReplicatedStorage.Shared.MissionClock)

local UPDATE_SECONDS = 0.1

local SkyClient = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Sun height from the time of day: 1 at noon, 0 at 6:00 and 18:00, -1 at midnight.
local function sunHeight(clockTime: number): number
	return math.sin((clockTime - 6) / 12 * math.pi)
end

-- Mix the three presets: full day above 0.3, full night below -0.12, sunset between.
local function mixPresets(height: number): DataMapping.SkyPreset
	local sky = DataMapping.sky
	local from, to, t
	if height >= 0.05 then
		from, to, t = sky.sunset, sky.day, math.clamp((height - 0.05) / 0.25, 0, 1)
	else
		from, to, t = sky.night, sky.sunset, math.clamp((height + 0.12) / 0.17, 0, 1)
	end
	return {
		density = lerp(from.density, to.density, t),
		offset = lerp(from.offset, to.offset, t),
		color = from.color:Lerp(to.color, t),
		decay = from.decay:Lerp(to.decay, t),
		glare = lerp(from.glare, to.glare, t),
		haze = lerp(from.haze, to.haze, t),
		brightness = lerp(from.brightness, to.brightness, t),
		ambient = from.ambient:Lerp(to.ambient, t),
		outdoorAmbient = from.outdoorAmbient:Lerp(to.outdoorAmbient, t),
	}
end

function SkyClient.start()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	local state = ReplicatedStorage:WaitForChild("WeatherState")
	local baseState = ReplicatedStorage:WaitForChild("MB_BaseState")
	local config = require(ReplicatedStorage:WaitForChild("MB_Config"))
	local initialClock = Lighting.ClockTime
	local isStudio = RunService:IsStudio()

	-- Current event look and its fade weight (0 = off, 1 = full).
	local look: DataMapping.Look? = nil
	local weight = 0
	local target = 0

	local function onPayload()
		local raw = state:GetAttribute("Payload")
		local id = nil
		if typeof(raw) == "string" and raw ~= "" then
			local ok, payload = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok and type(payload) == "table" then
				id = payload.id
			end
		end
		local nextLook = if id then DataMapping.looks[id] else nil
		if nextLook then
			if nextLook ~= look then
				look = nextLook
				weight = 0
			end
			target = 1
		else
			target = 0 -- keep `look` while it fades out
		end
	end
	state:GetAttributeChangedSignal("Payload"):Connect(onPayload)
	onPayload()

	local elapsed = UPDATE_SECONDS
	RunService.RenderStepped:Connect(function(dt)
		local startedAt = baseState:GetAttribute("MissionStartedAt")
		local solSeconds = baseState:GetAttribute("SolSeconds")
		local clock = initialClock
		if typeof(startedAt) == "number" and typeof(solSeconds) == "number" and solSeconds > 0 then
			clock = MissionClock.sample(
				workspace:GetServerTimeNow(),
				startedAt,
				solSeconds,
				config.StartClockTime,
				config.StartSol
			)
		else
			local replicatedClock = baseState:GetAttribute("ClockTime")
			if typeof(replicatedClock) == "number" then
				clock = replicatedClock
			end
		end
		-- Studio preview: set Lighting attribute DebugClockTime (0-24) to see any hour.
		local debugClock = if isStudio then Lighting:GetAttribute("DebugClockTime") else nil
		if typeof(debugClock) == "number" then
			clock = debugClock % 24
		end
		Lighting.ClockTime = clock

		elapsed += dt
		if elapsed < UPDATE_SECONDS then
			return
		end
		local step = elapsed
		elapsed = 0

		local fade = if look then look.fadeSeconds else 4
		if weight < target then
			weight = math.min(target, weight + step / fade)
		elseif weight > target then
			weight = math.max(target, weight - step / fade)
		end
		if weight == 0 and target == 0 then
			look = nil
		end

		local p = mixPresets(sunHeight(clock))

		local density, haze, color, brightness = p.density, p.haze, p.color, p.brightness
		if look then
			density = lerp(density, look.atmosphereDensity or density, weight)
			haze = lerp(haze, look.atmosphereHaze or haze, weight)
			color = color:Lerp(look.atmosphereColor or color, weight)
			brightness *= lerp(1, look.brightnessScale or 1, weight)
		end

		Lighting.Brightness = brightness
		Lighting.Ambient = p.ambient
		Lighting.OutdoorAmbient = p.outdoorAmbient
		atmosphere.Density = density
		atmosphere.Offset = p.offset
		atmosphere.Color = color
		atmosphere.Decay = p.decay
		atmosphere.Glare = p.glare
		atmosphere.Haze = haze
	end)
end

return SkyClient
