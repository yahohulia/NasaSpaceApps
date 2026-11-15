-- MB_SoundConfig (ReplicatedStorage): all game sounds in one place. Put "rbxassetid://<id>" or leave "".
-- An empty id means that sound is simply silent (no errors). Read by MB_Music and MB_Footsteps.
-- Copy of the script that lives in the team place (studio/MB in the repo).
return {
	Volume = 0.3, -- background music
	FadeSeconds = 3, -- cross-fade at 6:00 (day) and 18:00 (night), and into / out of a storm

	Day = "rbxassetid://130094065357950", -- "monume - retro arcade game music 2" (Pixabay)
	Night = "rbxassetid://129043173046268", -- "Night Sky Travel", Static Glow Sounds (Epidemic Sound)
	Storm = "", -- music during a solar storm (empty: day/night music keeps playing)
	Wind = "", -- Mars wind outside the base, loops quietly (empty: silent)
	WindVolume = 0.25,

	StepsBase = "rbxassetid://101444322623946", -- walking inside the base ("звук по железу")
	StepsSand = "rbxassetid://130948620356531", -- walking on sand outside ("ходьба по песку")
}
