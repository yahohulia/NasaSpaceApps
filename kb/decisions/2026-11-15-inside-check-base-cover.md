---
title: 'Decision: inside check falls back to base cover'
type: decision
status: current
date: 2026-11-15
permalink: sol-sandbox/decisions/2026-11-15-inside-check-base-cover
---

# Decision: inside check falls back to base cover

Баг: гравця, що бігає по базі без скафандра, у випадковий момент телепортувало в шлюз (кімната зі скафандрами).

## Observations
- [fact] Ланцюжок: `MB_ResourceServer` ставить `IsInside` (корінь гравця в одній із 127 зон `MB_InsideZone` у `Workspace.MB_HabitatZone` і під дахом) → `Radiation` копіює його в `Indoors` → `Suit` після 3 с з `Indoors == false` без скафандра переносить гравця на `Base.Habitat.Airlock.InsideSpot` (повідомлення `suit.rescued`).
- [fact] Зони не покривають кімнати повністю: смуга ~1,5 стада вздовж північної стіни центрального коридору (зона закінчується на z −121,5), край купола ферми (зона з x 102,4, підлога вже з x ≈ 100), смуги в кімнатах біля x 121–133. Перевірка сіткою 2026-11-15: 264 точки підлоги під мешем бази поза зонами. Хто біжить уздовж стіни, 3 с «надворі».
- [decision] У `src/server/MB_ResourceServer.server.luau` (`playersInside`): якщо гравець не в жодній зоні, але прямо над ним (до 40 стадів) є меш `Workspace.MarsBase`, він усередині. Розширювати зони не стали: щоб закрити прогалини, довелося б захопити й простір надворі.
- [fact] Перевірка в Edit: на дахах бази хибних «усередині» немає; 88 точок підлоги бази тепер усередині, ще 39 точок з рельєфом замість підлоги під мешем бази — теж усередині (це місця в будівлі).
- [todo] Перевірити в Play після синхронізації Rojo: бігти вздовж стіни коридору без скафандра — телепорту бути не повинно; доза надворі росте як і раніше.

## Relations
- relates_to [[Co-op campaign concept]]
