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
- [fact] Впалий супутник (2026-11-14): `Workspace.CrashedSatellite`, уламок у (−40, 0, 420), ≈370 студів на північ від бази. Вигаданий старий орбітер (не справжня місія NASA — не підписувати реальною назвою). Борозна ковзання ≈42 студи на північний захід з випаленим дном (Basalt), вал піску спереду. Частини: `Bus` (корпус у фользі, відкритий люк з електронікою, червоний `Beacon`), `SolarWing` (зігнуте), `BrokenSolarWing` (у борозні), `Antenna` (тарілка), `Debris`, `HatchDoor`. Атрибут моделі `Landmark = "CrashedSatellite"`.
- [decision] Супутник дає **запчастини для ремонту машин**, а не новий ресурс (правило: ресурсів рівно три). Точки збору — невидимі `SalvageElectronics` (`Salvage = "SpareParts"`), `SalvageSolarCells` (`"SolarCells"`), `SalvageAntenna` (`"Antenna"`, напр. для ремонту радара); у кожної `Salvaged = false`.
- [todo] Mechanics: ProximityPrompt на точках `Salvage*`, що саме дає кожна запчастина і скільки (значення в `Config`, `-- game value, TODO balance`). Story: хто і як знаходить супутник (радар? підказка CAPCOM?) — вирішити команді.
- [fact] Зразки на поверхні (2026-11-14): `Workspace.Samples`, ≈295 штук по всій карті (не ближче 25 студів до старої і нової бази, не в горах). Атрибути: `Collectible = "Sample"`, `SampleKind`, `Collected = false`. Види: `Rock` (222, звичайний червоний камінець), `IronMeteorite` (21, рідкісні; Model з 3 шматків CorrodedMetal, атрибути на моделі), `Hematite` (52, темні кульки-«чорниці» купками по 5–8).
- [fact] Біля нової бази (`Base`/`MarsBase`/`MarsBaseFixes`/`MB_Interactables`) у радіусі 60 студів від будівель прибрано 12 зразків і 7 купок валунів `MarsRocks` → `ServerStorage.SamplesRemovedNearBase`. Якщо базу знову перенесуть — повторити цю чистку.
- [fact] Блиск: на кожному `IronMeteorite` і `Hematite` — `SparkleAttachment` з `ParticleEmitter` «Sparkle» (метеорити частіше, гематит рідше). Mechanics: при зборі зразок зникає разом з блиском.
- [fact] Великий метеорит (2026-11-14): `Workspace.MeteoriteSite` у (220, 40), ≈205 студів на північний схід від нової бази. Мілка ямка з валиком, темні промені навколо (здутий пил — так виглядають свіжі місця падіння), у ямці `BigIronMeteorite` (~3.5 студа, атрибути `Collectible = "Sample"`, `SampleKind = "IronMeteorite"`, `Large = true`, `Collected = false`) + 4 малі уламки-зразки на валу. Розмір — ігровий: справжні знайдені метеорити значно менші.
- [todo] Факт для FactPopup біля великого метеорита: Opportunity знайшов залізо-нікелевий метеорит «Heat Shield Rock» (розмір ~ баскетбольний м'яч). Звірити з NASA і записати в `kb/data/` перед показом у грі.
- [decision] Зразки — не ресурс (ресурсів рівно три). Ідея: зібрати → на базі сортувати на звичайні камені й залізо (метеорит, гематит). Мідь не додали: марсоходи її не знаходили, а гра не має подавати вигадку як факт. Нові види — лише з джерелом у [[NASA data sources]].
- [todo] Звірити з першоджерелами NASA і записати в `kb/data/`: залізо-нікелеві метеорити на Марсі (Opportunity, Curiosity) і гематитові сферули «blueberries» (Opportunity). Поки що це знання агента, не перевірене посиланням.
- [todo] Станція сортування на базі + логіка збору/сортування (Mechanics). Місце залежить від нової бази `MarsBase` (див. нижче).
- [question] Базу переробляють: у Workspace нові `MarsBase` (x 14…177, z −196…−48), `MarsBaseFixes`, `MB_Interactables` (`MB_DrillPoint`, `MB_GreenhousePoint`, `MB_BunkPoint`, `MB_WaterStation`), `MB_HabitatZone`; стара база і бур (`Drill`, `DrillPath`) — у `ServerStorage.OldBaseBackup`. Рельєф під новою базою не захищений генератором (захищали стару). Треба узгодити, де тепер бур і чи повертати його на карту.
- [fact] Стартовий майданчик (2026-11-14, друга версія): `LandingZone` + `RocketModel` збільшено ×3 від початкового (ракета ≈90 студів заввишки, площадка вежі на ≈73; реальний шатл ≈37 м ≈ 120 студів — свідомий компроміс) і перенесено: центр майданчика (80, 1, 60), ≈20 студів від північного краю `MarsBase`. Рельєф під ним вирівняно (висота 1, плавні краї 20 студів). Попереднє місце (130, 50) лишилось рівним піщаним майданчиком.
- [decision] Обслуговувальну вежу (`ServiceTower` з колонами, площадкою, містком і старою драбиною) прибрано повністю → `ServerStorage.LaunchPadBackup.ServiceTower_removed`. Замість неї — проста розкладна драбина `LandingZone.CrewLadder`: від порогу дверей `RocketModel.CrewHatch` (двері дивляться на −Z, висота ≈74) під кутом 75° до майданчика (низ ≈ (82, 4.6, 33.6)), 59 перекладин, невидимий `ClimbTruss` для лазіння; перевірено `GetPartsInPart` — модель ракети ніде не перетинає.
- [fact] Біла (жовтувата) плита `Workspace.Сheckpoints` 13×13 зі скриптом контрольної точки прибрана з карти на прохання → `ServerStorage.LaunchPadBackup.Сheckpoints`. Скрипт `ServerScriptService.Сheckpoint Script` чекає папку `Workspace.Checkpoints` — це окрема річ, її не чіпали.
- [fact] Сходи вежі прибрано (→ `ServerStorage.LaunchPadBackup.Stairs`, там же копії старих `LandingZone`/`RocketModel`). Замість них — мінімалістична драбина `LandingZone.ServiceTower.Ladder` з боку −Z (дві рейки, перекладини кожні 1.2 студа, невидимий `TrussPart` для лазіння), в огорожі площадки `CrewDeck` вирізано прохід 3 студи. Три безхозні `Part` 4×1×2, що лежали на сходах (жоден скрипт їх не використовує), → `LaunchPadBackup.StrayPart_fromStairs`.
- [question] У Workspace по 3 копії `Cameras` (однакові позиції) — схоже на випадкове дублювання. Не чіпали; власнику перевірити.
- [fact] Невидимі стіни `Workspace.MapBounds` (`WallN/S/E/W`) на ±680, висота 800, всередині гір (рельєф біля стін 79–209 студів). Без них персонаж міг би вилізти на гору. Щоб відкотити розширення: видалити `MapBounds` і залити `Air` усе поза квадратом ±256.
- [fact] `screen_capture` у Studio MCP лишає камеру Studio в режимі `Scriptable`. Після знімків повертайте `workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed`, інакше в Studio не можна крутити камеру.
- [question] Сонячні панелі (`Workspace.Base.SolarPanels`) і камери (`Workspace.Cameras`) лишилися зі старої концепції ([[Game concept]]). Енергії як ресурсу немає, тож панелі — декорація. Чи лишаємо камери?

## Relations
- part_of [[Co-op campaign concept]]
- see_also [[Decision: Roblox engine]]
