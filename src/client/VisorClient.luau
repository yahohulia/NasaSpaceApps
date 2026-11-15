-- Helmet visor while the player wears the space suit (Player attribute "SuitOn").
-- Layers (back to front), all textures from scripts/visor-texture.mjs:
--   dust  - Mars dust on the outside of the glass. Builds up outside (faster in a dust
--           storm); the player wipes it with R (or the on-screen button on touch).
--   fog   - breath condensation on the inside. Comes on each exhale and dries off;
--           breathing gets faster when the suit's oxygen (MB "SuitO2") runs low.
--   frame - the helmet shell around the visor, out of focus, with glass glare.
-- Plus a light colour grade (local ColorCorrectionEffect).
-- DisplayOrder -9: above the vignette (-10), under every HUD.
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Strings = require(ReplicatedStorage.Shared.Strings)

local FADE_SECONDS = 0.8
local BREATH_CALM = 4.5 -- seconds per breath with plenty of oxygen
local BREATH_FAST = 2.0 -- seconds per breath with an empty suit
local FOG_CALM = 0.35 -- fog strength at the peak of a calm exhale (0..1)
local FOG_FAST = 0.75
local DUST_SECONDS = 120 -- outside in calm weather: clean -> fully dusty
local DUST_STORM_FACTOR = 4 -- dust storm makes it this many times faster
local DUST_MAX = 0.85 -- strongest dust layer (1 - ImageTransparency)
local DUST_HINT_AT = 0.45 -- remind the player to wipe at this level
local WIPE_SECONDS = 0.55
local WIPE_ACTION = "WipeVisor"
local GRADE = { TintColor = Color3.fromRGB(255, 246, 232), Contrast = 0.05, Saturation = -0.04 }
local NO_GRADE = { TintColor = Color3.new(1, 1, 1), Contrast = 0, Saturation = 0 }

local VisorClient = {}

local function layer(parent: Instance, name: string, image: string, z: number): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Image = image
	label.ScaleType = Enum.ScaleType.Stretch
	label.ImageTransparency = 1
	label.ZIndex = z
	label.Parent = parent
	return label
end

function VisorClient.start()
	local me = Players.LocalPlayer
	local lang = Strings.langFromLocale(me.LocaleId)
	local weather = ReplicatedStorage:WaitForChild("WeatherState")

	local gui = Instance.new("ScreenGui")
	gui.Name = "HelmetVisor"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -9
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local dustLayer = layer(gui, "Dust", Assets.VisorDust.id, 1)
	local fogLayer = layer(gui, "Fog", Assets.VisorFog.id, 2)
	local frameLayer = layer(gui, "Frame", Assets.VisorFrame.id, 3)
	-- The wipe sweeps a clean band across the dust from left to right.
	local wipeGradient = Instance.new("UIGradient")
	wipeGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.58, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	wipeGradient.Offset = Vector2.new(-1, 0)
	wipeGradient.Parent = dustLayer
	gui.Parent = me:WaitForChild("PlayerGui")

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "VisorGrade"
	for prop, value in NO_GRADE do
		(grade :: any)[prop] = value
	end
	grade.Parent = Lighting

	local suited = false
	local visible = 0 -- 0..1, fades with the suit
	local dust = 0 -- 0..1
	local breath = 0 -- seconds into the current breath
	local wiping = false
	local hinted = false

	local function wipe(_: string, state: Enum.UserInputState)
		if state ~= Enum.UserInputState.Begin or wiping or not suited then
			return Enum.ContextActionResult.Pass
		end
		wiping = true
		wipeGradient.Offset = Vector2.new(-1, 0)
		local sweep = TweenService:Create(
			wipeGradient,
			TweenInfo.new(WIPE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Offset = Vector2.new(1, 0) }
		)
		sweep.Completed:Connect(function()
			dust = 0
			hinted = false
			wipeGradient.Offset = Vector2.new(-1, 0)
			wiping = false
		end)
		sweep:Play()
		return Enum.ContextActionResult.Sink
	end

	local function apply()
		local on = me:GetAttribute("SuitOn") == true
		suited = on
		local info = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Sine)
		TweenService:Create(grade, info, if on then GRADE else NO_GRADE):Play()
		if on then
			ContextActionService:BindAction(WIPE_ACTION, wipe, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
			ContextActionService:SetTitle(WIPE_ACTION, Strings.get("visor.wipe.button", lang))
		else
			ContextActionService:UnbindAction(WIPE_ACTION)
			dust = 0 -- the suit goes back to the locker clean
		end
	end
	me:GetAttributeChangedSignal("SuitOn"):Connect(apply)
	apply()

	RunService.RenderStepped:Connect(function(dt)
		visible = math.clamp(visible + (if suited then dt else -dt) / FADE_SECONDS, 0, 1)
		gui.Enabled = visible > 0
		if visible <= 0 then
			return
		end

		-- Breathing: faster and foggier when the suit's oxygen is low.
		local o2 = me:GetAttribute("SuitO2")
		local need = if type(o2) == "number" then 1 - math.clamp(o2 / 50, 0, 1) else 0
		local period = BREATH_CALM + (BREATH_FAST - BREATH_CALM) * need
		local peak = FOG_CALM + (FOG_FAST - FOG_CALM) * need
		breath = (breath + dt) % period
		local phase = breath / period
		-- quick exhale (0..0.18), slow drying (0.18..0.75), clear glass after that
		local fog = if phase < 0.18 then phase / 0.18 elseif phase < 0.75 then 1 - (phase - 0.18) / 0.57 else 0
		fogLayer.ImageTransparency = 1 - fog * peak * visible

		-- Dust: only outside, faster in a dust storm.
		if suited and not wiping and me:GetAttribute("Indoors") == false then
			local raw = weather:GetAttribute("Payload")
			local storm = typeof(raw) == "string" and string.find(raw, '"id":"dust"', 1, true) ~= nil
			dust = math.min(1, dust + dt / DUST_SECONDS * (if storm then DUST_STORM_FACTOR else 1))
			if dust >= DUST_HINT_AT and not hinted then
				hinted = true
				pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
					Title = Strings.get("visor.hint.title", lang),
					Text = Strings.get("visor.wipe.hint", lang),
					Duration = 5,
				})
			end
		end
		dustLayer.ImageTransparency = 1 - dust * DUST_MAX * visible
		frameLayer.ImageTransparency = 1 - visible
	end)
end

return VisorClient
