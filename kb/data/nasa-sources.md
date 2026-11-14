---
title: NASA data sources
type: data
tags:
- data
date: 2026-11-12
permalink: sol-sandbox/data/nasa-sources
---

# NASA data sources

Реєстр джерел. Будь-яке число, яке потрапляє в гру, має бути тут разом з URL і датою перевірки.

## Observations
- [fact] DONKI (Space Weather Database Of Notifications, Knowledge, Information): вспишки (FLR), SEP, CME, геомагнітні бурі. Робочий API — `https://ccmc.gsfc.nasa.gov/DONKI-API/get/...` без ключа (див. перевірку нижче). Старий шлях через api.nasa.gov частково зламаний.
- [fact] OSDR (Open Science Data Repository): дозиметрія та біологічні дослідження астронавтів.
- [question] Доза на поверхні Марса (Curiosity RAD), доза на поверхні Місяця, сонячна енергія на Марсі відносно Землі, тривалість місячної ночі, продуктивність MOXIE — **усе це ще не перевірено**. Dev 4 має внести кожне значення з джерелом.
- [question] Кандидати з документа концепції ([[Game concept]]), **ще не перевірені за першоджерелом**. Доза на поверхні Марса ~0,64 мЗв/добу і в польоті ~1,8 мЗв/добу (Curiosity RAD, SwRI). Затримка зв'язку Земля–Марс ~3–22 хв в один бік. Сонячне з'єднання раз на ~26 місяців, ≈2 тижні без команд. Сол 24 год 39 хв. Затримка до Місяця ~1,3 с.
- [fact] Вкладку Resources челенджу прочитано 2026-11-14. Офіційні ресурси NASA:
  - NASA Open APIs — https://api.nasa.gov/ (APOD, Mars Rover Photos, DONKI; безкоштовний ключ з вищими лімітами, ніж DEMO_KEY).
  - DONKI — https://ccmc.gsfc.nasa.gov/tools/DONKI/ (спалахи, CME та інші події космічної погоди → радіаційний ризик, перебої зв'язку).
  - OSDR — https://osdr.nasa.gov/bio/repo/, пошуковий API https://osdr.nasa.gov/osdr/data/search (космічна біологія і здоров'я астронавтів: кістки, м'язи, імунітет, сон; рослини).
  - RadLab (OSDR Radiation Dosimetry) — https://visualization.osdr.nasa.gov/radlab/gui/data-api/ (справжні виміри дози на МКС від кількох агенцій, напр. absorbed dose rate).
  - Mars Trek — https://trek.nasa.gov/mars/ (знімки поверхні, рельєф, дані Curiosity і Perseverance).
