-- Run from the repository root with lune run tests/strings-lang.luau.
-- The whole game is in English for now (Ukrainian comes after the deadline), whatever the player's locale.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local source = fs.readFile("src/shared/Strings.luau")
	:gsub("require%(script%.Parent%.i18n%.uk%)", "{ greet = 'Привіт' }")
	:gsub("require%(script%.Parent%.i18n%.en%)", "{ greet = 'Hi' }")
local Strings = luau.load(source)()

assert(Strings.langFromLocale("uk-ua") == "en", "a Ukrainian locale still gets English")
assert(Strings.langFromLocale("en-us") == "en")
assert(Strings.get("greet", Strings.langFromLocale("uk-ua")) == "Hi")
print("strings-lang ok")
