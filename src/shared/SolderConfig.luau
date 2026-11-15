--!strict
-- Soldering station and water pump breakdowns. All numbers are game values, TODO balance.
return table.freeze({
	-- Where the 3D soldering station stands if the place has no Workspace.MB_Interactables.MB_SolderStation
	-- anchor part (World can drop one there in Studio to move it). Power room, middle, facing the door.
	StationCFrame = CFrame.new(37, 2.3, -93),
	Distance = 10, -- studs from the bench or the pump to use them
	Timeout = 180, -- seconds a soldering session may stay open
	UpdateSeconds = 0.1,

	-- One joint = catch the drop (SolderSlider). Positions are in bar heights (0 = bottom, 1 = top).
	Slider = table.freeze({
		Box = 0.26, -- height of the player's box (the iron); kids get a big one
		Lift = 3.0, -- upward push per second while holding
		Gravity = 1.6, -- pull down per second when not holding
		Drag = 2.2, -- slows the box down, so it does not fly past the drop
		MaxSpeed = 1, -- fastest the box moves
		Bounce = 0.35, -- how much the box bounces off the floor
		DropPace = 0.28, -- fastest the drop moves on the first contact
		DropPaceStep = 0.06, -- each next contact makes the drop a bit faster
		GoalMin = 0.08, -- the drop wanders between these heights
		GoalMax = 0.92,
		GoalHold = 1.2, -- about this many seconds before the drop picks a new place
		FillRate = 0.34, -- solder per second while the drop is in the box (about 3 s per contact)
		DrainRate = 0.12, -- solder lost per second while it is outside
		Grace = 1, -- seconds at the start before solder can drain
		PerfectSlip = 0.35, -- seconds you may lose the drop and still get a shiny joint
	}),
	-- The server accepts a finished contact only after this many seconds (a full fill takes ~3 s).
	MinJointSeconds = 2,

	-- Boards that can be fixed at the station.
	Boards = table.freeze({
		WaterPump = table.freeze({ joints = 4 }),
	}),

	-- Water pump: breaks at a random moment while it runs.
	PumpBreakMin = 150, -- seconds of work before it may break
	PumpBreakMax = 330,
})
