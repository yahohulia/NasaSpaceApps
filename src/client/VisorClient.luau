-- Helmet visor while the player wears the space suit (Player attribute "SuitOn").
-- Layers (back to front), all textures from scripts/visor-texture.mjs:
--   dust  - Mars dust on the outside of the glass. Builds up outside (faster in a dust
--           storm); the player wipes it with R (or the on-screen button on touch):
--           a suit glove sweeps across the glass and leaves a smear that fades.
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
local WIPE_SECONDS = 1.6 -- the whole wipe: hand up, across to the left, back to the right, down
local SMEAR_LEFT = 0.14 -- a light smear of dust stays after the wipe...
local SMEAR_FADE = 1.6 -- ...and fades out in this many seconds
local WIPE_ACTION = "WipeVisor"
-- The suit glove (ReplicatedStorage.VisorGlove, a MeshPart built in Studio) is shown in front of the
-- camera, outside the glass. The mesh has its fingers along -Y; this turns them up with the palm to us.
local GLOVE_SCALE = 1.7
local GLOVE_TURN = CFrame.Angles(0, math.pi, math.pi)
-- Hand path in camera space: t (0..1 of WIPE_SECONDS), x, y, z (studs), roll (degrees).
-- Like Metro Exodus: up from below on the right, press on the glass, across to the left, back, down.
local PATH = {
	{ 0.0, 0.9, -1.15, -1.0, 28 },
	{ 0.18, 0.6, -0.12, -0.85, 14 },
	{ 0.52, -0.62, -0.02, -0.85, -12 },
	{ 0.82, 0.42, -0.1, -0.85, 10 },
	{ 1.0, 0.95, -1.2, -1.0, 30 },
}
local SWEEP_FROM, SWEEP_TO = 0.18, 0.52 -- the part of PATH that clears the dust
local PALM_HALF = 0.16 -- half the palm's width on screen (0..1), what it clears around its centre
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

-- Position on PATH at time t (0..1), smooth between the keys.
local function pathAt(t: number): (Vector3, number)
	for i = 1, #PATH - 1 do
		local a, b = PATH[i], PATH[i + 1]
		if t <= b[1] then
			local k = (t - a[1]) / (b[1] - a[1])
			k = k * k * (3 - 2 * k) -- smoothstep: eases in and out of every key
			local pos = Vector3.new(a[2], a[3], a[4]):Lerp(Vector3.new(b[2], b[3], b[4]), k)
			return pos, a[5] + (b[5] - a[5]) * k
		end
	end
	local last = PATH[#PATH]
	return Vector3.new(last[2], last[3], last[4]), last[5]
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

	-- The dust sits on the glass between the eye and the glove, so the 3D glove shows
	-- through the dust only where it has already wiped it off.
	local dustLayer = layer(gui, "Dust", Assets.VisorDust.id, 1)
	local fogLayer = layer(gui, "Fog", Assets.VisorFog.id, 2)
	local frameLayer = layer(gui, "Frame", Assets.VisorFrame.id, 3)
	-- The dust is clean to the right of the edge, which follows the palm as it sweeps left.
	-- Offset o: clean where screen x > o + 0.5. NO_CLEAN keeps all the dust.
	local NO_CLEAN = Vector2.new(0.7, 0)
	local wipeGradient = Instance.new("UIGradient")
	wipeGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.46, 0),
		NumberSequenceKeypoint.new(0.54, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	wipeGradient.Offset = NO_CLEAN
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
	local smearUntil = 0 -- os.clock() until the smear left by the glove fades out
	local hinted = false

	local function wipe(_: string, state: Enum.UserInputState)
		if state ~= Enum.UserInputState.Begin or wiping or not suited then
			return Enum.ContextActionResult.Pass
		end
		wiping = true
		task.spawn(function()
			local template = ReplicatedStorage:FindFirstChild("VisorGlove")
			local camera = workspace.CurrentCamera
			local glove: BasePart? = nil
			if template and template:IsA("BasePart") then
				local copy = template:Clone()
				copy.Size = template.Size * GLOVE_SCALE
				copy.Parent = camera -- local only, nobody else sees it
				glove = copy
			end
			local edge = 1.2 -- screen x (0..1) left of which the dust is still there
			local t = 0
			while t < WIPE_SECONDS and suited do
				t += RunService.RenderStepped:Wait()
				local k = math.min(t / WIPE_SECONDS, 1)
				local pos, roll = pathAt(k)
				local cf = camera.CFrame * CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(roll)) * GLOVE_TURN
				if glove then
					glove.CFrame = cf
				end
				if k >= SWEEP_FROM and k <= SWEEP_TO then
					local screen = camera:WorldToViewportPoint(cf.Position)
					edge = math.min(edge, screen.X / camera.ViewportSize.X - PALM_HALF)
					wipeGradient.Offset = Vector2.new(edge - 0.5, 0)
				elseif k > SWEEP_TO and edge < 1.2 then
					-- across and back: what is left is a light smear (fades in RenderStepped below)
					dust = math.min(dust, SMEAR_LEFT)
					smearUntil = os.clock() + SMEAR_FADE
					edge = 1.2
					wipeGradient.Offset = NO_CLEAN
				end
			end
			if glove then
				glove:Destroy()
			end
			wipeGradient.Offset = NO_CLEAN
			hinted = false
			wiping = false
		end)
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

		-- Dust: only outside, faster in a dust storm. Right after a wipe the smear fades first.
		if os.clock() < smearUntil then
			dust = math.max(0, dust - dt * SMEAR_LEFT / SMEAR_FADE)
		elseif suited and not wiping and me:GetAttribute("Indoors") == false then
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
