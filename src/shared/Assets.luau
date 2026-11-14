-- Single registry of Roblox asset ids used from code.
-- Rules: kb/decisions/2026-11-14-roblox-asset-conventions.md
-- Never write raw "rbxassetid://" strings in other scripts; add an entry here.

export type Asset = {
	id: string, -- "rbxassetid://<number>"
	kind: "Image" | "Sound" | "Mesh" | "Animation" | "Video",
	credit: string, -- shown on the in-game credits screen
	source: string, -- URL or "uploaded by <owner>"
}

local Assets: { [string]: Asset } = {
	-- Example:
	-- MarsSurface = {
	-- 	id = "rbxassetid://0",
	-- 	kind = "Image",
	-- 	credit = "NASA/JPL-Caltech",
	-- 	source = "https://...",
	-- },
}

return table.freeze(Assets)
