-- MB_Music (StarterPlayerScripts): background music and ambience from ReplicatedStorage.MB_SoundConfig.
--   Day music from DayStartHour to DayEndHour (6:00-18:00 of MB_BaseState.ClockTime), night music otherwise,
--   storm music during a solar storm (if MB_SoundConfig.Storm is set). Cross-fades over FadeSeconds.
--   Wind ambience loops quietly while the player is outside (if MB_SoundConfig.Wind is set).
-- Any empty id is simply silent - no errors. Music is local to each player (not 3D).
-- Copy of the script that lives in the team place (studio/MB in the repo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("MB_Config"))
local SC = require(ReplicatedStorage:WaitForChild("MB_SoundConfig"))
local baseState = ReplicatedStorage:WaitForChild("MB_BaseState")
local player = Players.LocalPlayer

local fade = TweenInfo.new(SC.FadeSeconds or 3, Enum.EasingStyle.Sine)

local function track(name: string, id: string?): Sound?
	if not id or id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	return s
end

local day = track("MB_MusicDay", SC.Day)
local night = track("MB_MusicNight", SC.Night)
local storm = track("MB_MusicStorm", SC.Storm)
local wind = track("MB_Wind", SC.Wind)

local function fadeTo(sound: Sound, volume: number)
	if volume > 0 and not sound.IsPlaying then
		sound.TimePosition = 0
		sound:Play()
	end
	local tween = TweenService:Create(sound, fade, { Volume = volume })
	if volume == 0 then
		tween.Completed:Connect(function()
			if sound.Volume == 0 then
				sound:Stop()
			end
		end)
	end
	tween:Play()
end

local function isDay(): boolean
	local clock = baseState:GetAttribute("ClockTime")
	local c = if typeof(clock) == "number" then clock else 12
	return c >= Config.DayStartHour and c < Config.DayEndHour
end

local current: Sound? = nil
local function updateMusic()
	local want = if storm and baseState:GetAttribute("StormActive") == true then storm elseif isDay() then day else night
	if want == current then
		return
	end
	if current then
		fadeTo(current, 0)
	end
	current = want
	if want then
		fadeTo(want, SC.Volume or 0.3)
	end
end

local windOn: boolean? = nil
local function updateWind()
	if not wind then
		return
	end
	local outside = player:GetAttribute("IsInside") == false
	if outside ~= windOn then
		windOn = outside
		fadeTo(wind, if outside then SC.WindVolume or 0.25 else 0)
	end
end

baseState:GetAttributeChangedSignal("ClockTime"):Connect(updateMusic)
baseState:GetAttributeChangedSignal("StormActive"):Connect(updateMusic)
player:GetAttributeChangedSignal("IsInside"):Connect(updateWind)
updateMusic()
updateWind()
