---
title: Drill crafting
type: concept
status: current
tags:
- mechanics
- drill
- crafting
date: 2026-11-14
permalink: sol-sandbox/concept/drill-crafting
---

# Drill crafting

Щоб добувати лід, команда спершу збирає бур. Цикл: зібрати зразки надворі → зняти запчастину зі старого супутника → посортувати на базі → зібрати бур на місці з льодом → (за потреби) скласти бур і перенести на інше місце з льодом.

## Observations
- [decision] Рецепт бура: 3 заліза + 1 запчастина зі спільного складу бази. Числа — ігрові, у `src/shared/CraftConfig.luau` (`-- game value, TODO balance`). Ресурсів у грі й далі три (Water, Food, Oxygen); залізо, камені й запчастини — це матеріали, не ресурси.
- [fact] Код: `src/server/Crafting.luau` (сервер, `Crafting.start()` в `init.server.luau`), `src/client/CraftClient.luau` (панель «сумка · запчастини · склад бази» внизу екрана + короткі повідомлення), `src/shared/CraftConfig.luau`, тексти `craft.*` в `src/shared/i18n/en|uk.luau`. Remote: `ReplicatedStorage.CraftNotify`.
- [fact] Стан: у гравця атрибути `BagSamples`, `CarryParts`, `CarryingDrill`; спільний склад — атрибути `Iron`, `Rocks`, `Parts`, `DrillBuilt` на `ReplicatedStorage.MB_BaseState` (папку створює `MB_ResourceServer` або `Crafting`, хто перший).
- [fact] Зразки (`Workspace.Samples`, `Workspace.MeteoriteSite`): кнопка «Pick up», у сумку до 10 (`BagSize`). Що за зразок — видно лише після сортування. Залізо при сортуванні: `Rock` 0, `Hematite` 1, `IronMeteorite` 2, великий метеорит 5.
- [decision] Метали (2026-11-15): на складі три метали — `Iron`, `Nickel`, `Manganese` (атрибути `MB_BaseState`). Що з чого (за реальними знахідками, [[Metals on the Mars surface]]): гематит → залізо; залізний метеорит → залізо + нікель; новий зразок `Manganese` (світлий пісковик з темними жилами оксиду марганцю, як у Kimberley, Curiosity) → марганець. Кількості — `CraftConfig.Yield` (`-- game value, TODO balance`). Мідь/цинк не додаємо: на Марсі вони лише домішка в породі.
- [fact] На карті (2026-11-15): 32 `ManganeseRock` (Model: світлий пісковик Sandstone з 2 нерівними шматками + 2–3 темні вертикальні жили Slate, легкий блиск; атрибути на моделі, `SampleKind = "Manganese"`) — 2–3 біля кожного останця + решта на рівнині; ще 10 залізних метеоритів (джерело нікелю). Разом у `Workspace.Samples`: Rock 213, Hematite 46, IronMeteorite 33, Manganese 32. Усе ≥40 студів від будівель бази і ≥20 від ракети, супутника, метеорита, місць з льодом.
- [todo] Нікель і марганець поки ні на що не витрачаються. Ідеї: ремонт радара / електролізера, другий бур. Вирішити команді.
- [fact] Інвентар (2026-11-15): при підборі сервер кладе візуальну копію зразка в `Player.SampleBag` (без підказок, блиску й світла); `CraftClient` малює над панеллю 10 клітинок, у зайнятих обертається 3D-копія саме цього каменя (через ViewportFrame), без тексту — сортують на око. Окремі клітинки зі значком плати — запчастини (`CarryParts`). Після сортування `SampleBag` очищується.
- [decision] Гематит (2026-11-15, друга версія): замість окремих кульок на піску — `HematiteRock` (Model): шматок шаруватого пісковику (2 плити Sandstone) з 4–7 сіро-синіми кульками, втопленими в поверхню, і 0–2 кульками, що «випали» поруч. Так NASA описує «чорниці» Opportunity: вкраплені в м'який шаруватий пісковик (див. [[Metals on the Mars surface]]). Купки проріджено: 24 шматки замість 46 кульок; старі кульки — `ServerStorage.HematiteBallsBackup`. Атрибути на моделі, `SampleKind = "Hematite"`.
- [decision] Гематит — не блискучі чорні кулі: справжні «чорниці» Opportunity майже круглі, матові, сіро-сині, частково в ґрунті, часто злиплі по дві. У грі вони більші за справжні (ті — кілька мм), щоб їх було видно. TODO: факт про них показувати лише після звірки з NASA (див. [[NASA data sources]]).
- [fact] Супутник: 3 точки `Salvage*` у `Workspace.CrashedSatellite`, кожна дає 1 запчастину один раз на сервер.
- [fact] Стіл сортування: `Workspace.SortStation` усередині бази, у науковій станції (`MarsBase.ScienceStation_Solid`), на підлозі біля (78, 2.3, −71), перед пультом з екранами; кнопка на `TableTop` (тег `Craft_SortStation`). Спершу стояв надворі біля шлюзу (−8, −140), перенесли всередину. Три ящики без тексту, з підказками-предметами: іржаве залізо, червоні камені, синій ящик із платою.
- [fact] Місця з льодом — частини з тегом `MB_Drill`: `MB_Interactables.MB_DrillPoint` (−1, −34) і нові `Workspace.IceSites.IceSite_2` (−140, −40), `IceSite_3` (260, 120). Біля кожного — ділянка льоду (Glacier) і стовпчик із синім прапорцем.
- [fact] Бур: шаблон `ServerStorage.CraftDrillTemplate` (копія старого бура, атрибут `GroundOffset`). Після збирання клон стоїть у `Workspace.CraftDrills.IceDrill` над ділянкою льоду. «Pack up drill» (клавіша F) — бур зникає, гравець «несе» його; «Set up drill» на іншому місці з льодом — ставить. Якщо носій вийде з гри, бур повертається на останнє місце.
- [decision] `MB_` скрипти не редагуємо. `Crafting` лише вмикає/вимикає їхню кнопку «Dig ice» (`MB_Prompt`): вона працює тільки там, де стоїть бур.
- [todo] Перевірити в Play: збір, сортування, крафт, перенесення; чи `MB_Prompt` справді вимикається. Ще не запускалось — код у `src/` потрапить у плейс після `git pull` + `rojo serve`.
- [question] На машині, з якої писали код, немає `selene`/`stylua`/`rojo` (Rokit не встановлено) — перевірки перед комітом не запускали. Синтаксис `Crafting.luau` і `CraftConfig.luau` перевірено компіляцією в Studio.
- [question] `MB_` скрипти (`MB_ResourceServer`, `MB_Config`, `MB_HUD`) живуть лише в Studio; у коментарях згадано `studio/MB` у репо, але такої папки ще немає. За новим правилом в `AGENTS.md` скрипти мають бути в `src/`.

## Relations
- part_of [[Co-op campaign concept]]
- see_also [[Base layout]]
