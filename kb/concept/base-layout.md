---
title: Base layout
type: concept
status: current
tags:
- world
- base
date: 2026-11-14
permalink: sol-sandbox/concept/base-layout
---

# Base layout

Стартова база на Марсі: один великий купол (головна кімната) і менші допоміжні модулі, з'єднані коридорами. На старті є лише найпотрібніше. Решту (більша оранжерея, лабораторія, нові каюти) гравці добудовують самі на місцях розширення. Усе живе в Studio-плейсі (`Workspace.Base`), не в Rojo.

## Observations
- [fact] Головний купол: `Workspace.Base.Habitat`, центр (1, 0, 49), радіус ≈25. Усередині каюти екіпажу, стіл, пульт місії. Шлюз на півдні (−90°), коридор до оранжереї на сході (0°).
- [fact] Нові модулі (2026-11-14) — у `Workspace.Base.Modules`. Кожне крило = коридор + модуль, дверний отвір у нижньому кільці куполу:
  - `LifeSupportWing` (NE, 45°) — модуль `LifeSupport`: `Electrolyzer` (атрибут `Machine = "Electrolyzer"`, PrimaryPart `Body`), `WaterTank`, `OxygenTanks`, `AirScrubber`. Колір-акцент синій.
  - `ShelterWing` (NW, 135°) — `StormShelter`: бетонний бункер, засипаний реголітом (`RegolithBerm`), стіна з мішків з водою (`WaterWall`), лавки. Невидима зона `ShelterZone` (атрибут `ShelterZone = true`, CanCollide/CanQuery = false) — для механіки бурі «сховатися». Акцент помаранчевий.
  - `WorkshopWing` (SW, −135°) — `Workshop`: `RepairBench` (атрибут `Machine = "RepairBench"`, для Engineer), `SpareParts`, `DrillBits`, `Printer3D`, `SuitLockers`. Акцент жовтий.
  - `ExpansionPort_SE` (SE, −45°) — короткий коридор із закритим люком (атрибут `ExpansionPort = true`) і розмічений майданчик `BuildSite` (атрибут `BuildSlot = "SE"`, Ø19) для першого модуля, який будують гравці.
