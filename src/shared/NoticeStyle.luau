--!strict
-- One look for the text of every on-screen notice: the event card (EventUI), the weather card
-- (WeatherClient) and the toasts (NoticeClient, CraftClient, MB_HUD). Backgrounds and borders may
-- keep their own colours (they tell the kind of notice); the text is always the same.
local NoticeStyle = {}

NoticeStyle.Font = Font.fromEnum(Enum.Font.BuilderSans)
NoticeStyle.Bold = Font.new(NoticeStyle.Font.Family, Enum.FontWeight.Bold)
NoticeStyle.Heavy = Font.new(NoticeStyle.Font.Family, Enum.FontWeight.Heavy)

NoticeStyle.TextColor = Color3.fromRGB(245, 240, 235) -- the same as MB_HUD's text

NoticeStyle.TitleSize = 20 -- first line of a card
NoticeStyle.TextSize = 16 -- every other line of a card, and toasts
NoticeStyle.SmallSize = 13 -- only inside the small 56 px squares (timer, key hint)

return NoticeStyle