- [fact] Ресурси партнера CSA (Канада): Space resources for STEM and youth organizations — https://www.asc-csa.gc.ca/eng/youth-educators/resources-stem-and-youth-organizations.asp ; Food production on the moon and in remote areas — https://www.asc-csa.gc.ca/eng/youth-educators/toolkits/food-production/ (їжа в космосі, харчування астронавтів).
- [fact] Правило сторінки: для не-урядових (не-US) сайтів треба дотримуватися їхніх умов використання даних.
- [fact] Перевірка API 2026-11-14 (Node з `--use-system-ca`, бо на машині Ярослава HTTPS іде через нестандартний корінь сертифікатів):
  - **RadLab API** `https://visualization.osdr.nasa.gov/radlab/api/` — працює, без ключа, CSV/TSV/JSON. Є **Curiosity RAD на поверхні Марса** (`instrument_id=MSL-RAD-Surface`, `trajectory=Mars surface`), а також МКС, LRO та інші. Приклад: `?instrument_id=MSL-RAD-Surface&timestamp>=2018-06-01&timestamp<2018-07-15&absorbed_dose_rate&format=csv`. Середнє `absorbed_dose_rate` у червні–липні 2018 ≈ 8,9, у січні 2024 ≈ 5,2, з піком 39 (схоже на сонячну подію).
  - [question] Документація RadLab пише одиницю «Gy/hour», але значення ~5–9 відповідають **мкГр/год**: 8,9 × 24 ≈ 0,21 мГр/добу, як у публікаціях RAD. Одиницю треба підтвердити в knowledgebase RadLab, перш ніж показувати в грі.
  - [fact] Дані MSL-RAD-Surface є щонайменше для 2018 і 2024 років. За серпень–вересень 2012 і червень 2025 рядків немає.
  - **DONKI — використовувати новий хост CCMC `https://ccmc.gsfc.nasa.gov/DONKI-API/get/<TYPE>?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD`** (з OpenAPI-специфікації на https://ccmc.gsfc.nasa.gov/DONKI/api/). Ключ не потрібен, `Access-Control-Allow-Origin: *`, тож браузерна гра може тягнути дані напряму. Ендпоінти: FLR, SEP, CME, CMEAnalysis, GST, IPS, HSS, MPC, RBE, WSAEnlilSimulations, notifications. Перевірено 15.09–13.11.2026: FLR 25 подій (напр. M6.7 08.10.2026, M6.4 10.10.2026), CME 174, GST 3, SEP 0, notifications 77. Травень 2024: 181 спалах, зокрема X1.6 03.05.2024. Запит SEP за цілий рік повернув «API Error», тож тримаємо діапазон ≤ 60 днів.
  - [fact] Старі шляхи не працюють: `api.nasa.gov/DONKI/FLR` → 404 (CME там ще відповідав), `kauai.ccmc.gsfc.nasa.gov/DONKI/WS/get/...` з цієї мережі недоступний.
  - **DEMO_KEY** — ліміт вичерпався за ~10 запитів. Потрібен власний ключ з https://api.nasa.gov/.
  - **Mars Rover Photos API** — **архівований NASA** (банер на api.nasa.gov; `api.nasa.gov/mars-photos/...` → 404 «No such app»). Не плануємо на нього.
  - **APOD** — старий `api.nasa.gov/planetary/apod` архівують 1 грудня 2026 (банер на api.nasa.gov). Новий: `https://science.nasa.gov/wp-json/wp/v2/apod-basic` → 200, без ключа, CORS дозволяє будь-який origin; поля `date,title,explanation,credit,copyright,url,hdurl,media_type`. Для гри APOD не критичний.
  - **OSDR search API** `https://osdr.nasa.gov/osdr/data/search?term=...&type=cgene&size=N` — працює, JSON з полями `Accession`, `Study Title`, `Mission.Name`, `organism`. Наприклад, «plant growth spaceflight» дає 56 досліджень, серед них OSD-772 «PH-04 Chile Peppers in Space» (SpaceX-22) і Arabidopsis на SpaceX-5/23. **CORS дозволено лише для osdr.nasa.gov**, тому з браузерної гри напряму не працює: факти готуємо заздалегідь у JSON. Сторінка репозиторію https://osdr.nasa.gov/bio/repo/ відкривається (200).
  - **Mars Trek** https://trek.nasa.gov/mars/ — 200. Тайли карти Марса доступні через WMTS, CORS `*`: `https://trek.nasa.gov/tiles/Mars/EQ/<layer>/1.0.0/default/default028mm/{z}/{y}/{x}.jpg`. Перевірено шари `Mars_MGS_MOLA_ClrShade_merge_global_463m` і `Mars_Viking_MDIM21_ClrMosaic_global_232m`, є `WMTSCapabilities.xml`. Підходить для фону «вид зі шлюзу» або карти місця бази.
  - **RadLab API** не віддає заголовок CORS, тож з браузера напряму не працює: дози готуємо заздалегідь у JSON.
  - **DONKI tools page** https://ccmc.gsfc.nasa.gov/tools/DONKI/ — 200.
  - **CSA STEM** — у браузері відкривається (з Node був ECONNRESET). Корисне там: «Astronautics vocabulary» (для словника Спаркі), «Copyright/permission to reproduce CSA materials» (перевірити перед використанням), «Open data». **CSA food production** — 200.
- [todo] Отримати власний ключ api.nasa.gov (потрібен лише для APOD та інших сервісів api.nasa.gov; DONKI-API від CCMC працює без ключа).

## Relations
- part_of [[Index]]
- see_also [[Challenge]]