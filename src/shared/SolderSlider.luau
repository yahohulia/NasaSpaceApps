--!strict
-- One solder joint as a catch-the-drop game, pure math (no Instances) so it can be tested with lune.
-- A vertical heat bar from 0 (bottom) to 1 (top). The player's box (the iron) rises while the
-- player holds and falls when they let go. A silver drop (the melting point) wanders up and down.
-- While the drop is inside the box the solder fills the contact; outside it drains a little.
-- The joint is done at fill = 1. Never losing the drop after the first catch gives a shiny joint.
local Config = require(script.Parent.SolderConfig)
local S = Config.Slider

local SolderSlider = {}

export type State = {
	box: number, -- bottom edge of the box, 0..1 - S.Box
	speed: number, -- box speed, bar heights per second (+ = up)
	drop: number, -- the drop's position, 0..1
	dropSpeed: number,
	goal: number, -- where the drop is heading
	goalTimer: number, -- seconds until it picks a new goal
	pace: number, -- how fast the drop moves (grows with each contact)
	fill: number, -- 0..1
	caught: boolean, -- the drop has been inside the box at least once
	slips: number, -- seconds the drop spent outside after the first catch
	inside: boolean,
	time: number,
	done: boolean,
	seed: number,
}

-- Small deterministic random numbers (lune has no Random), 0..1.
local function nextRandom(state: State): number
	state.seed = (state.seed * 1103515245 + 12345) % 2147483648
	return state.seed / 2147483648
end

function SolderSlider.new(joint: number, seed: number): State
	local state: State = {
		box = 0,
		speed = 0,
		drop = 0.35,
		dropSpeed = 0,
		goal = 0.35,
		goalTimer = S.GoalHold,
		pace = S.DropPace + (joint - 1) * S.DropPaceStep,
		fill = 0,
		caught = false,
		slips = 0,
		inside = false,
		time = 0,
		done = false,
		seed = math.max(1, math.floor(seed) % 2147483647),
	}
	return state
end

function SolderSlider.inside(state: State): boolean
	return state.drop >= state.box and state.drop <= state.box + S.Box
end

-- Shiny = after the first catch the drop was (almost) never lost.
function SolderSlider.shiny(state: State): boolean
	return state.slips <= S.PerfectSlip
end

function SolderSlider.step(state: State, dt: number, holding: boolean)
	if state.done then
		return
	end
	state.time += dt

	-- The box: lift while holding, gravity otherwise, a soft bounce on the floor.
	state.speed += (if holding then S.Lift else -S.Gravity) * dt
	state.speed -= state.speed * math.min(1, S.Drag * dt) -- air drag keeps it easy to steer
	state.speed = math.clamp(state.speed, -S.MaxSpeed, S.MaxSpeed)
	state.box += state.speed * dt
	local top = 1 - S.Box
	if state.box <= 0 then
		state.box = 0
		state.speed = if state.speed < 0 then -state.speed * S.Bounce else state.speed
	elseif state.box >= top then
		state.box = top
		state.speed = math.min(state.speed, 0)
	end

	-- The drop: picks a new goal now and then and glides towards it.
	state.goalTimer -= dt
	if state.goalTimer <= 0 then
		state.goal = S.GoalMin + nextRandom(state) * (S.GoalMax - S.GoalMin)
		state.goalTimer = S.GoalHold * (0.6 + nextRandom(state) * 0.8)
	end
	local want = math.clamp((state.goal - state.drop) * 3, -state.pace, state.pace)
	state.dropSpeed += (want - state.dropSpeed) * math.min(1, dt * 4)
	state.drop = math.clamp(state.drop + state.dropSpeed * dt, 0, 1)

	-- The solder: fills while the drop is in the box, drains a little outside.
	state.inside = SolderSlider.inside(state)
	if state.inside then
		state.caught = true
		state.fill = math.min(1, state.fill + S.FillRate * dt)
	else
		if state.caught then
			state.slips += dt
		end
		if state.time > S.Grace then
			state.fill = math.max(0, state.fill - S.DrainRate * dt)
		end
	end
	if state.fill >= 1 then
		state.done = true
	end
end

return SolderSlider
