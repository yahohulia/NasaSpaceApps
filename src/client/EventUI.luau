-- EventUI (client): shows the events from EventDirector (RemoteEvent MB_EventState).
--   New event -> the full card for BANNER_TIME s -> it folds into a small square (icon + timer).
--   The squares sit in a column on the left side of the screen (the weather square from WeatherClient
--   joins the same column) and stay until the event is over. Tap a square -> its full card.
--   T (MB_Events.Config.TOGGLE_KEY) reads the cards one by one: weather first, then each event; after the
--   last one T folds everything. Only one full card is on screen at a time, so they never overlap.
--   WeatherClient follows T through the LocalPlayer attributes MB_EventsOpen / MB_EventsToggleId.
--   The card fits between the HUD top and the messages below it (MB_HUD.Toast, the team's Toast near the
--   bottom): when there is not enough room it shrinks (down to 60 %) instead of covering them.
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

	-- Squares: a column on the left side, one per running event (icon + timer). Tap = its full card. -------
	-- WeatherClient puts its weather square into this same column (LayoutOrder 0, on top).
	local SIDE_X, SIDE_TOP = 16, 0.16 -- px from the left edge; share of the screen height (upper half only)
	-- One straight column, all squares the same size. If it would go below the upper half, every square shrinks
	-- by the same amount (set every frame), but not below MIN_SQUARE_SCALE; on a very small screen the rest wraps
	-- into a second column of the same size. Order: weather on top, then the events in the order they started.
	local MIN_SQUARE_SCALE = 0.6 -- the smallest the squares get (56 px * 0.6), so the timer stays readable
	local iconRow = new("Frame", {
		Name = "Icons",
		AnchorPoint = Vector2.new(0, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Wraps = true,
		Parent = iconRow,
	})
	local iconScale = new("UIScale", { Parent = iconRow })
	-- Key hint (T): a small badge beside the first square, outside the column so the rows of squares stay even
	-- (computers only; on a phone the squares are tapped).
	local zHint = new("TextLabel", {
		Name = "ZHint",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(26, 22),
		BackgroundColor3 = Color3.fromRGB(10, 10, 14),
		BackgroundTransparency = 0.2,
		FontFace = HEAVY,
		TextSize = 14,
		TextColor3 = TEXT,
		Text = C.TOGGLE_KEY.Name,
		Visible = false,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = zHint })
	local zHintScale = new("UIScale", { Parent = zHint })

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

	-- Z: open the full text of everything (event card + weather card), or fold everything if anything is open.
	local function weatherOpen(): boolean
		local w = playerGui:FindFirstChild("WeatherCard")
		local box = w and w:FindFirstChild("Box")
		return w ~= nil and w:IsA("ScreenGui") and w.Enabled and box ~= nil and box:IsA("GuiObject") and box.Visible
	end
	-- WeatherClient listens to MB_EventsToggleId and opens / folds the weather card.
	local function setWeatherOpen(open: boolean)
		player:SetAttribute("MB_EventsOpen", open)
		player:SetAttribute("MB_EventsToggleId", (player:GetAttribute("MB_EventsToggleId") or 0) + 1)
	end
	-- Z: show the next card (weather first, then the running events in order); after the last, fold all.
	local function togglePanel()
		local items: { string } = {}
		local w = playerGui:FindFirstChild("WeatherCard")
		if w and w:IsA("ScreenGui") and w.Enabled then
			table.insert(items, "weather")
		end
		for _, e in events do
			if e.phase == "warning" or e.phase == "active" then
				table.insert(items, e.id)
			end
		end
		local current = if weatherOpen()
			then "weather"
			elseif (mode == "panel" or mode == "banner") and focus then focus.id
			else nil
		local nextItem = items[1]
		if current then
			nextItem = nil
			for i, item in items do
				if item == current then
					nextItem = items[i + 1]
				end
			end
		end
		if nextItem == "weather" then
			setMode("none")
			setWeatherOpen(true)
		elseif nextItem then
			if weatherOpen() then
				setWeatherOpen(false)
			end
			openPanel(nextItem)
		else
			setMode("none")
			if weatherOpen() then
				setWeatherOpen(false)
			end
		end
	end
	closeButton.Activated:Connect(function()
		setMode("none")
	end)

	local squares: { [string]: TextButton } = {}
	-- Fixed order of the squares: the server's list order can change, the order an event started does not.
	local orderOf: { [string]: number } = {}
	local orderCounter = 0
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
			-- Tap the square of the open card = fold it; any other square = open that one.
			if mode == "panel" and focus and focus.id == id then
				setMode("none")
			else
				openPanel(id)
			end
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
		-- The open weather card (WeatherClient) sits there too: event cards go below it.
		-- (Its folded square lives in the side column, so it does not count here.)
		local weather = playerGui:FindFirstChild("WeatherCard")
		if weather and weather:IsA("ScreenGui") and weather.Enabled then
			for _, g in weather:GetChildren() do
				if g:IsA("GuiObject") and g.Visible and (g.Name == "Box" or g.Name == "Square") then
					y = math.max(y, g.AbsolutePosition.Y + g.AbsoluteSize.Y)
				end
			end
		end
		return y + 8
	end

	local wasCardOpen, wasWeatherOpen = false, false
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = gui.AbsoluteSize -- the safe area, in the same space as MB_HUD
		local s = math.clamp(camera.ViewportSize.Y / 480, 0.75, 1.4)
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

		local hud = playerGui:FindFirstChild("MB_HUD")
		-- Side column: one square per event that is still running (warning or active), always shown.
		local shown = 0
		for _, b in squares do
			b.Visible = false
		end
		local running: { [string]: boolean } = {}
		for _, e in events do
			if e.phase == "warning" or e.phase == "active" then
				running[e.id] = true
				if not orderOf[e.id] then
					orderCounter += 1
					orderOf[e.id] = orderCounter
				end
				local b = square(e.id)
				b.Visible = true
				b.LayoutOrder = orderOf[e.id] -- the weather square is 0, the key hint -1
				local timer = b:FindFirstChild("Timer") :: TextLabel
				timer.Text = if e.endsAt > 0 then mmss(e.endsAt - workspace:GetServerTimeNow()) else "tap"
				shown += 1
			end
		end
		local weatherSquare = iconRow:FindFirstChild("WeatherSquare")
		local anySquare = shown > 0 or (weatherSquare ~= nil and (weatherSquare :: GuiObject).Visible)
		for id in orderOf do
			if not running[id] then
				orderOf[id] = nil
			end
		end
		zHint.Visible = anySquare and UserInputService.KeyboardEnabled
		-- Same size for every square; shrink them all evenly when the column would reach below the upper half.
		local need, count = 0, 0
		for _, c in iconRow:GetChildren() do
			if c:IsA("GuiObject") and c.Visible then
				need += c.Size.Y.Offset
				count += 1
			end
		end
		need += math.max(count - 1, 0) * 8 -- UIListLayout padding
		local room = viewport.Y * MAX_Y - (iconRow.AbsolutePosition.Y - gui.AbsolutePosition.Y)
		local scale = math.clamp(room / math.max(need, 1), MIN_SQUARE_SCALE, s * 0.8)
		iconScale.Scale = scale
		iconRow.Size = UDim2.fromOffset(0, room / scale) -- taller than this wraps into a second column
		-- The key badge sits just left of the column's top square.
		zHintScale.Scale = scale
		zHint.Position = UDim2.fromOffset(
			iconRow.AbsolutePosition.X - gui.AbsolutePosition.X - 6,
			iconRow.AbsolutePosition.Y - gui.AbsolutePosition.Y
		)
		-- Another script may own the column's place (MB_HudEventIcons moves it under the radar and sets its
		-- AnchorPoint to (1, 0)); then leave Position alone, or the two scripts fight and the column jitters.
		if iconRow.AnchorPoint == Vector2.zero then
			iconRow.Position = UDim2.fromOffset(SIDE_X, viewport.Y * SIDE_TOP)
		end

		-- One full card at a time. The one the player opened last wins; an event card always beats a weather
		-- card that popped up by itself (WeatherCard@Mode "full"); if both appear together, the event wins.
		local cardOpen = focus ~= nil and (mode == "banner" or mode == "panel" or mode == "fact")
		local wOpen = weatherOpen()
		if cardOpen and wOpen then
			local weatherCard = playerGui:FindFirstChild("WeatherCard")
			local weatherAuto = weatherCard ~= nil and weatherCard:GetAttribute("Mode") == "full"
			if not wasCardOpen or weatherAuto then
				setWeatherOpen(false)
				wOpen = false
			elseif not wasWeatherOpen then
				setMode("none")
				cardOpen = false
			end
		end
		wasCardOpen, wasWeatherOpen = cardOpen, wOpen

		if cardOpen and focus then
			card.Visible = true
			-- Full card for a new event and when reopened; the short "done ✓" flash has no details.
			fill(focus :: Entry, focus.phase ~= "done")
			-- Never below 0.55 of the screen: move up if needed.
			-- Room for the card (gui space): from the HUD top down to the upper-half limit, above the team's
			-- message near the bottom (NoticeClient "Toast") and leaving room for MB_HUD's own message.
			local base = gui.AbsolutePosition.Y
			local top = math.max(topY() - base, viewport.Y * 0.27)
			local bottom = viewport.Y * MAX_Y
			local notice = playerGui:FindFirstChild("Toast")
			local noticeBox = notice and notice:FindFirstChild("Box")
			if
				notice
				and notice:IsA("ScreenGui")
				and notice.Enabled
				and noticeBox
				and noticeBox:IsA("GuiObject")
				and noticeBox.Visible
			then
				bottom = math.min(bottom, noticeBox.AbsolutePosition.Y - base - 8)
			end
			local hudToast = hud and hud:FindFirstChild("Toast")
			if hudToast and hudToast:IsA("GuiObject") and hudToast.Visible then
				bottom -= hudToast.AbsoluteSize.Y + 8
			end
			-- Shrink the card (down to 60 % of normal) when it does not fit.
			local natural = card.AbsoluteSize.Y / cardScale.Scale
			cardScale.Scale = math.clamp((bottom - top) / math.max(natural, 1), 0.6, 1) * s
			local h = natural * cardScale.Scale
			card.Position = UDim2.fromOffset(viewport.X / 2, math.max(math.min(top, bottom - h), 0))
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
			if hud then
				-- Messages go below the open weather card, if any (the squares are on the side now).
				hud:SetAttribute("EventBottom", topY())
			end
		end
	end)
end

return EventUI
