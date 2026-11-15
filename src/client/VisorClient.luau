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
local WIPE_SECONDS = 1.0 -- one glove sweep across the glass
local SMEAR_LEFT = 0.12 -- a light smear of dust stays after the sweep...
local SMEAR_FADE = 1.2 -- ...and fades out in this many seconds
local WIPE_ACTION = "WipeVisor"
-- Suit glove colours (white suit, grey grip pads, orange cuff stripe).
local GLOVE = Color3.fromRGB(232, 232, 226)
local GLOVE_SHADE = Color3.fromRGB(176, 178, 176)
local GRIP = Color3.fromRGB(112, 116, 122)
local CUFF = Color3.fromRGB(150, 152, 156)
local STRIPE = Color3.fromRGB(236, 112, 40)
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

local function rounded(
	parent: Instance,
	name: string,
	color: Color3,
	size: UDim2,
	pos: UDim2,
	radius: number,
	z: number
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius, 0)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 72, 76)
	stroke.Thickness = 2
	stroke.Transparency = 0.35
	stroke.Parent = f
	f.Parent = parent
	return f
end

-- The palm side of a suit glove, seen through the visor from inside, fingers up.
-- Built from frames (no image asset). Size follows the screen height.
local function makeGlove(parent: Instance, z: number): Frame
	local hand = Instance.new("Frame")
	hand.Name = "WipeGlove"
	hand.AnchorPoint = Vector2.new(0.5, 0.35)
	hand.Size = UDim2.fromScale(0.42, 0.42)
	hand.BackgroundTransparency = 1
	hand.Visible = false
	hand.ZIndex = z
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 0.8
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = hand
	hand.Parent = parent

	-- sleeve and cuff at the bottom
	rounded(hand, "Sleeve", GLOVE_SHADE, UDim2.fromScale(0.62, 0.4), UDim2.fromScale(0.5, 0.95), 0.25, z)
	rounded(hand, "Cuff", CUFF, UDim2.fromScale(0.66, 0.12), UDim2.fromScale(0.5, 0.74), 0.4, z + 1)
	rounded(hand, "Stripe", STRIPE, UDim2.fromScale(0.66, 0.035), UDim2.fromScale(0.5, 0.74), 0.5, z + 2)
	-- palm with a grip pad
	local palm = rounded(hand, "Palm", GLOVE, UDim2.fromScale(0.64, 0.42), UDim2.fromScale(0.5, 0.5), 0.3, z + 1)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(GLOVE, GLOVE_SHADE)
	shade.Parent = palm
	rounded(hand, "Grip", GRIP, UDim2.fromScale(0.36, 0.2), UDim2.fromScale(0.52, 0.52), 0.35, z + 2)
	-- four fingers and the thumb
	local fingers = {
		{ x = 0.29, h = 0.26, y = 0.2 },
		{ x = 0.43, h = 0.3, y = 0.17 },
		{ x = 0.57, h = 0.29, y = 0.18 },
		{ x = 0.7, h = 0.23, y = 0.22 },
	}
	for i, f in fingers do
		local finger =
			rounded(hand, "Finger" .. i, GLOVE, UDim2.fromScale(0.13, f.h), UDim2.fromScale(f.x, f.y + f.h / 2), 0.5, z)
		rounded(finger, "Tip", GRIP, UDim2.fromScale(0.8, 0.22), UDim2.fromScale(0.5, 0.16), 0.5, z + 1)
	end
	local thumb = rounded(hand, "Thumb", GLOVE, UDim2.fromScale(0.14, 0.3), UDim2.fromScale(0.14, 0.52), 0.5, z)
	thumb.Rotation = -38
	return hand
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

	-- The glove wipes the outside of the glass: over the dust, under the inside fog and the helmet.
	local dustLayer = layer(gui, "Dust", Assets.VisorDust.id, 1)
	local glove = makeGlove(gui, 2)
	local fogLayer = layer(gui, "Fog", Assets.VisorFog.id, 10)
	local frameLayer = layer(gui, "Frame", Assets.VisorFrame.id, 11)
	-- The dust is clean to the left of the glove: the gradient's edge follows the glove.
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
	local smearUntil = 0 -- os.clock() until the smear left by the glove fades out
	local hinted = false

	local function wipe(_: string, state: Enum.UserInputState)
		if state ~= Enum.UserInputState.Begin or wiping or not suited then
			return Enum.ContextActionResult.Pass
		end
		wiping = true
		task.spawn(function()
			-- The glove comes in low on the left, rises over the middle of the glass and leaves
			-- on the right, tilting as it goes. The dust is clean wherever it has passed.
			glove.Visible = true
			local t = 0
			while t < WIPE_SECONDS and suited do
				t += RunService.RenderStepped:Wait()
				local e = TweenService:GetValue(
					math.min(t / WIPE_SECONDS, 1),
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut
				)
				local x = -0.2 + 1.4 * e
				glove.Position = UDim2.fromScale(x, 0.8 - 0.3 * math.sin(math.pi * e))
				glove.Rotation = -30 + 60 * e
				wipeGradient.Offset = Vector2.new(x - 0.5, 0)
			end
			glove.Visible = false
			wipeGradient.Offset = Vector2.new(-1, 0)
			-- A thin smear stays for a moment and fades (see RenderStepped below).
			dust = math.min(dust, SMEAR_LEFT)
			smearUntil = os.clock() + SMEAR_FADE
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
