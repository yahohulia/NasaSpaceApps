--!strict
-- Base power balance (all game values, not NASA data). Base power is 0..100 (MB_BaseState@Power).
-- One sol = Config.SolSeconds (360 s), so one game hour = 15 real seconds; the sun shines 06:00-18:00.
-- Read by MB_ResourceServer (power) and BaseLights (dimming). Balance check: with clean panels the
-- battery ends the night at about 40 and the lights stay bright; after the sol-2 dust storm, dirty
-- panels can't keep up: the lights dim in the evening and go out at night until someone cleans them.
local PowerConfig = {}

PowerConfig.SolarPower = 1.4 -- game value, TODO balance: power/s from the sun with all panels clean
PowerConfig.BaseLoadPower = 0.1 -- game value, TODO balance: heaters and computers, always on
PowerConfig.DirtyPanelOutput = 0.05 -- game value, TODO balance: share of power a dusty panel still gives
PowerConfig.DustStormSun = 0.2 -- game value, TODO balance: share of sunlight that gets through a dust storm
PowerConfig.PanelTag = "MB_Panel" -- solar panels (Workspace.MB_SolarField), Dust 0..1 and Broken attributes

-- Lights dim when the battery runs low and go out at zero.
PowerConfig.DimFromPower = 35 -- game value: below this the lamps get dimmer
PowerConfig.DimMinBrightness = 0.25 -- game value: lamp brightness just before the power runs out

return PowerConfig
