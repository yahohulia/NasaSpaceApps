local SparkyClient = require(script.SparkyClient)
local WeatherClient = require(script.WeatherClient)

task.spawn(SparkyClient.start)
task.spawn(WeatherClient.start)

print("[junior-astronaut] client started")
