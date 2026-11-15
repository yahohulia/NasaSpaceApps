---
title: Space crops
type: data
status: current
tags:
- greenhouse
- crops
- nasa
date: 2026-11-15
permalink: sol-sandbox/data/space-crops
---

# Space crops

Культури для ящика з насінням на складі ([[Greenhouse crops]]). Беремо лише те, що NASA справді вирощувала в космосі (МКС: Veggie та Advanced Plant Habitat). Числа днів — з джерел нижче; у грі вони лише задають, яка культура росте швидше (швидкість гри — game value). Перевірено 2026-11-15 через пошук на nasa.gov / ntrs.nasa.gov.

## Observations
- [fact] Салат 'Outredgeous' (червоний ромен), Veggie: перший урожай ріс 33 дні (VEG-01A, 2014, не їли — заморозили для аналізу). 10.08.2015 екіпаж (Скотт Келлі, Челл Ліндгрен, Кіміа Юі) уперше офіційно з'їв овоч, вирощений на МКС (VEG-01B). Джерела: https://www.nasa.gov/wp-content/uploads/2019/04/veggie_fact_sheet_508.pdf , https://www.nasa.gov/missions/station/veggie-plant-growth-system-activated-on-international-space-station/
- [fact] Редиска, Plant Habitat-02 (Advanced Plant Habitat): перший урожай Кейт Рубінс зібрала 30.11.2020 після 27 днів росту; другий — 31.12.2020, його з'їли. Джерело: https://www.nasa.gov/missions/station/astronauts-harvest-radish-crop-on-international-space-station/
- [fact] Гірчиця міцуна, Veggie VEG-04A (2019): 35-денний тест з одним урожаєм; VEG-04B — 58 днів, урожаї на 4, 6 і 8 тижні з тих самих рослин. Частину врожаю екіпаж з'їв. Джерела: https://ntrs.nasa.gov/citations/20205008589 , https://www.nasa.gov/image-article/nasa-astronaut-christina-koch-collects-packs-mizuna-mustard-greens/
- [fact] Карликова пшениця 'Apogee': перша культура в Advanced Plant Habitat; тест почався 22.01.2018, пшеницю зібрали приблизно через 30 днів (NASA в інших статтях пише «близько п'яти тижнів»). Її не їли. Джерела: https://ntrs.nasa.gov/api/citations/20180008564/downloads/20180008564.pdf , https://blogs.nasa.gov/kennedy/2018/03/16/we-have-the-wheat/
- [fact] Перець чилі 'Española Improved', Plant Habitat-04: ріс з 12.07.2021, перший урожай 29.10.2021 (екіпаж скуштував 7 перців — уперше астронавти їли перець, вирощений у космосі), останній урожай 26.11.2021. Перець вибрали з понад двох десятків сортів; він багатий на вітамін C; перці — складна культура: довше проростають, ростуть і дають плоди. Джерела: https://www.nasa.gov/image-article/astronauts-have-first-taste-of-peppers-grown-space/ , https://www.nasa.gov/blogs/stationreport/2021/11/26/iss-daily-summary-report-11-26-2021/
- [fact] Карликові томати 'Red Robin', Veggie VEG-05 (2022–2023): урожаї на 90, 97 і 104 день; на орбіті дозріло лише близько десятка помідорів, бо були проблеми з поливом і надто сухе повітря. Джерела: https://www.nasa.gov/missions/station/nasa-teams-persevere-through-plant-challenges-in-space/ , https://ntrs.nasa.gov/citations/20240001505
- [decision] Дні, які йдуть у гру (від посадки до першого врожаю): редиска 27, пшениця 30, салат 33, міцуна 35, томат 90, перець 109 (12.07 → 29.10.2021). Це «справжні дні NASA»; гра прискорює їх однаково для всіх культур (`CropConfig.SecondsPerRealDay`, game value). Скільки їжі дає врожай — game value.
- [question] Точна кількість стиглих томатів у VEG-05 у різних джерелах різна (12 або 11) — у грі число не показуємо, лише «близько десятка».

## Relations
- part_of [[NASA data sources]]
- used_by [[Greenhouse crops]]
