---
title: Co-op campaign concept
type: concept
status: current
tags:
- game-design
- concept
date: 2026-11-14
permalink: sol-sandbox/concept/coop-campaign
---

# Co-op campaign concept

**Головна концепція з 2026-11-14.** Кооперативна гра від першого обличчя на Roblox для дітей 7–12 (1–3 гравці, соло — перемикання ролей). Замінює [[Game concept]] (оператор на Землі з камерами). Джерело — `CLAUDE.md` від Максима (2026-11-14), правила для агентів перенесено в `AGENTS.md`.

## Сюжет
Екіпаж прилітає на Марс шукати воду (лід під ґрунтом). Сонячна буря пошкоджує ракету для повернення, тож треба вижити до прильоту допомоги: бур, оранжерея, електролізер, радар. Перемога — дожити до дня прильоту.

Глави (чернетка): 1) прилітаємо, бур, перший лід; 2) сонячна буря, ракета пошкоджена; 3) оранжерея, перша їжа; 4) ремонти й нова буря; 5) прильот допомоги.

## Observations
- [decision] Рівно три ресурси: Water, Food, Oxygen. Енергії як ресурсу немає. Бур, оранжерея, електролізер і радар — механіки.
- [decision] Жодного безкоштовного вибору: кожна дія коштує час, воду або безпеку.
- [decision] До дедлайну (2026-11-15 23:59 за Києвом) робимо лише глави 1–2. Решту показуємо в презентації. Збереження прогресу не робимо.
- [decision] Механіки MVP: Drill (лід → Water, ламається), Electrolyzer (Water → Oxygen), Greenhouse (Water → Food), щодобове споживання екіпажу, Radar (позиції друзів, ламається), автоматична зміна сол (тривалість у `Config`).
- [decision] Буря береться з реального запису DONKI з датою і джерелом. Вибір: сховатися (безпечно, втрачаємо час) або працювати (росте radiation dose). Доза — статус гравця, а не четвертий ресурс.
- [decision] Ролі MVP: Engineer (ремонт), Botanist (оранжерея), Driller (бур і лід).
- [decision] Поразка м'яка: екран «mission failed» з поясненням, що пішло не так. Без смерті на екрані.
- [decision] Синхронізація коду — Rojo (не Studio Script Sync). Модулі розкладено по `src/shared|server|client` в `AGENTS.md`.
- [decision] Тексти UI — через модуль `Strings`, спочатку англійською, українська після дедлайну.
- [decision] Карта — реальна локація з карти льоду NASA (Arcadia Planitia).
- [fact] Власники: Systems (ResourceSystem, DayCycle), World (карта, база), Mechanics (Machines, ролі), Data+UI (DonkiService, ArchiveEvents, Hud, FactPopup), Presentation (GIF, відео, слайди).
- [fact] Заморожування функцій — неділя 15:00, подача до 22:30 неділі.
- [question] Маскот Спаркі з попередньої концепції: лишаємо як помічника у FactPopup чи прибираємо?
- [question] Глави кампанії — чернетка, команда має підтвердити.
- [todo] Баланс (тривалість сол, споживання, вихід машин) — game values у `Config`, позначені TODO balance.

## Relations
- part_of [[Index]]
- supersedes [[Game concept]]
- depends_on [[Decision: Roblox engine]]
- see_also [[NASA data sources]]
- see_also [[Decision: Mars setting]]
- see_also [[Base layout]]
