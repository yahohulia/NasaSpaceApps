---
title: 'Decision: HUD contract'
type: decision
status: proposed
date: 2026-11-14
permalink: sol-sandbox/decisions/2026-11-14-hud-contract
---

# Decision: HUD contract

Що HUD (`src/client/Hud/`) очікує від сервера та від світу. Макет — скріншот команди від 2026-11-14: Сол і 3 ресурси зліва вгорі, подія справа вгорі, роль і доза зліва внизу, підказка дії по центру внизу, маркери на об'єктах.

## Observations
- [decision] Спільні ресурси приходять тільки з сервера: RemoteEvent `ReplicatedStorage.Remotes.ResourcesChanged` з даними `{ sol: number, resources = { Oxygen|Water|Food = { amount, capacity } } }`. Його надсилають усім при зміні і кожному гравцю при вході. Типи лежать у `src/shared/Remotes.luau`.
- [decision] Космічна погода: RemoteEvent `Remotes.EventChanged` з даними `{ active, kind = "FLR"|"SEP"|"CME", endsAt }`. `endsAt` рахується за `workspace:GetServerTimeNow()`. Таймер HUD рахує сам.
- [decision] Особисте береться з атрибутів Player, які ставить сервер: `Role` (рядок `Engineer`/`Botanist`/`Driller`) і `RadiationDose` (число від 0 до `Config.Dose.Limit`, ігрові одиниці). Імена атрибутів лежать у `Config.PlayerAttributes`.
- [decision] Маркери: Part або Model з тегом `HudMarker`, атрибути `Label` (ключ Strings, напр. `hud.marker.pump`) і `Kind` (`alert` для поломки, інакше `objective`). Відстань у метрах = студи × 0,28 (`Config.Hud.MetersPerStud`, домовленість Roblox, не дані NASA).
- [decision] Підказки дій — звичайні ProximityPrompt. HUD локально перемикає їх на `Style = Custom` і малює сам. На сенсорному екрані підказка натискається пальцем. Текст `ActionText` локалізує власник машини, як у Спаркі.
- [decision] Шрифт Press Start 2P (вбудований у Roblox). Іконки намальовано пікселями з Frame, без завантажених зображень.
- [decision] `src/server/DevHudFeed.luau` подає вигадані дані лише в Studio (`Config.DevHudFeed`). Коли з'являться ResourceSystem і StormEvent, поставити `false` або видалити файл.
- [question] Банер події поки не показує дату й джерело DONKI. За правилом атрибуції їх має показувати FactPopup, коли подія починається.

## Relations
- implements [[Game concept]]
- see_also [[NASA data sources]]
- part_of [[Index]]
