--!strict
-- Real Mars -> Earth signal delay for today from NASA JPL Horizons (server only).
-- One live request at server start (HttpService, pcall). On any failure the snapshot
-- src/server/data/horizons-mars-lt.json (one row per day) is used and labelled ARCHIVED,
-- and if today is not in it, Config.CommDelayMinutes. Source note: kb/data/comm-delay.md.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local snapshot = require(script.Parent.data["horizons-mars-lt"]) :: any

export type Delay = {
	minutes: number, -- one-way light time, real minutes
	date: string, -- YYYY-MM-DD the value is for
	live: boolean, -- fetched this session
	source: string,
}

local SOURCE = "NASA JPL Horizons"
local MONTHS = {
	Jan = "01",
	Feb = "02",
	Mar = "03",
	Apr = "04",
	May = "05",
	Jun = "06",
	Jul = "07",
	Aug = "08",
	Sep = "09",
	Oct = "10",
	Nov = "11",
	Dec = "12",
}

local Horizons = {}

local current: Delay

local function today(): string
	return os.date("!%Y-%m-%d") :: string
end

local function query(start: string, stop: string): string
	local function q(v: string): string
		return HttpService:UrlEncode("'" .. v .. "'")
	end
	return "https://ssd.jpl.nasa.gov/api/horizons.api?format=json"
		.. "&COMMAND="
		.. q("499")
		.. "&OBJ_DATA="
		.. q("NO")
		.. "&MAKE_EPHEM="
		.. q("YES")
		.. "&EPHEM_TYPE="
		.. q("OBSERVER")
		.. "&CENTER="
		.. q("500@399")
		.. "&START_TIME="
		.. q(start)
		.. "&STOP_TIME="
		.. q(stop)
		.. "&STEP_SIZE="
		.. q("1 d")
		.. "&QUANTITIES="
		.. q("20,21")
end

-- Snapshot row for the date, or the closest earlier one; nil if the date is outside it.
local function fromSnapshot(date: string): Delay?
	local best = nil
	for _, row in snapshot.rows do
		if row.date <= date then
			best = row
		end
	end
	local last = snapshot.rows[#snapshot.rows]
	if not best or (last and date > last.date) then
		return nil
	end
	return { minutes = best.lightMinutes, date = best.date, live = false, source = SOURCE }
end

-- First ephemeris row: "2026-Nov-15 00:00     1.31585436923142 -14.7502717    10.94362708".
local function parse(result: string): (string?, number?)
	local body = string.match(result, "%$%$SOE(.-)%$%$EOE")
	if not body then
		return nil, nil
	end
	local y, mon, d, lt =
		string.match(body, "(%d%d%d%d)%-(%a%a%a)%-(%d%d)%s+%d%d:%d%d%s+[%d%.]+%s+[%-%d%.]+%s+([%d%.]+)")
	local month = mon and MONTHS[mon]
	local minutes = tonumber(lt)
	if not (y and month and d and minutes) then
		return nil, nil
	end
	return `{y}-{month}-{d}`, minutes
end

function Horizons.start()
	local date = today()
	current = fromSnapshot(date)
		or { minutes = Config.CommDelayMinutes, date = date, live = false, source = "Config (game value)" }
	task.spawn(function()
		local tomorrow = os.date("!%Y-%m-%d", os.time() + 86400) :: string
		local ok, result = pcall(function()
			return HttpService:JSONDecode(HttpService:GetAsync(query(date, tomorrow)))
		end)
		if not ok or type(result) ~= "table" or type(result.result) ~= "string" then
			warn(`[horizons] live request failed, using snapshot: {result}`)
			return
		end
		local day, minutes = parse(result.result)
		if not (day and minutes and minutes > 0 and minutes < 30) then
			warn("[horizons] could not read the light time, using snapshot")
			return
		end
		current = { minutes = minutes, date = day, live = true, source = SOURCE }
		print(string.format("[horizons] Mars -> Earth signal: %.2f min (live, %s)", minutes, day))
	end)
end

-- Today's one-way delay (live when the request worked).
function Horizons.get(): Delay
	return current
end

return Horizons
