local Hud = require(script.Hud)
local SparkyClient = require(script.SparkyClient)

task.spawn(Hud.start)
task.spawn(SparkyClient.start)

print("[junior-astronaut] client started")
