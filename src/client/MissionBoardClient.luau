--!strict
-- The mission board (top-left): the sol's title and 2-3 crew objectives with ☐ / ☑, the debrief card at
-- the end of each sol, and the calm "Mission stopped" screen with two choices.
-- Reads ReplicatedStorage.MissionState@Payload (JSON from Server.MissionDirector); answers through
-- RemoteEvent MissionChoice. Text through Shared.Strings; facts of sols 2-5 come from Shared.MB_Events.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local CraftConfig = require(ReplicatedStorage.Shared.CraftConfig)
local MB_Events = require(ReplicatedStorage.Shared.MB_Events) :: any
local MissionPlan = require(ReplicatedStorage.Shared.MissionPlan)
local Strings = require(ReplicatedStorage.Shared.Strings)

local DEBRIEF_SECONDS = 14 -- game value: how long the debrief card stays if not closed
local BG = Color3.fromRGB(16, 22, 28)
local TEXT = Color3.fromRGB(240, 244, 248)
local DIM = Color3.fromRGB(160, 175, 185)
local GOOD = Color3.fromRGB(110, 220, 140)
local ACCENT = Color3.fromRGB(255, 170, 70)
local FONT = Font.fromEnum(Enum.Font.BuilderSans)
local BOLD = Font.new(FONT.Family, Enum.FontWeight.Bold)

local MissionBoardClient = {}

type Payload = {
	sol: number,
	briefAt: number,
	done: { string },
	debrief: {
		sol: number,
		done: { string },
		missed: { string },
		emergencies: number,
		fact: string,
		factEvent: string?,
	}?,
	failed: string?,
	drill: { [string]: number }?, -- the ice drill's recipe progress; nil once it is built
}

local function corner(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

local function pad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft, p.PaddingRight = UDim.new(0, px), UDim.new(0, px)
	p.PaddingTop, p.PaddingBottom = UDim.new(0, px), UDim.new(0, px)
	p.Parent = parent
end

local function list(parent: Instance, gap: number)
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap)
	l.Parent = parent
end

local function label(parent: Instance, text: string, size: number, font: Font, color: Color3, order: number): TextLabel
	local t = Instance.new("TextLabel")
	t.LayoutOrder = order
	t.Size = UDim2.fromScale(1, 0)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.BackgroundTransparency = 1
	t.FontFace = font
	t.TextSize = size
	t.TextColor3 = color
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = text
	t.Parent = parent
	return t
end

local function button(parent: Instance, text: string, color: Color3, order: number): TextButton
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.Size = UDim2.new(1, 0, 0, 40)
	b.BackgroundColor3 = color
	b.FontFace = BOLD
	b.TextSize = 18
	b.TextColor3 = BG
	b.Text = text
	b.AutoButtonColor = true
	corner(b, 8)
	b.Parent = parent
	return b
end

