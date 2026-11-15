---
title: Mars-Earth signal delay
type: data
tags:
- mars
- communication
- sparky
permalink: sol-sandbox/data/comm-delay
---

# Mars-Earth signal delay

Скільки летить радіосигнал між Марсом і Землею. Використовується в чаті зі Спаркі ([[Handoff: Sparky AI questions 2026-11-15 15:30]]).
How long a radio signal takes between Mars and Earth. Used by Sparky's chat with Earth.

## Observations
- [fact] NASA Goddard, «Space Communications: 7 Things You Need to Know»: «At Mars' closest approach — about 35 million miles away — the delay is about four minutes.» і «When the planets are at their greatest distance — about 250 million miles away — the delay is around 24 minutes.» Джерело: https://www.nasa.gov/centers-and-facilities/goddard/space-communications-7-things-you-need-to-know/ (перевірено 2026-11-15).
- [decision] (2026-11-15, Yaroslav) Затримка в грі справжня: беремо сьогоднішній час, за який сигнал летить від Марса до Землі, з NASA JPL Horizons. Сервер (`src/server/Horizons.luau`) робить один запит на старті. Якщо запит не вдався, береться знімок `src/server/data/horizons-mars-lt.json` з позначкою ARCHIVED, а якщо в знімку нема дати, то `Config.CommDelayMinutes = 20`. Відповідь приходить через подвійну затримку. Реальні хвилини йдуть як ігрові хвилини, бо годинник гри прискорений (`SolSeconds = 360`): 10,9 хв в один бік дають ≈2,7 реальних секунди, туди й назад ≈5,5 с.
- [fact] JPL Horizons API: `https://ssd.jpl.nasa.gov/api/horizons.api?format=json&COMMAND='499'&EPHEM_TYPE='OBSERVER'&CENTER='500@399'&START_TIME=…&STOP_TIME=…&STEP_SIZE='1 d'&QUANTITIES='20,21'`. Ключ не потрібен, сигнатура `NASA/JPL Horizons API 1.2`. Запит дає Марс, видимий із центру Землі: `delta` — відстань в а.о., `1-way_down_LT` — скільки хвилин летить світло від Марса до Землі. Перевірено 2026-11-15: Земля–Марс 1,3159 а.о., сигнал летить 10,94 хв.
- [fact] Знімок `horizons-mars-lt` (`node --use-system-ca scripts/snapshots.mjs horizons-mars-lt`, отримано 2026-11-15) охоплює 2026-11-08…2027-11-15, по рядку на день. Затримка в ньому від 5,64 до 18,37 хв.
- [fact] Сигнал летить зі швидкістю світла, тож дорога Марс → Земля і Земля → Марс займає однаковий час. Відповідь на питання приходить через подвійну затримку. ESA (блог Mars Express, «Spacecraft event time vs. Earth receive time»): «The delay between the two is usually called the One-Way Light Time (OWLT)» і «the time for a message to go to Mars and come back is the Two-Way Light Time (TWLT), or round-trip time». ESA теж дає «the minimum delay of around 4 minutes and the maximum of around 24 minutes». Джерело: https://blogs.esa.int/mex/?p=257 (перевірено 2026-11-15).
- [fact] NASA, Karasinski et al. 2025, «Assessment of the State of Communication Delay Research in Preparation for Missions Beyond Low Earth Orbit» (NTRS 20250000703): «Mars missions will encounter up to a 44-minute round-trip latency at a maximum distance from Earth.» Джерело: https://ntrs.nasa.gov/citations/20250000703 (перевірено 2026-11-15).
- [fact] Діапазон «3–22 хв» в один бік з інших джерел рахує інші відстані. Так пише, наприклад, NASA ASCEND 2022 (McBrayer, Chai, Judd): «communication delays will vary from 0 to 22 minutes over the course of a mission». Джерело: https://ntrs.nasa.gov/citations/20220013418. Чому там нижня межа 0 хв, в анотації не пояснено. У грі беремо 4–24 хв від NASA Goddard та ESA.

## Relations
- part_of [[NASA data sources]]