-- Run from the repository root with lune run tests/mission-plan.luau.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local plan = luau.load(fs.readFile("src/shared/MissionPlan.luau"))()

-- Five sols, in order, 2-3 objectives each (the board shows at most 3).
assert(#plan.sols == 5, "five sols")
for i, s in plan.sols do
	assert(s.sol == i, `sol {i} is in order`)
	assert(#s.objectives >= 2 and #s.objectives <= 3, `sol {i} has 2-3 objectives`)
end
-- Objectives lead to the ice drill step by step: samples and sorting (sol 1), the drill on sol 3.
local function ids(n)
	local t = {}
	for _, o in plan.sols[n].objectives do
		table.insert(t, o.id)
	end
	return table.concat(t, ",")
end
assert(ids(1) == "outside,samples,sort", ids(1))
assert(ids(2) == "panels,pump,plant", ids(2))
assert(ids(3) == "drill,ice,storm", ids(3))
assert(ids(4) == "radar,oxygen,harvest", ids(4))
assert(ids(5) == "earth,allSamples,launch", ids(5))
assert(plan.sols[3].objectives[3].kind == "keep", "the storm objective is judged at the end of the sol")
-- The crew lands with enough ice to drink until the drill works (a drink = 1 ice = +35 water).
assert(plan.START_ICE >= 2 and plan.START_ICE <= 5)

-- Failure only when base air is gone or the WHOLE crew has no water / no food.
assert(
	plan.failureReason(10, { { water = 0, food = 5 }, { water = 3, food = 5 } }) == nil,
	"one thirsty player is not a failure"
)
assert(plan.failureReason(10, { { water = 0, food = 5 }, { water = 0, food = 5 } }) == "water")
assert(plan.failureReason(0, { { water = 5, food = 5 } }) == "air")
assert(plan.failureReason(10, { { water = 5, food = 0 } }) == "food")
assert(plan.failureReason(0, { { water = 0, food = 0 } }) == "air", "air is checked first")
assert(plan.failureReason(10, {}) == nil, "no crew, no failure")

-- Event hours shift by up to one game hour and stay inside the day.
assert(plan.jitteredHour(9, 0.5) == 9)
assert(plan.jitteredHour(9, 0) == 8)
assert(plan.jitteredHour(23.4, 0.99) <= 23.5)
assert(plan.jitteredHour(0.2, 0) == 0.5)

print("mission-plan ok")
