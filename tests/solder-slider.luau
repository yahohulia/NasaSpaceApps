-- Run from the repository root with lune run tests/solder-slider.luau.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
-- SolderConfig holds the bench CFrame; lune has no CFrame, so give it a stand-in.
local cframe = {
	new = function()
		return {}
	end,
}
local config = luau.load(fs.readFile("src/shared/SolderConfig.luau"), { environment = { CFrame = cframe } })()
local source = fs.readFile("src/shared/SolderSlider.luau"):gsub("require%(script.Parent.SolderConfig%)", "...")
local slider = luau.load(source)(config)
local box = config.Slider.Box
local dt = 1 / 60

-- Runs one contact for up to `seconds` with a holding rule; returns the state.
local function play(joint, seed, seconds, rule)
	local state = slider.new(joint, seed)
	for _ = 1, math.floor(seconds / dt) do
		slider.step(state, dt, rule(state))
		if state.done then
			break
		end
	end
	return state
end

-- A careful player keeps the drop in the middle of the box: every contact finishes.
local shiny = 0
for joint = 1, 4 do
	for seed = 1, 20 do
		local state = play(joint, seed, 20, function(s)
			return s.box + box / 2 + s.speed * 0.3 < s.drop
		end)
		assert(state.done, `careful player must finish contact {joint} (seed {seed})`)
		assert(state.time < 8, `contact {joint} takes too long: {state.time}`)
		if slider.shiny(state) then
			shiny += 1
		end
	end
end
assert(shiny >= 60, `a careful player should mostly get shiny joints, got {shiny}/80`)

-- Doing nothing must not finish most contacts.
local idleDone = 0
for seed = 1, 20 do
	if play(1, seed, 8, function()
		return false
	end).done then
		idleDone += 1
	end
end
assert(idleDone < 10, `an idle player must not finish most contacts, got {idleDone}/20`)

-- Holding all the time pins the box to the top: it must not be a free win.
local pinnedDone = 0
for seed = 1, 20 do
	if play(1, seed, 8, function()
		return true
	end).done then
		pinnedDone += 1
	end
end
assert(pinnedDone < 10, `holding all the time must not finish most contacts, got {pinnedDone}/20`)

-- The box and the drop stay inside the bar.
local state = slider.new(1, 7)
for i = 1, 600 do
	slider.step(state, dt, i % 50 < 30)
	assert(state.box >= 0 and state.box <= 1 - box + 1e-9, "box left the bar")
	assert(state.drop >= 0 and state.drop <= 1, "drop left the bar")
end
print(`Solder slider checks passed (careful player: {shiny}/80 shiny, idle {idleDone}/20, pinned {pinnedDone}/20)`)
