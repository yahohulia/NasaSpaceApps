-- Run from the repository root with lune run tests/solder-joint.luau.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local config = luau.load(fs.readFile("src/shared/SolderConfig.luau"))()
local source = fs.readFile("src/shared/SolderJoint.luau"):gsub("require%(script.Parent.SolderConfig%)", "...")
local joint = luau.load(source)(config)
local function advance(state, seconds)
	for _ = 1, math.floor(seconds / 0.01 + 0.5) do
		joint.step(state, 0.01)
	end
end
local state = joint.new()
state.holding = true
advance(state, 1.5)
assert(state.fill == 0, "Cold contacts must not melt solder")
state.holding = false
advance(state, 2)
assert(state.heat == 0 and state.phase == "cold")
state.holding = true
advance(state, 2.3)
assert(state.fill > 0 and state.fill < 1)
state.holding = false
advance(state, 2)
assert(state.fill == 0 and state.phase == "cold" and state.reason == "early", "Partial joints must need rework")
state.holding = true
advance(state, 3)
assert(state.fill == 1 and state.phase == "release")
state.holding = false
advance(state, 2)
assert(state.phase == "solid" and state.perfect, "A quick release sets a shiny joint")
state.holding = true
advance(state, 3)
assert(state.phase == "solid")
state = joint.new()
state.holding = true
advance(state, 3.8)
assert(state.phase == "release")
state.holding = false
advance(state, 2)
assert(state.phase == "solid" and not state.perfect, "A late release still sets, without the shine")
state = joint.new()
state.holding = true
advance(state, 4.3)
assert(state.phase == "retry" and state.fill == 0 and not state.holding and state.reason == "hot")
advance(state, 3)
assert(state.phase == "cold")
print("Solder joint regression checks passed")
