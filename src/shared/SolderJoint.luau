--!strict
-- One solder joint, pure math (no Instances) so it can be tested with lune.
-- Phases: cold -> heat -> flow -> release (filled, let go!) -> cool -> solid.
-- Letting go too early or holding too long gives "retry": wait to cool, then do it again.
local Config = require(script.Parent.SolderConfig)
local SolderJoint = {}
export type State = {
	heat: number,
	fill: number,
	holding: boolean,
	phase: string,
	late: number, -- seconds the iron stayed on after the joint was filled
	perfect: boolean, -- let go in time: a shiny joint
	reason: string?, -- why the last try failed: "early" | "hot"
}
function SolderJoint.new(): State
	return { heat = 0, fill = 0, holding = false, phase = "cold", late = 0, perfect = false, reason = nil }
end
function SolderJoint.step(state: State, dt: number)
	if state.phase == "solid" then
		return
	end
	if state.phase == "retry" then
		state.holding = false
		state.heat = math.max(0, state.heat - Config.CoolRate * dt)
		if state.heat <= Config.SafeHeat then
			state.phase = "cold"
		end
		return
	end
	if state.holding then
		local before = state.heat
		state.heat = math.min(1, before + Config.HeatRate * dt)
		if state.heat >= Config.Overheat then
			state.phase, state.fill, state.holding, state.late, state.reason = "retry", 0, false, 0, "hot"
			return
		end
		local warmTime = math.max(0, dt - math.max(0, Config.MeltHeat - before) / Config.HeatRate)
		if state.fill >= 1 then
			state.late += dt
		end
		state.fill = math.min(1, state.fill + warmTime / Config.FlowSeconds)
		state.phase = if state.fill >= 1 then "release" elseif state.heat >= Config.MeltHeat then "flow" else "heat"
	else
		state.heat = math.max(0, state.heat - Config.CoolRate * dt)
		if state.fill >= 1 then
			if state.phase == "release" then
				state.perfect = state.late <= Config.PerfectWindow
			end
			state.phase = if state.heat <= Config.SafeHeat then "solid" else "cool"
		elseif state.fill > 0 then
			state.fill, state.late, state.reason = 0, 0, "early"
			state.phase = "retry"
		else
			state.phase = "cold"
		end
	end
end
return SolderJoint
