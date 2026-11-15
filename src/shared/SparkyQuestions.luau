--!strict
-- Questions a player can ask Sparky (buttons in the dialog). Each one has a checked answer
-- in i18n (`answer`). The English answer is also the only fact the AI may use, so the AI
-- can reword it but not add new facts (AGENTS.md rule 6). Sources: see glossary / ice-map in kb/data.
export type Question = {
	id: string,
	question: string, -- i18n key of the button text
	answer: string, -- i18n key of the checked answer (also the AI's fact, and the fallback)
}

local list: { Question } = {
	{ id = "red", question = "sparky.q.red", answer = "sparky.line.2" },
	{ id = "sol", question = "sparky.q.sol", answer = "sparky.line.3" },
	{ id = "water", question = "sparky.q.water", answer = "sparky.line.8" },
	{ id = "dome", question = "sparky.q.dome", answer = "sparky.line.4" },
	{ id = "power", question = "sparky.q.power", answer = "sparky.line.5" },
	{ id = "airlock", question = "sparky.q.airlock", answer = "sparky.line.6" },
	{ id = "food", question = "sparky.q.food", answer = "sparky.line.7" },
}

local byId: { [string]: Question } = {}
for _, q in list do
	byId[q.id] = q
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
	greeting = "sparky.line.1",
})
