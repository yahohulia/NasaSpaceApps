--!strict
-- The ice map on the science console. Source and quotes: kb/data/ice-map.md.
-- Image: NASA's treasure map for water ice on Mars (PIA23514), credit NASA/JPL-Caltech/ASU.
-- Player-facing text lives in i18n (keys "icemap.*"), read through Shared.Strings.
local IceMapConfig = {}

-- The image, re-uploaded by the place owner (Maria_Strawberi, 2026-11-15) so the place can load it directly.
-- The first upload (rbxassetid://122016476140910) belonged to another account and only its thumbnail loaded.
IceMapConfig.Image = "rbxassetid://85333712790591"
IceMapConfig.ImageSize = Vector2.new(1614, 720) -- size of the original file, in pixels
IceMapConfig.Credit = "NASA/JPL-Caltech/ASU"
IceMapConfig.ArchivedDate = "2019-12-10" -- date of the NASA article with this map

-- Zoom level 2 frames the white NASA outline around Arcadia Planitia (pixels of the original file,
-- same aspect as the whole image). The outline itself is part of the NASA image.
IceMapConfig.ArcadiaView = { cx = 886, cy = 179, width = 560 }
-- Game marker "we are here" inside the box (story, not a real landing site).
IceMapConfig.HerePixel = Vector2.new(900, 152)

-- Our game area as shown on zoom level 3 (world studs, square).
IceMapConfig.ZoneHalfSize = 560

-- Ice spots (parts tagged MB_Drill, by name) and the base's guess that ice is there.
-- Chance is a GAME VALUE, shown as "our guess, not NASA data". -- game value, TODO balance
IceMapConfig.Deposits = {
	{ site = "MB_DrillPoint", label = "A", chance = 85 },
	{ site = "IceSite_2", label = "B", chance = 60 },
	{ site = "IceSite_3", label = "C", chance = 35 },
}

-- Landmarks drawn on zoom level 3: world model name -> i18n key.
IceMapConfig.Landmarks = {
	{ model = "MarsBase", key = "icemap.base" },
	{ model = "LandingZone", key = "icemap.rocket" },
}

IceMapConfig.ConsoleTag = "IceMapConsole"
IceMapConfig.PromptDistance = 10

return IceMapConfig