- [fact] Крила мають атрибути `ModuleId` (на моделі модуля) і `Starter = true` (на крилі).
- [fact] Прибрані панелі куполу (дверні отвори) лежать у `ServerStorage.BaseBackup`. Щоб відкотити: видалити `Workspace.Base.Modules` і повернути панелі в `Workspace.Base.Habitat.Dome`. Рельєф у місцях модулів зрізано до рівня підлоги.
- [decision] Захист від радіації в укритті — реголіт поверх даху і вода в стінах. Це художнє рішення, а не числа. Реальні значення захисту, якщо знадобляться в грі, — лише з [[NASA data sources]].
- [todo] Вільні місця для наступних портів розширення: 90° (північ) заблоковано пультом місії, 180° (захід) — каютами. Нові порти краще робити з модулів (наприклад із `LifeSupport`) або перенести меблі.
- [fact] Бур (2026-11-14): `Workspace.Base.Drill`, центр (−5, 1, −38), ≈40 студів на південь від шлюзу, пульт дивиться на базу. Атрибути `Machine = "Drill"`, `Broken = false`, `StatusLight = "ControlUnit.StatusLight"`. Частини: `Skid`, `Mast` (маячок `Beacon`, прожектор `WorkLight`), `DrillHead` (PrimaryPart `Carriage`), `DrillString`, `Auger`, `Borehole` (уламки льоду), `MeltTank` (бак WATER), `ControlUnit` (табличка ICE DRILL, `StatusLight` зелена — можна фарбувати в червоний, коли `Broken`), `IceCores`. Невидимий `InteractPoint` перед пультом — сюди Mechanics ставить ProximityPrompt (використати / полагодити). Доріжка з жовтих ліхтарів від шлюзу: `Workspace.Base.DrillPath`.
- [todo] Логіка бура (лід → Water, поломка, ремонт) у `src/server/Machines/Drill` — ще немає. Власник — Mechanics.
- [todo] Радар — зовні, його ще немає. Власник — Mechanics.
- [fact] Карта (2026-11-14) розширена з 512×512 до 1536×1536 студів (рельєф від −768 до 768). Стара середина ±256 з базою не змінювалась; новий рельєф плавно зшитий із нею (сходинка ≤2 студи). Рівнина на висоті ≈1–5, пісок поверх каменю. По краю — кільце гір (заокруглений квадрат), починаються ≈545 студів від центру, висота 110–230, матеріали Rock/Basalt. Ігрова зона ≈ ±550.
- [fact] Рельєф (2026-11-14, друга версія): по всій карті пагорби й западини (±~12 студів), поле дюн, два «зморшкові хребти» (wrinkle ridges — типові для марсіанських рівнин) і 62 кратери (радіус 5–75 студів): чаша, вал з каменю, викиди навколо, у великих — плоске дно й центральна гірка. Генератор детермінований (seed 2026). Матеріали: Sand (рівнини, дюни), Ground (дно кратерів, плями реголіту), Rock/Basalt (вали, круті схили, гори). Форма кратерів — художня, не реальні числа.
- [fact] Під базою, `LandingZone`, `RocketModel`, `Cameras`, контрольними точками і спавном рельєф не змінено: 8 студів навколо кожної деталі — старий рельєф, далі 40 студів плавного переходу. Скелі `MarsLandscapeEnhancement` пересаджені на нову поверхню. Копія старої середини (±256) — `ServerStorage.TerrainBackup_Center` (відновлення: `Terrain:PasteRegion(backup, Vector3int16.new(-64,-6,-64), true)`); можна видалити, коли команда погодить новий рельєф.
- [fact] Скелі (2026-11-14): старі меші `MarsLandscapeEnhancement` (9 `WeatheredOutcrop` з дивною текстурою + 36 сірих `BasaltCluster`) прибрані в `ServerStorage.RocksBackup`. У Workspace було 3 однакові копії цієї папки — усі три там. Замість них — 10 останців (бутів) з рельєфу (шаруваті Rock/Sandstone, пласка вершина, осип) і валуни-Part'и Rock/Basalt у `Workspace.MarsRocks`.
- [fact] Розміщення бутів (x, z): орієнтир (−180, −170) видно від бази; західне поле (−330, −60), (−385, 40), (−300, 110), (−410, −140); східна пара (260, −190), (330, −110); північ (120, 330), (−210, 340), (380, 230). Валуни: осипи біля бутів, викиди на валах кратерів (R > 14), 16 поодиноких на рівнині; не ближче ~60 студів до бази. Кратери не ставляться на бути.
- [question] У Workspace по 3 копії `Cameras` і контрольних точок `Part` (однакові позиції) — схоже на випадкове дублювання. Не чіпали; власнику перевірити.
- [fact] Невидимі стіни `Workspace.MapBounds` (`WallN/S/E/W`) на ±680, висота 800, всередині гір (рельєф біля стін 79–209 студів). Без них персонаж міг би вилізти на гору. Щоб відкотити розширення: видалити `MapBounds` і залити `Air` усе поза квадратом ±256.
- [fact] `screen_capture` у Studio MCP лишає камеру Studio в режимі `Scriptable`. Після знімків повертайте `workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed`, інакше в Studio не можна крутити камеру.
- [question] Сонячні панелі (`Workspace.Base.SolarPanels`) і камери (`Workspace.Cameras`) лишилися зі старої концепції ([[Game concept]]). Енергії як ресурсу немає, тож панелі — декорація. Чи лишаємо камери?
- [decision] Вуличні ліхтарі прибрано (2026-11-15): 9 стовпів `Workspace.MB_BaseLights` навколо бази (тег `MB_NightLight`, вмикав їх уночі `MB_Atmosphere`) перенесено в `ServerStorage.MB_BaseLightsBackup`. `MB_Atmosphere` без них працює (просто не знаходить ламп). Маяки посадкового майданчика (`LandingZone.Beacons`) і зелена/червона лампа над шлюзом лишились.

## Relations
- part_of [[Co-op campaign concept]]
- see_also [[Decision: Roblox engine]]
