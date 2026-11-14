-- Live NASA DONKI fetches (server only). Every call is wrapped in pcall and returns
-- nil on any failure, so callers fall back to the snapshots in src/server/data.
-- API notes and checks: kb/data/nasa-sources.md (keep ranges <= 60 days).
local HttpService = game:GetService("HttpService")

local BASE = "https://ccmc.gsfc.nasa.gov/DONKI-API/get/"

local Donki = {}

Donki.header = table.freeze({ source = "NASA DONKI", credit = "NASA CCMC", url = BASE, retrievedAt = "" })

local function day(secondsAgo: number): string
	return os.date("!%Y-%m-%d", os.time() - secondsAgo) :: string
end

-- Returns the decoded JSON array for an endpoint over the last `days` days, or nil.
function Donki.get(endpoint: string, days: number): { any }?
	local url = `{BASE}{endpoint}?startDate={day(days * 86400)}&endDate={day(0)}`
	local ok, result = pcall(function()
		return HttpService:JSONDecode(HttpService:GetAsync(url))
	end)
	if not ok then
		warn(`[donki] {endpoint} failed, using snapshot: {result}`)
		return nil
	end
	if type(result) ~= "table" then
		return nil
	end
	print(`[donki] {endpoint}: {#result} records (live)`)
	return result
end

return Donki
