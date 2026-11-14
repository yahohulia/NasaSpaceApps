---
name: design-handoff
description: Bring the designer's work into the code consistently — material palette, sprites, icons, UI tokens, fonts — with fixed formats, folders and names. Use when the user or designer shares new/updated colors, sprites, icons, mockups or a style guide, when code needs a color/asset, or when you're about to hardcode a color or image path.
---

# Design → code handoff

One source of truth for every color and asset, so agents never invent their own.

## Where things live
```
assets/
  palette.json        # material colors (single source of truth)
  ui-tokens.json      # UI colors, fonts, spacing, radii
  sprites/<name>.png  # pixel sprites, 1× scale, transparent background
  sprites/<name>.json # frame data if animated: { "frameW":4, "frameH":8, "frames":{ "walk":[0,1,2,3] } }
  icons/<name>.svg    # HUD/resource icons, viewBox-based, no hardcoded fill (use currentColor)
  fonts/              # only if self-hosted; licence file next to each font
design/               # designer's source files and exported mockups (PNG/PDF), not loaded by the game
```

## Formats
`assets/palette.json` — one entry per material id used in the engine:
```json
{
  "regolith": { "base": "#948C82", "noise": ["#8A8278", "#9C948A", "#A39B90"], "glow": null },
  "water":    { "base": "#2C7FD4", "noise": ["#2A78CC", "#3389DE"], "glow": null }
}
```
- `base` = main color, `noise` = 2–4 variants for per-pixel texture, `glow` = optional color for emissive materials (e.g. radiation particles).
- Night lighting is done by the engine (multiplying brightness), not by separate night colors — unless the designer explicitly provides them.

`assets/ui-tokens.json` — `{ "color": {...}, "font": {...}, "space": {...}, "radius": {...} }`; the UI imports tokens from here, never literal hex values.

## Naming
- kebab-case English: `astronaut-walk.png`, `icon-oxygen.svg`, `solar-panel`.
- Material ids in `palette.json` must match the engine's material ids exactly.
- Icons for the core resources are fixed names: `icon-energy`, `icon-oxygen`, `icon-radiation`, `icon-supplies`, `icon-time`, `icon-science`.

## Rules
- Never hardcode colors or asset paths in game/UI code — import from the palette/tokens.
- Readability first: each material must be distinguishable at 1–3 pixels and for color-blind players. When changing the palette, check the deuteranopia/protanopia views (designer has a Figma plugin) and contrast between neighbours that touch often (regolith/rock, water/ice, O₂/vacuum).
- No NASA logo ("meatball"/"worm"). NASA photos are allowed with credit in the Data Sources screen.
- When the designer sends something that doesn't fit these formats, convert it and tell them what was changed, instead of silently diverging.
- Record any design decision others depend on (style direction, palette version, sprite size) as a note in `kb/decisions/` (see `kb` skill).

## Checklist when importing new assets
- [ ] Files in the right folder with the right names
- [ ] Material ids match the engine
- [ ] Sprites at 1× scale, transparent background
- [ ] Icons use `currentColor`
- [ ] Game runs and the change is visible (screenshot via Playwright)
