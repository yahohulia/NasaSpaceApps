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
assert(plan.sols[2].objectives[2].id == "power" and plan.sols[2].objectives[2].kind == "keep")
assert(plan.sols[3].objectives[1].id == "storm" and plan.sols[3].objectives[1].kind == "keep")

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
