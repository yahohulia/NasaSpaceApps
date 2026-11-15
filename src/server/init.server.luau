local Airlock = require(script.Airlock)
local DevHudFeed = require(script.DevHudFeed)
local Sparky = require(script.Sparky)

Airlock.start()
Sparky.start()
DevHudFeed.start()

print("[junior-astronaut] server started")