local function card(gui: ScreenGui, name: string, width: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.45)
	f.Size = UDim2.fromOffset(width, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundColor3 = BG
	f.BackgroundTransparency = 0.05
	f.Visible = false
	corner(f, 12)
	pad(f, 18)
	list(f, 10)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(width, math.huge)
	limit.Parent = f
	f.Parent = gui
	return f
end

local function clear(frame: Instance)
	for _, c in frame:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- The real fact of a sol: the MB_Events fact when the sol names an event, else its own i18n line.
local function factText(fact: string, factEvent: string?, lang: Strings.Lang): string
	local def = factEvent and MB_Events.Defs[factEvent]
	if def and typeof(def.fact) == "string" then
		return def.fact
	end
	return Strings.get(fact, lang)
end

function MissionBoardClient.start()
	local me = Players.LocalPlayer
	local lang = Strings.langFromLocale(me.LocaleId)
	local state = ReplicatedStorage:WaitForChild("MissionState", 60)
	local choice = ReplicatedStorage:WaitForChild("MissionChoice", 60)
	if not (state and choice and choice:IsA("RemoteEvent")) then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "MissionBoard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.IgnoreGuiInset = false

	-- Board: top-left corner, small, never more than 3 lines.
	local board = Instance.new("Frame")
	board.Name = "Board"
	board.Position = UDim2.fromOffset(16, 16)
	board.Size = UDim2.fromOffset(290, 0)
	board.AutomaticSize = Enum.AutomaticSize.Y
	board.BackgroundColor3 = BG
	board.BackgroundTransparency = 0.25
	board.Visible = false
	corner(board, 10)
	pad(board, 12)
	list(board, 6)
	board.Parent = gui

	local debriefCard = card(gui, "Debrief", 420)
	local failCard = card(gui, "Failed", 420)
	-- Dim the game behind the failure card.
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.Visible = false
	dim.ZIndex = 0
	dim.Parent = gui
	gui.Parent = me:WaitForChild("PlayerGui")

	local payload: Payload? = nil
	local shownDebrief = 0 -- sol of the last debrief shown
	local debriefToken = 0

	-- Free the cursor while one of our cards is open, and give back what it was before, only when
	-- our cards open or close (other windows - Sparky, crops, soldering - manage it themselves).
	local cardsOpen = false
	local cursorBefore = UserInputService.MouseIconEnabled
	local function cursor()
		local open = debriefCard.Visible or failCard.Visible
		if open == cardsOpen then
			return
		end
		cardsOpen = open
		if open then
			cursorBefore = UserInputService.MouseIconEnabled
			UserInputService.MouseIconEnabled = true
		else
			UserInputService.MouseIconEnabled = cursorBefore
		end
	end

	-- The board steps aside while the sorting mini game is open (it would cover the left box).
	local function sorting(): boolean
		local g = me.PlayerGui:FindFirstChild("SortGame")
		return g ~= nil and g:IsA("ScreenGui") and g.Enabled
	end

	local function drawBoard()
		local p = payload
		local s = p and MissionPlan.sols[p.sol]
		board.Visible = s ~= nil and not sorting()
		if not (p and s) then
			return
		end
		clear(board)
		label(
			board,
			Strings.get("mission.board.sol", lang, { n = s.sol }) .. " · " .. Strings.get(s.title, lang),
			18,
			BOLD,
			TEXT,
			1
		)
		local wait = p.briefAt - workspace:GetServerTimeNow()
		if wait > 0 then
			-- Mission Control's message is still on its way (real Mars-Earth light time).
			local minutes = math.max(1, math.ceil(wait * 24 * 60 / Config.SolSeconds))
			label(board, Strings.get("mission.board.incoming", lang, { min = minutes }), 15, FONT, DIM, 2)
			return
		end
		label(board, Strings.get(s.brief, lang), 15, FONT, DIM, 2)
		local doneSet = {}
		for _, id in p.done do
			doneSet[id] = true
		end
		for i, o in s.objectives do
			local ok = doneSet[o.id] == true
			label(
				board,
				(if ok then "☑ " else "☐ ") .. Strings.get(o.text, lang),
				16,
				FONT,
				if ok then GOOD else TEXT,
				2 + i
			)
		end
		-- The main goal of sols 1-3: what the ice drill still needs (CraftConfig.Recipe).
		local d = p.drill
		if d and s.sol <= 3 then
			local r = CraftConfig.Recipe
			label(
				board,
				Strings.get("mission.goal.drill", lang, {
					iron = d.Iron or 0,
					needIron = r.Iron,
					nickel = d.Nickel or 0,
					needNickel = r.Nickel,
					manganese = d.Manganese or 0,
					needManganese = r.Manganese,
					parts = d.Parts or 0,
					needParts = r.Parts,
				}),
				14,
				FONT,
				ACCENT,
				10
			)
		end
	end

	local function showDebrief()
		local p = payload
		local d = p and p.debrief
		if not d or d.sol == shownDebrief or (p and p.failed) then
			return -- nothing new, or wait until the "Mission stopped" card is gone
		end
		shownDebrief = d.sol
		clear(debriefCard)
		label(debriefCard, Strings.get("mission.debrief.title", lang, { n = d.sol }), 22, BOLD, ACCENT, 1)
		local order = 2
		for _, id in d.done do
			label(debriefCard, "☑ " .. Strings.get("mission.obj." .. id, lang), 16, FONT, GOOD, order)
			order += 1
		end
		for _, id in d.missed do
			label(debriefCard, "☐ " .. Strings.get("mission.obj." .. id, lang), 16, FONT, DIM, order)
			order += 1
		end
		if d.emergencies > 0 then
			label(
				debriefCard,
				Strings.get("mission.debrief.emergency", lang, { n = d.emergencies }),
				15,
				FONT,
				ACCENT,
				order
			)
			order += 1
		end
		label(debriefCard, factText(d.fact, d.factEvent, lang), 15, FONT, TEXT, order)
		local close = button(debriefCard, Strings.get("mission.debrief.close", lang), GOOD, order + 1)
		close.Modal = true -- unlocks the first-person mouse so the button can be clicked
		debriefCard.Visible = true
		cursor()
		debriefToken += 1
		local my = debriefToken
		local function hide()
			if debriefToken == my then
				debriefCard.Visible = false
				cursor()
			end
		end
		close.Activated:Connect(hide)
		task.delay(DEBRIEF_SECONDS, hide)
	end

	local function drawFailure()
		local p = payload
		local reason = p and p.failed
		failCard.Visible = reason ~= nil
		dim.Visible = reason ~= nil
		if reason then
			debriefCard.Visible = false -- one card at a time
		end
		cursor()
		if not reason then
			return
		end
		clear(failCard)
		label(failCard, Strings.get("mission.failed.title", lang), 24, BOLD, ACCENT, 1)
		label(failCard, Strings.get("mission.failed." .. reason, lang), 17, FONT, TEXT, 2)
		local supplies =
			button(failCard, Strings.get("mission.failed.supplies", lang, { h = MissionPlan.EMERGENCY_HOURS }), GOOD, 3)
		local restart = button(failCard, Strings.get("mission.failed.restart", lang), DIM, 4)
		supplies.Modal = true -- unlocks the first-person mouse so the buttons can be clicked
		restart.Modal = true
		supplies.Activated:Connect(function()
			(choice :: RemoteEvent):FireServer("supplies")
		end)
		restart.Activated:Connect(function()
			(choice :: RemoteEvent):FireServer("restart")
		end)
	end

	local function read()
		local raw = state:GetAttribute("Payload")
		if typeof(raw) ~= "string" or raw == "" then
			return
		end
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok then
			return
		end
		local p = decoded :: Payload
		if not payload and p.debrief then
			shownDebrief = p.debrief.sol -- joined mid-mission: don't pop up an old debrief
		elseif payload and p.sol < payload.sol then
			shownDebrief = 0 -- a new mission: debriefs start over
		end
		payload = p
		drawBoard()
		showDebrief()
		drawFailure()
	end

	state:GetAttributeChangedSignal("Payload"):Connect(read)
	read()
	-- Redraw once a second while the briefing is on its way (countdown) and when it arrives.
	task.spawn(function()
		while gui.Parent do
			task.wait(1)
			local p = payload
			if (p and p.briefAt - workspace:GetServerTimeNow() > -1.5) or board.Visible == sorting() then
				drawBoard()
			end
		end
	end)
end

return MissionBoardClient
