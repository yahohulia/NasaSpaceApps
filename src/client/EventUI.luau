-- EventUI (client): shows the events from EventDirector (RemoteEvent MB_EventState).
--   New event -> the full card for BANNER_TIME s -> it folds into a small square (icon + timer).
--   The square stays until the event is over. Tap the square (or press G) -> the full card again;
--   it stays open until the player taps X (or G). One square per running event.
--   Event over -> "done" flash -> "Real event" card with the fact (FACT_TIME s).
--   Marsquake shakes the camera. F1-F7 start events (Studio only, checked on the server).
-- Sits under the MB_HUD centre column (and the weather card), never below 0.55 of the screen.
-- Text and numbers come from Shared.MB_Events. Replaces EventDebugClient (its F-keys live here now).
-- The place must NOT also run StarterPlayerScripts.MB_EventUI (its Studio copy): delete that when this is served.
local EventUI = {}

function EventUI.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")

	local Events = require(ReplicatedStorage.Shared.MB_Events) :: any
	local C = Events.Config
	local stateRemote = ReplicatedStorage:WaitForChild("MB_EventState")
	local debugRemote = ReplicatedStorage:WaitForChild("MB_EventDebug")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local FONT = Font.fromEnum(Enum.Font.BuilderSans)
	local BOLD = Font.new(FONT.Family, Enum.FontWeight.Bold)
	local HEAVY = Font.new(FONT.Family, Enum.FontWeight.Heavy)
	local TEXT = Color3.fromRGB(245, 240, 235)
	local MUTED = Color3.fromRGB(200, 205, 215)
	local MAX_Y = 0.55

	local gui = Instance.new("ScreenGui")
	gui.Name = "MB_EventUI"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- same space as MB_HUD, positions match directly
	gui.DisplayOrder = 7
	gui.Parent = playerGui

	local function new(className: string, props: { [string]: any }): any
		local inst = Instance.new(className)
		for k, v in props do
			if k ~= "Parent" then
				(inst :: any)[k] = v
			end
		end
		inst.Parent = props.Parent
		return inst
	end

	local function label(
		parent: Instance,
		order: number,
		font: Font,
		size: number,
		color: Color3,
		wrap: boolean?
	): TextLabel
		return new("TextLabel", {
			LayoutOrder = order,
			AutomaticSize = if wrap then Enum.AutomaticSize.Y else Enum.AutomaticSize.XY,
			Size = if wrap then UDim2.fromScale(1, 0) else UDim2.new(),
			BackgroundTransparency = 1,
			FontFace = font,
			TextSize = size,
			TextColor3 = color,
			TextWrapped = wrap == true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
			Parent = parent,
		})
	end

	-- Card (banner / panel / fact) ------------------------------------------------------------------------
	local card = new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(C.UI_WIDTH, 0),
		BackgroundColor3 = Color3.fromRGB(10, 10, 14),
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = card })
	local cardStroke = new("UIStroke", { Thickness = 3, Parent = card })
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 12),
		Parent = card,
	})
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = card })
	new("UISizeConstraint", { MinSize = Vector2.new(260, 0), Parent = card })
	local cTitle = label(card, 1, HEAVY, 20, TEXT)
	local cShort = label(card, 2, BOLD, 15, TEXT, true)
	local cBody = label(card, 3, FONT, 14, MUTED, true)
	local cTodo = label(card, 4, FONT, 14, TEXT, true)
	local cRole = label(card, 5, FONT, 13, MUTED, true)
	local cTimer = label(card, 6, BOLD, 15, TEXT)
	local cardScale = new("UIScale", { Parent = card })

	-- ✕ button on the card's top-right corner (a separate button so the card's list layout ignores it).
	local closeButton = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Color3.fromRGB(55, 55, 66),
		FontFace = HEAVY,
		TextSize = 16,
		TextColor3 = TEXT,
		Text = "X", -- the BuilderSans font has no ✕ glyph
		Visible = false,
		ZIndex = 3,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = closeButton })
	new(
		"UIStroke",
		{ Thickness = 2, Color = TEXT, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = closeButton }
	)
	local closeScale = new("UIScale", { Parent = closeButton })

	-- Squares: one per running event (icon + timer). Tap = open the full card again. ----------------------
	local iconRow = new("Frame", {
		Name = "Icons",
		AnchorPoint = Vector2.new(0.5, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = iconRow,
	})
	local iconScale = new("UIScale", { Parent = iconRow })

	-- State ---------------------------------------------------------------------------------------------
	type Entry = { id: string, phase: string, endsAt: number, fact: string? }
	local events: { Entry } = {}
	local mode = "none" -- "banner" (closes itself) | "panel" (open until ✕) | "fact" | "none" (squares)
	local modeUntil = 0
	local focus: Entry? = nil
	local seen: { [string]: string } = {} -- id -> last phase shown
	local shakeUntil = 0 -- marsquake camera shake

	local function mmss(seconds: number): string
		local s = math.max(0, math.ceil(seconds))
		return string.format("%d:%02d", s // 60, s % 60)
	end

	local function timerText(e: Entry): string
		if e.endsAt <= 0 then
			return ""
		end
		local left = e.endsAt - workspace:GetServerTimeNow()
		if e.phase == "warning" then
			return "⏱ Starts in " .. mmss(left)
		end
		return "⏱ " .. mmss(left)
	end

	local function fill(e: Entry, full: boolean)
		local def = Events.Defs[e.id]
		if not def then
			return
		end
		local color = Events.Colors[def.type] or Events.Colors.info
		if e.phase == "done" then
			color = Events.Colors.done
		end
		cardStroke.Color = color
		if e.phase == "fact" then
			cTitle.Text = "🛰 Real event"
			cShort.Text = e.fact or def.fact
			cBody.Visible, cTodo.Visible, cRole.Visible, cTimer.Visible = false, false, false, false
			return
		end
		cTitle.Text = def.icon .. "  " .. (if e.phase == "done" then def.title .. " ✓" else def.title)
		cShort.Text = def.short
		cBody.Text = def.description
		cTodo.Text = table.concat(def.todo, "\n")
		cRole.Text = "👤 " .. def.role
		cBody.Visible, cTodo.Visible, cRole.Visible = full, full, full
		cTimer.Visible = true
		cTimer.Text = timerText(e)
	end

	local function pickFocus(): Entry?
		-- Prefer dangerous running events, then anything else.
		local best: Entry? = nil
		for _, e in events do
			local def = Events.Defs[e.id]
			if def and (not best or (def.type == "danger" and e.phase ~= "fact")) then
				best = e
			end
		end
		return best
	end

	local function setMode(m: string, seconds: number?)
		mode = m
		modeUntil = if seconds then os.clock() + seconds else math.huge
	end

	stateRemote.OnClientEvent:Connect(function(list: { Entry })
		events = list
		for _, e in list do
			local before = seen[e.id]
			seen[e.id] = e.phase
			if before ~= e.phase then
				local def = Events.Defs[e.id]
				if before == nil and (e.phase == "warning" or e.phase == "active") then
					focus = e
					setMode("banner", C.BANNER_TIME)
					if e.id == "Marsquake" then
						shakeUntil = os.clock() + 3
					end
				elseif e.phase == "done" then
					focus = e
					setMode("banner", C.DONE_FLASH)
				elseif e.phase == "fact" then
					focus = e
					setMode("fact", C.FACT_TIME)
				elseif e.phase == "active" and def and before == "warning" then
					focus = e
					setMode("banner", C.BANNER_TIME)
				end
			end
		end
		-- Forget events that are gone.
		for id in seen do
			local still = false
			for _, e in list do
				if e.id == id then
					still = true
				end
			end
			if not still then
				seen[id] = nil
			end
		end
	end)

	-- Open the full card of one event (or the most important one); it stays open until ✕ / G.
	local function openPanel(id: string?)
		local pick: Entry? = nil
		for _, e in events do
			if e.id == id then
				pick = e
			end
		end
		focus = pick or pickFocus()
		if focus then
			setMode("panel")
		end
	end

	local function togglePanel()
		if mode == "panel" or mode == "banner" then
			setMode("none")
		elseif #events > 0 then
			openPanel(nil)
		end
	end
	closeButton.Activated:Connect(function()
		setMode("none")
	end)

	local squares: { [string]: TextButton } = {}
	local function square(id: string): TextButton
		local b = squares[id]
		if b then
			return b
		end
		local def = Events.Defs[id]
		b = new("TextButton", {
			Name = id,
			Size = UDim2.fromOffset(56, 56),
			BackgroundColor3 = Color3.fromRGB(10, 10, 14),
			BackgroundTransparency = 0.2,
			AutoButtonColor = true,
			Text = "",
			Parent = iconRow,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = b })
		new("UIStroke", {
			Thickness = 3,
			Color = Events.Colors[def and def.type or "info"] or Events.Colors.info,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = b,
		})
		new("TextLabel", {
			Name = "Glyph",
			Size = UDim2.fromScale(1, 0.62),
			BackgroundTransparency = 1,
			FontFace = BOLD,
			TextSize = 26,
			TextColor3 = TEXT,
			Text = def and def.icon or "!",
			Parent = b,
		})
		new("TextLabel", {
			Name = "Timer",
			Position = UDim2.fromScale(0, 0.58),
			Size = UDim2.fromScale(1, 0.36),
			BackgroundTransparency = 1,
			FontFace = BOLD,
			TextSize = 13,
			TextColor3 = TEXT,
			Text = "",
			Parent = b,
		})
		b.Activated:Connect(function()
			openPanel(id)
		end)
		squares[id] = b
		return b
	end

	-- Keys: G toggles the panel, F1-F7 start events in Studio (the server ignores them in a live game).
	local debugKeys: { [Enum.KeyCode]: string } = {}
	for id, def in Events.Defs do
		if def.debugKey then
			debugKeys[def.debugKey] = id
		end
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == C.TOGGLE_KEY then
			togglePanel()
		elseif debugKeys[input.KeyCode] and RunService:IsStudio() then
			debugRemote:FireServer(debugKeys[input.KeyCode])
		end
	end)

	-- Camera shake for the marsquake.
	RunService:BindToRenderStep("MB_QuakeShake", Enum.RenderPriority.Camera.Value + 1, function()
		if os.clock() < shakeUntil then
			local camera = workspace.CurrentCamera
			if camera then
				local a = 0.35
				camera.CFrame = camera.CFrame
					* CFrame.new(math.random() * a - a / 2, math.random() * a - a / 2, 0)
					* CFrame.Angles(0, 0, math.rad(math.random() * 1.2 - 0.6))
			end
		end
	end)

	-- Layout + per-frame update ------------------------------------------------------------------------
	local function topY(): number
		local y = 0
		local hud = playerGui:FindFirstChild("MB_HUD")
		local center = hud and hud:FindFirstChild("Center")
		if center and center:IsA("GuiObject") then
			y = center.AbsolutePosition.Y + center.AbsoluteSize.Y
		end
		local weather = playerGui:FindFirstChild("WeatherCard")
		local box = weather and weather:FindFirstChild("Box")
		if
			weather
			and weather:IsA("ScreenGui")
			and weather.Enabled
			and box
			and box:IsA("GuiObject")
			and box.Visible
		then
			y = math.max(y, box.AbsolutePosition.Y + box.AbsoluteSize.Y)
		end
		return y + 8
	end

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = gui.AbsoluteSize -- the safe area, in the same space as MB_HUD
		local s = math.clamp(camera.ViewportSize.Y / 480, 0.75, 1.4)
		cardScale.Scale = s
		iconScale.Scale = s
		closeScale.Scale = s

		if mode ~= "none" and os.clock() > modeUntil then
			setMode("none") -- the card folds into its square
		end
		if focus then
			-- Keep the focus entry fresh (phase / timer) from the latest list.
			local fresh = nil
			for _, e in events do
				if e.id == focus.id then
					fresh = e
				end
			end
			focus = fresh or pickFocus()
		else
			focus = pickFocus()
		end
		if not focus then
			setMode("none")
		end

		local y = math.max(topY(), viewport.Y * 0.27)
		local hud = playerGui:FindFirstChild("MB_HUD")
		if focus and (mode == "banner" or mode == "panel" or mode == "fact") then
			iconRow.Visible = false
			card.Visible = true
			-- Full card for a new event and when reopened; the short "done ✓" flash has no details.
			fill(focus :: Entry, focus.phase ~= "done")
			-- Never below 0.55 of the screen: move up if needed.
			local h = card.AbsoluteSize.Y
			card.Position = UDim2.fromOffset(viewport.X / 2, math.min(y, viewport.Y * MAX_Y - h))
			closeButton.Visible = true
			closeButton.Position = UDim2.fromOffset(
				card.AbsolutePosition.X + card.AbsoluteSize.X - gui.AbsolutePosition.X - 4,
				card.AbsolutePosition.Y - gui.AbsolutePosition.Y + 4
			)
			if hud then
				hud:SetAttribute("EventBottom", card.AbsolutePosition.Y + h + 8)
			end
		else
			card.Visible = false
			closeButton.Visible = false
			-- One square per event that is still running (warning or active).
			local shown = 0
			for _, b in squares do
				b.Visible = false
			end
			for i, e in events do
				if e.phase == "warning" or e.phase == "active" then
					local b = square(e.id)
					b.Visible = true
					b.LayoutOrder = i
					local timer = b:FindFirstChild("Timer") :: TextLabel
					timer.Text = if e.endsAt > 0 then mmss(e.endsAt - workspace:GetServerTimeNow()) else "tap"
					shown += 1
				end
			end
			iconRow.Visible = shown > 0
			iconRow.Position = UDim2.fromOffset(viewport.X / 2, y)
			if hud then
				hud:SetAttribute(
					"EventBottom",
					if shown > 0 then iconRow.AbsolutePosition.Y + iconRow.AbsoluteSize.Y + 8 else 0
				)
			end
		end
	end)
end

return EventUI
