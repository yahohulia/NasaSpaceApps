---
title: "Handoff: MB events UI, sleep, ice map 2026-11-15 18:35"
type: handoff
status: in-progress
branch: events/single-director (Rojo) + worktree-hud (studio/MB, kb)
date: 2026-11-15
---

# Handoff: MB events UI, sleep, ice map 2026-11-15 18:35

Одна система подій працює в place (Rojo подає `events/single-director`). Зроблено UI подій (квадратики + T), сповіщення без накладання, сон у ліжках, блакитна крапля води, карта льоду NASA на екрані. Усе в place (останнє збереження — версія 210) і в git (обидві гілки запушені). `events/single-director` ще не злита в `main`.

## Done
- **Події (EventUI, WeatherClient, MB_Events):** нова подія чи погода → повна картка 5 с → квадратик у стовпчику; T (`MB_Events.Config.TOGGLE_KEY`) показує картки по черзі (погода → події → згорнути); на екрані завжди одна повна картка. Квадратики однакового розміру, сталий порядок, рівномірно зменшуються в межах верхньої половини, на крихітному екрані — друга колонка. Значок «T» ліворуч від верхнього квадратика.
- **Чужий скрипт `MB_HudEventIcons`** переносить стовпчик праворуч під радар; EventUI не чіпає позицію, якщо AnchorPoint ≠ (0,0).
- **Без накладань (MB_HUD у Rojo):** повідомлення HUD (`Toast`) стає під карткою події (атрибут `EventBottom`) і ніколи не опускається на командне `Toast` (NoticeClient, низ екрана); картки подій і погоди зменшуються до 60 %, якщо не влазять. Перевірено вимірюванням прямокутників у вікні 1220×442 — перетинів 0.
- **Сон:** кнопка «Sleep · Bed» на 4 ліжках (`Workspace.MB_SleepSpots`, теги `MB_SleepSpot` + `MB_Bed`; ліжка знайдено raycast-ами в меші кімнати). Гравець лягає на спину головою до подушки, сон завжди `SleepSeconds = 10` (MB_Config), прокидається сам повністю відпочилим («Good morning!»), або раніше — пробіл / «Wake up» / кнопка ще раз. Екран сну — Studio-скрипт `MB_SleepClient` (затемнення + картка «N s more to sleep» зі смужкою; поступається іншим карткам).
- **Фіолетова смужка** тепер показує відпочинок (100 − Fatigue): повна після сну, червона коли дуже втомлений.
- **Вода:** значок — крапля з відблиском, колір (80, 190, 255) для значка й смужки.
- **Repair panel:** зламана марсотрясінням панель світиться червоним (Highlight), кнопка ремонту на деталі `Back` нових моделей; поки панель зламана, командна кнопка `MB_CleanPrompt` (MB_PanelCleaning) вимкнена. Код — Studio-скрипт `MB_Missions` (копія в `studio/MB`).
- **Карта льоду:** PIA23514 перезавантажила власниця гри → `rbxassetid://85333712790591` (модерація пройдена). `IceMapConfig.Image` + `Workspace.IceMapScreen` + підпис «Image: NASA/JPL-Caltech/ASU · ARCHIVED · 2019-12-10». Нотатка: [[NASA ice map]] (kb/data/ice-map.md).

## Next
1. Злити `events/single-director` у `main` (PR). Поки не злито, правильну версію дає лише Rojo з цієї гілки; кожне подання `main` повертає старий HUD/сервер ресурсів (так уже було з MB_HUD сьогодні).
2. Перевірити вручну: E біля каменя «Pick up» не відкриває погоду (тепер погода на T, тож має бути ок), F7 з клавіатури (через емулятор не доходив).
3. Вирішити з командою про зразки: `MB_Samples` перенесено в `ServerStorage.MB_SamplesBackup`, MB_Missions бачить 0 зразків; Ярослав тепер рахує камені з `Workspace.Samples` у MissionDirector (коміт fb78f67).
4. Мітка ферми `FarmRackMarker` («Crops · N m») біля правого краю може заходити на квадратики подій — скрипт команди, не мій.
5. Кнопки українською в грі («Вийти назовні», «Увійти в базу», «Оглянути ракету») — порушують правило «тексти англійською»; у кнопки «Suit» порожній ObjectText.

## Files touched
- `src/client/EventUI.luau`, `src/client/WeatherClient.luau`, `src/shared/MB_Events.luau` — квадратики, T, одна картка.
- `src/client/MB_HUD.client.luau` — Toast без накладань, крапля води, смужка відпочинку, повідомлення сну.
- `src/server/MB_ResourceServer.server.luau` — сон у ліжках.
- `src/shared/IceMapConfig.luau` — новий ID карти.
- `studio/MB/MB_SleepClient.client.luau` (новий), `MB_Missions.server.luau`, `MB_Config.luau`, `MB_Events.luau`, `MB_HUD.client.luau` (Studio-копія, вимкнена в place) — копії Studio-скриптів.
- `kb/data/ice-map.md` — рядок про новий ассет.

## Observations
- [risk] У place працюють Rojo-версії `Server.MB_ResourceServer` і `Client.MB_HUD`; Studio-копії `MB_ResourceServer` і `MB_HUD` вимкнені (Disabled). Правити треба Rojo-файли.
- [risk] Хтось змінює Rojo-файли прямо в Studio (у `Client.MB_HUD` було +9 байтів не з git). При поданні з диска такі правки зникають.
- [decision] Числа сну (`SleepSeconds = 10`) і нахилу картки (мін. 60 %) — ігрові значення, не NASA.
- [question] `Config.Actions.Rest.Fatigue` більше не використовується (сон рахує швидкість сам).

## Relations
- follows [[Handoff: MB events 2026-11-15 13:56]]
- see_also [[NASA ice map]]
- part_of [[Game concept]]
