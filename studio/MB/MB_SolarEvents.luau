-- MB_SolarEvents (ReplicatedStorage): real solar flares from NASA DONKI, used for the radiation storms.
-- Source: NASA / CCMC Space Weather Database Of Notifications, Knowledge, Information (DONKI),
-- API https://ccmc.gsfc.nasa.gov/DONKI-API/get/FLR?startDate=...&endDate=... (fetched 2026-11-15).
-- Fields copied as given (class, peak time UTC, active region, link). Nothing is made up or rounded.
-- These are ARCHIVED events: the game must say "Real event", never "live".
-- Copy of the script that lives in the team place (studio/MB in the repo).
local EVENTS = {
	{
		Class = "X9.0",
		Peak = "2024-10-03T12:18Z",
		Region = 13842,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/33693/-1",
	},
	{
		Class = "X8.7",
		Peak = "2024-05-14T16:51Z",
		Region = 13664,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/30849/-1",
	},
	{
		Class = "X7.1",
		Peak = "2024-10-01T22:20Z",
		Region = 13842,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/33656/-1",
	},
	{
		Class = "X5.8",
		Peak = "2024-05-11T01:23Z",
		Region = 13664,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/30711/-1",
	},
	{
		Class = "X4.5",
		Peak = "2024-05-06T06:35Z",
		Region = 13663,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/30484/-1",
	},
	{
		Class = "X3.9",
		Peak = "2024-05-10T06:54Z",
		Region = 13664,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/30666/-1",
	},
	{
		Class = "X3.4",
		Peak = "2024-05-15T08:37Z",
		Region = 13664,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/30879/-1",
	},
	{
		Class = "X3.3",
		Peak = "2024-10-24T03:57Z",
		Region = 13869,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/34148/-1",
	},
	{
		Class = "X2.8",
		Peak = "2024-05-27T07:08Z",
		Region = 13697,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/31158/-1",
	},
	{
		Class = "X2.3",
		Peak = "2024-11-06T13:40Z",
		Region = 13883,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/34449/-1",
	},
	{
		Class = "X2.2",
		Peak = "2024-05-09T09:13Z",
		Region = 13664,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/30605/-1",
	},
	{
		Class = "X2.0",
		Peak = "2024-10-31T21:20Z",
		Region = 13878,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/34344/-1",
	},
	{
		Class = "X1.8",
		Peak = "2024-10-09T01:56Z",
		Region = 13848,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/33863/-1",
	},
	{
		Class = "X1.6",
		Peak = "2024-05-03T02:22Z",
		Region = 13663,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/30403/-1",
	},
	{
		Class = "X1.5",
		Peak = "2024-06-10T11:08Z",
		Region = 13697,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/31397/-1",
	},
	{
		Class = "X1.1",
		Peak = "2024-05-09T17:44Z",
		Region = 13664,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/30634/-1",
	},
	{
		Class = "M6.7",
		Peak = "2026-10-08T15:48Z",
		Region = nil,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/49015/-1",
	},
	{
		Class = "M6.4",
		Peak = "2026-10-10T15:10Z",
		Region = nil,
		Link = "https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/49057/-1",
	},
}

local SolarEvents = {}

SolarEvents.Source = "NASA DONKI (CCMC)"
SolarEvents.Events = EVENTS

-- "Real event: X8.7 flare, 2024-05-14 (NASA DONKI)"
function SolarEvents.factLine(event): string
	return string.format("Real event: %s flare, %s (NASA DONKI)", event.Class, string.sub(event.Peak, 1, 10))
end

function SolarEvents.random(rng: Random?)
	local r = rng or Random.new()
	return EVENTS[r:NextInteger(1, #EVENTS)]
end

return SolarEvents
