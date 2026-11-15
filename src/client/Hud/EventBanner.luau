--!strict
-- Top-right banner during a space-weather event: sun icon, event name, countdown. Data: Remotes.EventChanged.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local PixelIcon = require(script.Parent.PixelIcon)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local KNOWN_KINDS = { FLR = true, SEP = true, CME = true }

local EventBanner = {}

local function formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function EventBanner.new(parent: Instance, lang: Strings.Lang): (Remotes.EventState) -> ()
	local panel = Widgets.panel("Event", Theme.Event)
	panel.Visible = false
	Widgets.row(panel, 10)

	local icon = PixelIcon.new("Sun", 2, Theme.Event)
	icon.frame.LayoutOrder = 1
	icon.frame.Parent = panel

	local name = Widgets.label("Title", Theme.Text)
	name.LayoutOrder = 2
	name.Parent = panel

	local timer = Widgets.label("Timer", Theme.Event)
	timer.LayoutOrder = 3
	timer.Parent = panel

	panel.Parent = parent

	local endsAt: number? = nil
	RunService.Heartbeat:Connect(function()
		if endsAt then
			timer.Text = formatTime(endsAt - workspace:GetServerTimeNow())
		end
	end)

	return function(state: Remotes.EventState)
		if not state.active then
			panel.Visible = false
			endsAt = nil
			return
		end
		local kind = state.kind
		local key = if kind and KNOWN_KINDS[kind] then `hud.event.{kind}` else "hud.event.unknown"
		name.Text = Strings.get(key, lang)
		endsAt = state.endsAt
		timer.Visible = endsAt ~= nil
		panel.Visible = true
	end
end

return EventBanner
