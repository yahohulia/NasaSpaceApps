-- Crew roles (kb/decisions/2026-11-14-multiplayer-crew.md). Pure data + helpers.
-- A player's role is the Player attribute "Role" (one of Roles.ids), set by the server.

export type RoleId = "engineer" | "botanist" | "medic"

export type Role = {
	id: RoleId,
	color: Color3, -- card border and name tag
	icon: string, -- text glyph shown on cards and tags
}

local Roles = {}

Roles.ATTRIBUTE = "Role"

Roles.ids = table.freeze({ "engineer", "botanist", "medic" } :: { RoleId })

Roles.byId = table.freeze({
	engineer = table.freeze({ id = "engineer", color = Color3.fromRGB(240, 170, 60), icon = "⚡" }),
	botanist = table.freeze({ id = "botanist", color = Color3.fromRGB(110, 200, 110), icon = "🌱" }),
	medic = table.freeze({ id = "medic", color = Color3.fromRGB(110, 170, 240), icon = "✚" }),
} :: { [string]: Role })

function Roles.isValid(id: unknown): boolean
	return type(id) == "string" and Roles.byId[id] ~= nil
end

-- Role with the fewest players; ties go to the earlier role in Roles.ids.
-- `counts` maps role id -> number of players who already have it.
function Roles.leastFilled(counts: { [string]: number }): RoleId
	local best = Roles.ids[1]
	for _, id in Roles.ids do
		if (counts[id] or 0) < (counts[best] or 0) then
			best = id
		end
	end
	return best
end

return table.freeze(Roles)
