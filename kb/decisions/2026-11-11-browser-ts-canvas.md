---
title: 'Decision: browser TS canvas'
type: decision
status: superseded
date: 2026-11-11
permalink: sol-sandbox/decisions/2026-11-11-browser-ts-canvas
---

# Decision: browser TS canvas

Гра в браузері на TypeScript + Vite. Рендер через Canvas 2D (`ImageData`) з typed arrays, клітинний автомат ~200×110. Без ігрового фреймворку. Статичний деплой.

## Observations
- [decision] 2026-11-14: замінено рішенням [[Decision: Roblox engine]].
- [fact] Челендж радить браузерну гру без встановлення і реєстрації.
- [decision] Правила матеріалів описуються даними (таблиця матеріалів), щоб кілька агентів могли додавати матеріали паралельно.
- [decision] Phaser, WebGL і WASM не потрібні: на такій сітці Canvas 2D дає 60 fps.
- [question] Чи потрібен проксі для NASA API (кеш, ключ)? За замовчуванням ні: вбудований JSON з архівними подіями плюс опційний live-запит.
- [todo] Затвердити на D-1 разом з контрактами рушія.

- [question] 2026-11-14: рішення ухвалювали під пісочницю з клітинним автоматом. Для [[Game concept]] (покроковий пульт + монітор камер) стек TS + Vite без фреймворку теж підходить. Але документ концепції ще питає «Phaser / чистий JS / Godot?», тому команда має це підтвердити.

## Relations
- part_of [[Index]]
- implements [[Sol Sandbox concept]]