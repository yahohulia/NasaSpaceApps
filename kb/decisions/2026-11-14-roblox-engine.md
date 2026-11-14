---
title: 'Decision: Roblox engine'
type: decision
status: accepted
date: 2026-11-14
permalink: sol-sandbox/decisions/2026-11-14-roblox-engine
---

# Decision: Roblox engine

Гру робимо на Roblox (Roblox Studio + Luau). Це замінює [[Decision: browser TS canvas]]. Концепцію команда трохи змінить під Roblox.

## Observations
- [decision] Команда обрала Roblox, бо ця платформа ближча й зрозуміліша дітям 7–12 років (рішення користувача 2026-11-14).
- [decision] Код живе в git як `.luau` файли в `src/` і синхронізується в Studio через Rojo. 3D-світ і моделі збираються в Studio (Team Create) і Rojo їх не відстежує, тому `Workspace` у `default.project.json` не описаний.
- [decision] Тулчейн закріплено в `rokit.toml`: rojo 7.7.1, wally 0.3.2, selene 0.32.0, stylua 2.6.0, lune 0.11.1. Кожен учасник ставить його командою `rokit install`.
- [decision] Агенти бачать Studio і керують ним через вбудований MCP-сервер Studio (`Roblox_Studio` у `.mcp.json`). Старий `Roblox/studio-rust-mcp-server` закрито, ним не користуємося.
- [fact] Дані NASA на сервері гри тягнемо через `HttpService`, тому обмеження CORS у RadLab і OSDR тут не заважають. Потрібно увімкнути «Allow HTTP Requests» у Game Settings.
- [risk] Вебгравця в Roblox немає: журі потрібен акаунт і клієнт Roblox. Умови Roblox — 13+, молодшим потрібен дозвіл батьків. Тому обов'язково готуємо відео й публічне посилання на гру.
- [decision] Вебзаготовку React Router ([[Decision: React Router SPA]]) видалено 2026-11-14. Скіл `design-handoff` (палітра й PNG-спрайти для canvas) теж видалено. Скіли `nasa-data`, `kid-copy`, `task-split` і `handoff` адаптовано під Roblox/Luau.

## Relations
- part_of [[Game concept]]
- see_also [[Decision: browser TS canvas]]
- see_also [[Decision: React Router SPA]]
- see_also [[NASA data sources]]
