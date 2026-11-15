--!strict
-- HUD colours, font and sizes (from the team mock-up, 2026-11-14).
local Theme = {
	Font = Font.new("rbxasset://fonts/families/PressStart2P.json"),
	TextSize = 10,
	SmallTextSize = 8,

	Panel = Color3.fromRGB(18, 18, 22),
	PanelTransparency = 0.12,
	Border = Color3.fromRGB(58, 58, 66),
	Text = Color3.fromRGB(235, 235, 240),
	MutedText = Color3.fromRGB(150, 150, 160),
	EmptyCell = Color3.fromRGB(44, 44, 52),

	Oxygen = Color3.fromRGB(160, 182, 255),
	Water = Color3.fromRGB(80, 190, 235),
	Food = Color3.fromRGB(140, 205, 60),
	Warning = Color3.fromRGB(228, 112, 80),
	Dose = Color3.fromRGB(165, 112, 215),

	Event = Color3.fromRGB(222, 150, 60),
	Card = Color3.fromRGB(176, 210, 72),
	Key = Color3.fromRGB(176, 210, 72),
	KeyText = Color3.fromRGB(20, 22, 16),
	Alert = Color3.fromRGB(200, 82, 50),
	Objective = Color3.fromRGB(235, 190, 60),

	RoleColors = {
		Engineer = Color3.fromRGB(196, 104, 52),
		Botanist = Color3.fromRGB(96, 160, 60),
		Driller = Color3.fromRGB(80, 120, 200),
	} :: { [string]: Color3 },

	Margin = 14, -- distance from the screen edge
	ReferenceHeight = 680, -- screen height the mock-up was drawn at; UIScale follows it
}

return Theme
