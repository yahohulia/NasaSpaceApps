-- Pure builders that turn NASA data snapshots into weather event payloads.
-- No Instances here, so this can be tested headless with lune.
-- Sources: kb/data/nasa-sources.md (each builder names its snapshot).

export type Label = "ARCHIVED" | "LIVE"

export type Payload = {
	id: string, -- event kind, e.g. "dust"; also the i18n prefix weather.<id>.*
	label: Label,
	date: string, -- "YYYY-MM-DD" of the real event (ARCHIVED) or fetch time (LIVE)
	source: string, -- dataset name shown in the card
	credit: string,
	vars: { [string]: string | number }, -- placeholders for weather.<id>.fact
}

export type Header = { source: string, credit: string, url: string, retrievedAt: string }

export type RemsRow = {
	date: string,
	sol: number,
	minTemp: number?,
	maxTemp: number?,
	pressure: number?,
	uv: string,
}

local WeatherEvents = {}

-- 2018 global dust storm as seen by Curiosity REMS (snapshot rems-2018).
-- The storm is the first sol with UV "Low" after a run of "Very_High" days;
-- "before" is the last "Very_High" sol, so both values are real measurements.
function WeatherEvents.dustStorm(header: Header, rows: { RemsRow }): Payload?
	local before: RemsRow? = nil
	for _, row in rows do
		if row.uv == "Very_High" and row.maxTemp ~= nil then
			before = row
		elseif row.uv == "Low" and before ~= nil and row.maxTemp ~= nil then
			return {
				id = "dust",
				label = "ARCHIVED",
				date = row.date,
				source = header.source,
				credit = header.credit,
				vars = {
					uvBefore = before.uv,
					uvDuring = row.uv,
					tBefore = before.maxTemp :: number,
					tDuring = row.maxTemp :: number,
				},
			}
		end
	end
	return nil
end

-- Coldest night in the latest Curiosity REMS sols (snapshot rems-recent).
function WeatherEvents.coldNight(header: Header, rows: { RemsRow }): Payload?
	local coldest: RemsRow? = nil
	for _, row in rows do
		if row.minTemp ~= nil and row.maxTemp ~= nil then
			if coldest == nil or (row.minTemp :: number) < (coldest.minTemp :: number) then
				coldest = row
			end
		end
	end
	if coldest == nil then
		return nil
	end
	return {
		id = "cold",
		label = "ARCHIVED",
		date = coldest.date,
		source = header.source,
		credit = header.credit,
		vars = { sol = coldest.sol, tMin = coldest.minTemp :: number, tMax = coldest.maxTemp :: number },
	}
end

export type RadRow = { time: string, doseRate: number }

