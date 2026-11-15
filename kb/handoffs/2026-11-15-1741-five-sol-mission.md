---
title: 'Handoff: Five-sol mission 2026-11-15 17:41'
type: handoff
status: in-progress
branch: events/single-director
date: 2026-11-15
permalink: sol-sandbox/handoffs/2026-11-15-1741-five-sol-mission
---

# Handoff: Five-sol mission 2026-11-15 17:41

Активності гри зведено в одну місію на 5 солів: кожен сол — один урок (реальне обмеження), 2–3 спільні завдання, брифінг від Землі з реальною затримкою, підсумок сола і м'який провал. Дизайн: `docs/superpowers/specs/2026-11-15-five-sol-mission-design.md`, план: `docs/superpowers/plans/2026-11-15-five-sol-mission.md`. Робоча гілка `mission/five-sols` (worktree `D:\nasa-mission`) влита в `events/single-director`.
The game's activities now form one 5-sol mission (one real constraint per sol, crew objectives, Earth briefing with the real light delay, debrief, soft failure).

## Done
- [decision] Уроки: 1 лід → вода → їжа; 2 енергія від Сонця і пилу; 3 радіація і далека Земля; 4 техніка ламається; 5 вікно запуску (Yaroslav).
- [decision] Провал лише коли на базі нема повітря або весь екіпаж без води / їжі. Вибір: «Земля надсилає запас» (мінус `MissionPlan.EMERGENCY_HOURS` = 4 ігрові години) або «Почати спочатку» (Yaroslav).
- [decision] Світло кімнат коштує енергії: `LightsConfig.PowerPerLitRoom = 0.01`/с на кімнату (`MB_BaseState@LitRooms`), TODO balance.
- [decision] Час подій щоразу зсувається до ±1 год (`MissionPlan.jitteredHour`); поломки лишаються на своїх солах.
- Код: `Shared.MissionPlan` (+ тест `tests/mission-plan.luau`), `Server.MissionDirector`, `Client.MissionBoardClient`, хуки `MB_ObjectiveDone` у Crops / WaterPump / Sparky, `WaterPump.breakNow()`, команда `emergencySupplies` у MB_ResourceServer, джиттер у EventDirector, рядки `mission.*` en + uk.
- Перевірено в Play: табло з текстом, відмітка завдання, перехід сола + підсумок, відлік брифінгу «22 хв» (Horizons), картка провалу, кнопка запасу. Фінальний огляд гілки (opus): 5 ризикових сценаріїв проходять; критичні знахідки виправлено.
- [fact] Чийсь Rojo у Team Create перезаписав `Shared.i18n.en/uk` старою версією (без рядків місії та Спаркі). Відновлено через `ScriptEditorService:UpdateSourceAsync`. Поки всі не на свіжому `main`, це може повторитися.

## Next
1. Злити PR `events/single-director` → `main`; усім `git pull` (інакше чужий Rojo знову затре i18n і нові скрипти).
2. Повний прохід 5 солів удвох (Team Test): реальні завдання (скафандр, лід, панелі, помпа, шторм, радар, кисень, зразки, запуск) і баланс енергії на 2-му солі.
3. Автор `MB_Missions` (Studio): також слухати `ServerStorage.MB_ResetMission`, щоб «Почати спочатку» скидало зразки, панелі й радар.
4. Власник HUD: перевірити табло зліва вгорі (`MissionBoardClient`, Position 16,16).
5. [todo] Туторіал (`MB_Tutorial`, Studio) пише «сол = 24 h 39 min» без джерела в kb — підтвердити NASA або прибрати.
6. Відкладені дрібниці: відповідь Спаркі після з'єднання все одно зараховує «Запитай Землю»; у підсумку нема витрат води й енергії.

## Files touched
- new: `src/shared/MissionPlan.luau`, `src/server/MissionDirector.luau`, `src/client/MissionBoardClient.luau`, `tests/mission-plan.luau`, docs spec + plan.
- changed: `src/server/{Crops,WaterPump,Sparky,EventDirector,BaseLights,MB_ResourceServer.server,init.server}.luau`, `src/client/init.client.luau`, `src/shared/{LightsConfig,i18n/en,i18n/uk}.luau`.

## Relations
- continues [[Handoff: Sparky AI questions 2026-11-15 15:30]]
- uses [[Mars-Earth signal delay]]