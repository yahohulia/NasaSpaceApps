-- Single entry point for player-facing text (see kid-copy skill).
local uk = require(script.Parent.i18n.uk)
local en = require(script.Parent.i18n.en)

export type Lang = "uk" | "en"

local Strings = {}

-- The whole game is in English for now (AGENTS.md: English first, Ukrainian after the deadline).
-- Set to nil to pick the language from the player's locale again (i18n/uk.luau is kept up to date).
Strings.FORCED_LANG = "en" :: Lang?

-- Picks the language from a Roblox locale id such as "uk-ua" or "en-us".
function Strings.langFromLocale(localeId: string): Lang
	if Strings.FORCED_LANG then
		return Strings.FORCED_LANG
	end
	if string.sub(string.lower(localeId), 1, 2) == "uk" then
		return "uk"
	end
	return "en"
end

-- Returns the text for a key, falling back to English, then to the key itself.
function Strings.get(key: string, lang: Lang, vars: { [string]: string | number }?): string
	local tbl = if lang == "uk" then uk else en
	local text = tbl[key] or en[key] or key
	if vars then
		text = string.gsub(text, "{(%w+)}", function(name)
			local value = vars[name]
			return if value ~= nil then tostring(value) else nil
		end)
	end
	return text
end

return Strings