-- Solar radiation storm on the Mars surface (snapshot radlab-2024-05, Curiosity RAD).
-- The unit of doseRate is not confirmed yet, so only the unitless ratio
-- peak / median ("N times more than usual") goes into the game.
function WeatherEvents.radiationStorm(header: Header, rows: { RadRow }): Payload?
	if #rows == 0 then
		return nil
	end
	local rates = table.create(#rows)
	local peak = rows[1]
	for _, row in rows do
		table.insert(rates, row.doseRate)
		if row.doseRate > peak.doseRate then
			peak = row
		end
	end
	table.sort(rates)
	local median = rates[(#rates + 1) // 2]
	if median <= 0 then
		return nil
	end
	return {
		id = "radiation",
		label = "ARCHIVED",
		date = string.sub(peak.time, 1, 10),
		source = header.source,
		credit = header.credit,
		vars = { times = math.floor(peak.doseRate / median) },
	}
end

export type FlareRow = { peakTime: string, classType: string, link: string? }

export type EnlilRow = {
	simulationID: string,
	modelCompletionTime: string,
	cmeStartTime: string,
	speed: number,
	arrivalTime: string,
	link: string?,
}

-- Raw DONKI FLR records -> FlareRow (same shape as snapshot donki-flr).
function WeatherEvents.flareRows(raw: { any }): { FlareRow }
	local rows = {}
	for _, f in raw do
		if type(f.peakTime) == "string" and type(f.classType) == "string" then
			table.insert(rows, { peakTime = f.peakTime, classType = f.classType, link = f.link })
		end
	end
	return rows
end

-- Raw DONKI WSAEnlilSimulations -> runs with a Mars impact (same shape as snapshot donki-enlil-mars).
function WeatherEvents.enlilMarsRows(raw: { any }): { EnlilRow }
	local rows = {}
	for _, sim in raw do
		local cme = if type(sim.cmeInputs) == "table" then sim.cmeInputs[1] else nil
		local hit = nil
		for _, impact in (if type(sim.impactList) == "table" then sim.impactList else {}) do
			if impact.location == "Mars" then
				hit = impact
				break
			end
		end
		if cme and hit and type(cme.speed) == "number" then
			table.insert(rows, {
				simulationID = sim.simulationID,
				modelCompletionTime = sim.modelCompletionTime,
				cmeStartTime = cme.cmeStartTime,
				speed = cme.speed,
				arrivalTime = hit.arrivalTime,
				link = sim.link,
			})
		end
	end
	return rows
end

local FLARE_RANK = { A = 1, B = 2, C = 3, M = 4, X = 5 }

-- "M6.7" -> sortable strength; unknown classes sort last.
local function flareStrength(classType: string): number
	local letter, value = string.match(classType, "^(%a)([%d%.]+)")
	local rank = if letter then FLARE_RANK[string.upper(letter)] else nil
	if not rank then
		return -1
	end
	return rank * 1000 + (tonumber(value) or 0)
end

-- Strongest solar flare in the rows (DONKI FLR, live or snapshot donki-flr).
function WeatherEvents.solarFlare(header: Header, rows: { FlareRow }, label: Label): Payload?
	local best: FlareRow? = nil
	for _, row in rows do
		if best == nil or flareStrength(row.classType) > flareStrength(best.classType) then
			best = row
		end
	end
	if best == nil or flareStrength(best.classType) < 0 then
		return nil
	end
	return {
		id = "flare",
		label = label,
		date = string.sub(best.peakTime, 1, 10),
		source = header.source,
		credit = header.credit,
		vars = { class = best.classType },
	}
end

-- "2026-11-09T18:15Z" -> seconds (UTC-agnostic: only differences are used).
local function isoSeconds(iso: string): number?
	local y, mo, d, h, mi = string.match(iso, "^(%d+)-(%d+)-(%d+)T(%d+):(%d+)")
	if not y then
		return nil
	end
	return os.time({
		year = tonumber(y) :: number,
		month = tonumber(mo) :: number,
		day = tonumber(d) :: number,
		hour = tonumber(h) :: number,
		min = tonumber(mi) :: number,
		sec = 0,
	})
end

-- Latest WSA-ENLIL forecast of a CME reaching Mars (live or snapshot donki-enlil-mars).
-- This is a model forecast, and the text says so.
function WeatherEvents.cmeToMars(header: Header, rows: { EnlilRow }, label: Label): Payload?
	local latest: EnlilRow? = nil
	for _, row in rows do
		if latest == nil or row.modelCompletionTime > latest.modelCompletionTime then
			latest = row
		end
	end
	if latest == nil then
		return nil
	end
	local start, arrival = isoSeconds(latest.cmeStartTime), isoSeconds(latest.arrivalTime)
	if start == nil or arrival == nil or arrival <= start then
		return nil
	end
	return {
		id = "cme",
		label = label,
		date = string.sub(latest.arrivalTime, 1, 10),
		source = header.source,
		credit = header.credit,
		vars = {
			speed = math.floor(latest.speed + 0.5),
			days = math.floor((arrival - start) / 86400 + 0.5),
		},
	}
end

return WeatherEvents
