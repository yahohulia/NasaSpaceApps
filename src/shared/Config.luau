--!strict
return table.freeze({
	SolSeconds = 360, -- game value: six real minutes per sol
	-- game value: one-way Mars -> Earth signal time in game minutes. Real range is about
	-- 4-24 min (NASA, kb/data/comm-delay.md); 20 is our pick inside it. TODO balance
	CommDelayMinutes = 20,
})
