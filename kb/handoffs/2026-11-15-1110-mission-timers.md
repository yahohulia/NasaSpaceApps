---
title: "Handoff: Mission timers 2026-11-15 11:10"
type: handoff
status: in-progress
branch: codex/fix-mission-timers
date: 2026-11-15
---

# Handoff: Mission timers 2026-11-15 11:10

Виправлення таймерів і неба готові в окремому worktree. Спільний плейс ще використовує попередні скрипти.

## Done

- Сонце та годинник HUD беруть час із `MB_BaseState.MissionStartedAt` і `SolSeconds`. Візуальний ефект холодної ночі більше не пересуває Сонце.
- Сервер публікує точні межі початку й кінця спалаху. HUD відраховує час за тими самими межами. Перезапуск місії скидає таймер оранжереї.
- Rojo build і StyLua для змінених файлів пройшли. Lune перевірив 28 800 кадрів, північ і межі спалаху при затриманих тіках. Повні перевірки мають старі зауваження в `IceMapClient` та `Crafting`.
- У поточному плейтесті був увімкнений старий `PlayerScripts.MB_HUD`, а `MissionStartedAt` був відсутній. При 480 секундах на сол серверний крок 0,5 секунди додає 1,5 ігрової хвилини, тому старий HUD чергує +1 та +2. У Lune перевірено, що HUD із покадровим часом показує кожну хвилину при 30, 60 і 144 FPS для звичайного та швидкого солу.

## Next

1. Узгодити заміну з власниками HUD і систем. Після `git pull` під'єднати актуальний Rojo та вимкнути попередні `ServerScriptService.MB_ResourceServer` і `StarterPlayer.StarterPlayerScripts.MB_HUD` у плейсі перед плейтестом. Rojo-версії знаходяться під `Server` і `Client`. Плейсові `MB_Config` та `MB_SolarEvents` потрібні обом версіям.
2. У Play Solo та Team Test перевірити світанок, перехід через північ, обидві фази спалаху та Play again. Перевірити, що `Lighting.DebugClockTime` відсутній, і що увімкнена одна копія кожного скрипта.

## Files touched

- `src/shared/MissionClock.luau`, `src/client/SkyClient.luau`, `src/shared/DataMapping.luau` — рівномірний рух Сонця.
- `src/server/MB_ResourceServer.server.luau`, `src/client/MB_HUD.client.luau` — версії з плейсу, перенесені в Rojo з виправленнями таймерів.

## Relations

- part_of [[Co-op campaign concept]]
- see_also [[Decision: Roblox asset conventions]]
