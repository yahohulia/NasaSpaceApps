---
title: NASA ice map
type: data
tags:
- data
- ice
- map
date: 2026-11-15
permalink: sol-sandbox/data/ice-map
---

# NASA ice map

Карта підповерхневого водяного льоду на Марсі, яку показуємо на пульті в науковій станції (див. [[Drill crafting]]).

## Observations
- [fact] Сторінка: «NASA's Treasure Map for Water Ice on Mars», NASA/JPL, автор Anthony Greicius, 10.12.2019 — https://www.nasa.gov/solar-system/nasas-treasure-map-for-water-ice-on-mars/ (прочитано 2026-11-15, HTTP 200).
- [fact] Зображення: https://www.nasa.gov/wp-content/uploads/2019/12/pia23514.jpg (1614×720), кредит «NASA/JPL-Caltech/ASU». Завантажено в Roblox як `rbxassetid://122016476140910` (2026-11-15).
- [fact] Легенда на зображенні: «Water Ice Depth (m)», шкала від «< 0.1» (пурпурний) до «> 0.8» (червоний). Біла рамка — район, куди найкраще відправити астронавтів копати лід.
- [fact] Текст сторінки (цитати): «Cool colors are closer to the surface than warm colors; black zones indicate areas where a spacecraft would sink into fine dust»; про Arcadia Planitia — «lots of blue and purple in this region, representing water ice less than one foot (30 centimeters) below the surface; warm colors are over two feet (60 centimeters) deep»; «A large portion of a region called Arcadia Planitia is the most tempting target in the northern hemisphere».
- [fact] Дані для карти: MRO Mars Climate Sounder і THEMIS на Mars Odyssey; звірено з радаром, свіжими кратерами з льодом і Gamma Ray Spectrometer (Mars Odyssey). Стаття в Geophysical Research Letters, провідний автор Sylvain Piqueux (JPL).
- [decision] У грі з цієї карти беремо лише: зображення з кредитом, пояснення кольорів і факт «у районі Arcadia Planitia лід менш ніж за 30 см під поверхнею». Підпис `ARCHIVED · 2019-12-10`.
- [decision] «Шанс льоду» на родовищах у нашій зоні — ігрове число (оцінка бази), не дані NASA; у грі прямо підписано «наша оцінка, не дані NASA». Значення в `src/shared/IceMapConfig.luau` (`-- game value, TODO balance`).
- [fact] Ассет належить акаунту 11994567135, а гра (universe 9327967477) — акаунту 1751145905, тож `rbxassetid://` у плейсі не вантажиться (Failure). Працює мініатюра `rbxthumb://type=Asset&id=122016476140910&w=768&h=432` (Roblox розтягує її до 768×432; вікно з пропорціями оригіналу повертає правильний вигляд). Для чіткішої карти: власник гри дає universe дозвіл «Use» на ассет (потрібен Open Cloud scope `legacy-asset:manage`) або сам перезавантажує картинку.
- [fact] У грі: `Workspace.IceMapScreen` (тег `IceMapConsole`) на середньому екрані пульта в науковій станції (78, 7.9, −60.5); код `src/client/IceMapClient.luau` + `src/shared/IceMapConfig.luau`, тексти `icemap.*`. Три рівні: увесь Марс → Arcadia Planitia (біла рамка NASA, позначка «Ми тут») → наша зона з родовищами A/B/C і їхнім «шансом льоду».
- [fact] Наша ігрова зона (~460 м) значно менша за один піксель цієї карти, тож справжня глибина однакова для всіх наших родовищ — різниця між ними лише в ігровій оцінці.

- [fact] 2026-11-15: картинку перезавантажила власниця гри (Maria_Strawberi, user 1751145905) — `rbxassetid://85333712790591` (тип Image, пройшов модерацію, у плейсі вантажиться: PreloadAsync = Success). Тепер `IceMapConfig.Image` і настінний екран `Workspace.IceMapScreen` беруть оригінал, а не мініатюру `rbxthumb`. На екрані підпис: «Image: NASA/JPL-Caltech/ASU · ARCHIVED · 2019-12-10». Офіційна назва: «A Water Ice Map for Mars» (PIA23514), https://science.nasa.gov/photojournal/a-water-ice-map-for-mars — дані Mars Reconnaissance Orbiter (MCS), Mars Odyssey (THEMIS) і Mars Global Surveyor.

## Relations
- part_of [[NASA data sources]]
- see_also [[Drill crafting]]
