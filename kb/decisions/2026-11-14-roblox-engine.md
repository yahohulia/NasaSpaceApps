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
- [decision] Групу Roblox («Holland pilots») поки не створюємо: створення коштує 100 Robux (перевірено на сторінці communities/create 2026-11-14), а на акаунті 0. Гра належить акаунту Ярослава, колеги — колаборанти з правом Edit.
- [fact] Колаборанти (https://create.roblox.com/docs/projects/collaboration): у відкритій грі в Studio кнопка **Collaborate** → Manage Collaborators → знайти людину → **Edit** → Save. Team Create вмикається сам. Право Edit можна дати **лише друзям** Roblox. Для Team Create з іншими власник і колаборанти мають пройти **перевірку віку** (ID або оцінка за обличчям). Учасникам до 16 може знадобитися дозвіл батьків або статус trusted friends. Колаборант заходить через Creator Dashboard → Shared With Me → Edit in Studio. Відкатувати версії може лише власник.
- [question] Як колаборанти користуються пакетами й ассетами, завантаженими власником, на сторінці про колаборацію не сказано. Треба перевірити на практиці.
- [fact] Ассети колаборантів (https://create.roblox.com/docs/projects/assets/privacy, 2026-11-14): Restricted-ассет видно або чутно в грі, лише коли **сама гра** (universe) має на нього дозвіл. Інакше він не завантажується, а в Output з'являється помилка, на яку можна клікнути. Images/Decals/Meshes за замовчуванням Open Use, якщо автор не ввімкнув «restrict assets on creation». Для Audio, Video, Animations, Models і Packages діють свої умовчання, сторінка їх не називає. Аудіо — головний ризик.
- [decision] Правило команди: хто завантажив Restricted-ассет (звук, відео, анімацію), той одразу дає дозвіл грі: Creator Dashboard → Development Items → вкладка типу → ассет → Permissions → Experiences → Add experiences → universe ID гри. Або в Studio клікає помилку в Output і погоджується. Дозвіл грі назавжди, відкликати його не можна. Universe ID записати в `AGENTS.md`, коли гру опублікують.
- [risk] Вебгравця в Roblox немає: журі потрібен акаунт і клієнт Roblox. Умови Roblox — 13+, молодшим потрібен дозвіл батьків. Тому обов'язково готуємо відео й публічне посилання на гру.
- [decision] Вебзаготовку React Router ([[Decision: React Router SPA]]) видалено 2026-11-14. Скіл `design-handoff` (палітра й PNG-спрайти для canvas) теж видалено. Скіли `nasa-data`, `kid-copy`, `task-split` і `handoff` адаптовано під Roblox/Luau.

## Relations
- part_of [[Game concept]]
- see_also [[Decision: browser TS canvas]]
- see_also [[Decision: React Router SPA]]
- see_also [[NASA data sources]]
