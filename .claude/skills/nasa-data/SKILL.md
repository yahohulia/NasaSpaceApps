---
name: nasa-data
description: Rules and workflow for bringing real NASA open data (DONKI space weather, OSDR, Artemis/Mars mission data) into the game — fetching, caching as JSON, LIVE/ARCHIVED labelling, in-game attribution, and fact-checking numbers. Use whenever code or game balance uses a real-world value, an event from DONKI, or any NASA dataset/API.
---

# Using NASA data in the game

The challenge rewards real data and penalises fake "live" data. Every real-world number must be traceable.

## Workflow
0. **Start from the official list** in `kb/data/nasa-sources.md` (the challenge Resources tab: NASA Open APIs, DONKI, OSDR, RadLab, Mars Trek, CSA kits). Prefer those over other sources.
1. **Register the source first** in `kb/data/` (use the `kb` skill): what, URL, date checked, units, how we use it. Unverified values stay `[question]` and must not ship as facts.
2. **Fetch at build time, not only at runtime.** Save a curated snapshot to `src/data/<source>/*.json` with a header object: `{ source, url, retrievedAt, license/credit, notes }`. The game must work fully offline from snapshots.
3. **Optional live fetch**: DONKI via `https://ccmc.gsfc.nasa.gov/DONKI-API/get/<TYPE>?startDate=…&endDate=…` (no key, CORS `*`, keep ranges ≤ 60 days; the old `api.nasa.gov/DONKI/FLR` path returns 404). Wrap in a timeout + fallback to the snapshot. Keys for other api.nasa.gov services come from env/config, never committed; DEMO_KEY runs out after ~10 calls — use a team key and cache.
4. **Label honestly in the UI:** `LIVE · <time>` only for data fetched this session; otherwise `ARCHIVED · <event date>`. Never fake liveness.
5. **Attribute in-game:** every event/fact card shows the dataset name and a link; the "Data sources" screen lists all snapshots from their headers (generate it from the JSON headers, don't hand-write it).
6. **Translate to gameplay transparently:** keep the mapping (e.g. flare class → particle count, mSv/day → dose units) in one file `src/data/mapping.ts` with comments citing the `kb/data/` note. Game-feel scaling is fine, but say so in the debrief ("у грі прискорено в N разів").
7. **Kid-friendly wording:** explain any term (sol, dose, SEP) in one short sentence where it first appears.

## Check before merging
- [ ] Source note exists in `kb/data/` with URL
- [ ] Snapshot JSON has header and is used as fallback
- [ ] UI label is correct (LIVE vs ARCHIVED)
- [ ] Attribution visible in game
- [ ] No API key in the repo
