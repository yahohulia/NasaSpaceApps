--!strict

local MissionClock = {}

function MissionClock.sample(
	now: number,
	startedAt: number,
	solSeconds: number,
	startHour: number,
	startSol: number
): (number, number)
	local hours = startHour + 24 * math.max(0, now - startedAt) / solSeconds
	return hours % 24, startSol + math.floor(hours / 24)
end

return MissionClock
