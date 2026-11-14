local CraftClient = require(script.CraftClient)
local IceMapClient = require(script.IceMapClient)
local SparkyClient = require(script.SparkyClient)
local WeatherClient = require(script.WeatherClient)

task.spawn(CraftClient.start)
task.spawn(IceMapClient.start)
task.spawn(SparkyClient.start)
task.spawn(WeatherClient.start)

print("[junior-astronaut] client started")
