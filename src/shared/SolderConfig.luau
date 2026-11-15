--!strict
-- Soldering station and water pump breakdowns. All numbers are game values, TODO balance.
return table.freeze({
	-- Where the 3D soldering station stands if the place has no Workspace.MB_Interactables.MB_SolderStation
	-- anchor part (World can drop one there in Studio to move it). Power room, middle, facing the door.
	StationCFrame = CFrame.new(37, 2.3, -93),
	Distance = 10, -- studs from the bench or the pump to use them
	Timeout = 180, -- seconds a soldering session may stay open

	-- One joint: heat is 0..1, fill is 0..1.
	HeatRate = 0.25, -- heat per second while the iron touches the contact
	CoolRate = 0.5, -- heat lost per second without the iron
	MeltHeat = 0.45, -- solder starts to melt at this heat
	Overheat = 1, -- too hot: the joint must cool and be done again
	SafeHeat = 0.15, -- cool enough to try again / joint set
	FlowSeconds = 1.1, -- seconds of melting to fill a joint
	PerfectWindow = 0.5, -- release within this many seconds after "Let go!" for a shiny joint
	HoldLease = 0.8, -- the client must repeat "hold" this often, or the iron lifts
	UpdateSeconds = 0.1,

	-- Boards that can be fixed at the station.
	Boards = table.freeze({
		WaterPump = table.freeze({ joints = 4 }),
	}),

	-- Water pump: breaks at a random moment while it runs.
	PumpBreakMin = 150, -- seconds of work before it may break
	PumpBreakMax = 330,
})
