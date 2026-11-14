---
name: nasa-data
description: Rules and workflow for bringing real NASA open data (DONKI space weather, OSDR, Artemis/Mars mission data) into the game — fetching from Roblox server scripts (HttpService), caching snapshots, LIVE/ARCHIVED labelling, in-game attribution, and fact-checking numbers. Use whenever code or game balance uses a real-world value, an event from DONKI, or any NASA dataset/API.
---

# Using NASA data in the game

The challenge rewards real data and penalises fake "live" data. Every real-world number must be traceable.

## Workflow
0. **Start from the official list** in `kb/data/nasa-sources.md` (the challenge Resources tab: NASA Open APIs, DONKI, OSDR, RadLab, Mars Trek, CSA kits). Prefer those over other sources.
1. **Register the source first** in `kb/data/` (use the `kb` skill): what, URL, date checked, units, how we use it. Unverified values stay `[question]` and must not ship as facts.
2. **Snapshot first, live second.** Save a curated snapshot as `src/server/data/<source>.json` (Rojo turns a `.json` file into a ModuleScript that returns the table) with a header object: `{ source, url, retrievedAt, credit, notes }`. Fetch snapshots with a script (`lune` or `node --use-system-ca`), not by hand. The game must work fully from snapshots if HTTP fails.
3. **Optional live fetch** — only from server scripts with `HttpService:GetAsync` inside `pcall` (enable *Game Settings → Security → Allow HTTP Requests*; CORS does not apply on Roblox servers, so RadLab and OSDR can be fetched live too). DONKI via `https://ccmc.gsfc.nasa.gov/DONKI-API/get/<TYPE>?startDate=…&endDate=…` (no key, keep ranges ≤ 60 days; the old `api.nasa.gov/DONKI/FLR` path returns 404). Wrap in a timeout + fallback to the snapshot. Keys for other api.nasa.gov services go into Roblox Secrets (`HttpService:GetSecret`), never into the repo; DEMO_KEY runs out after ~10 calls — use a team key and cache.
4. **Label honestly in the UI:** `LIVE · <time>` only for data fetched this session; otherwise `ARCHIVED · <event date>`. Never fake liveness.
5. **Attribute in-game:** every event/fact card shows the dataset name and a link; the "Data sources" screen lists all snapshots from their headers (generate it from the snapshot headers, don't hand-write it).
6. **Translate to gameplay transparently:** keep the mapping (e.g. flare class → particle count, mSv/day → dose units) in one module `src/shared/DataMapping.luau` with comments citing the `kb/data/` note. Game-feel scaling is fine, but say so in the debrief ("у грі прискорено в N разів").
7. **Kid-friendly wording:** explain any term (sol, dose, SEP) in one short sentence where it first appears.

## Check before merging
- [ ] Source note exists in `kb/data/` with URL
- [ ] Snapshot has a header and is used as fallback when HTTP fails
- [ ] UI label is correct (LIVE vs ARCHIVED)
- [ ] Attribution visible in game
- [ ] No API key in the repo
