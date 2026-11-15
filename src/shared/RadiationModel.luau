-- Personal radiation dose (pure, no Instances). Dose is stored in microgray (μGy),
-- the unit of Curiosity RAD / RadLab absorbed_dose_rate (kb/data/nasa-sources.md).
-- Real inputs: the Mars surface background rate and the storm ratio from the
-- radlab snapshot. Game-feel inputs (time speed-up, mission limit) live in DataMapping.

export type Level = "ok" | "rising" | "high" | "limit"

local RadiationModel = {}

-- Median of absorbed_dose_rate rows = the usual (quiet) Mars surface rate, μGy/h.
function RadiationModel.medianRate(rows: { { doseRate: number } }): number
	local rates = table.create(#rows)
	for _, row in rows do
		table.insert(rates, row.doseRate)
	end
	table.sort(rates)
	return rates[(#rates + 1) // 2] or 0
end

-- μGy gained in `seconds` of game time. `ratio` = 1 normally, storm peak/median in a storm.
-- `speedUp` = Mars seconds per game second (game feel).
function RadiationModel.gain(baseRatePerHour: number, ratio: number, speedUp: number, seconds: number): number
	return baseRatePerHour * ratio * speedUp * seconds / 3600
end

-- Same dose expressed as days of the usual Mars background ("as much as N days on Mars").
function RadiationModel.marsDays(dose: number, baseRatePerHour: number): number
	if baseRatePerHour <= 0 then
		return 0
	end
	return dose / (baseRatePerHour * 24)
end

-- Warning level by share of the mission limit.
function RadiationModel.level(dose: number, limit: number): Level
	local share = if limit > 0 then dose / limit else 1
	if share >= 1 then
		return "limit"
	elseif share >= 0.8 then
		return "high"
	elseif share >= 0.5 then
		return "rising"
	end
	return "ok"
end

return table.freeze(RadiationModel)
