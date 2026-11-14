---
title: 'Decision: content and asset conventions'
type: decision
status: proposed
date: 2026-11-12
permalink: sol-sandbox/decisions/2026-11-12-content-and-asset-conventions
---

# Decision: content and asset conventions

Тексти гри та ресурси дизайну мають одне джерело правди. Агенти не вигадують власних кольорів, шляхів чи формулювань.

## Observations
- [decision] Тексти: ключі i18n у `src/i18n/uk.json` та `src/i18n/en.json`. Правила описані в скілі `kid-copy`.
- [decision] Кольори матеріалів зберігаються в `assets/palette.json`, токени UI в `assets/ui-tokens.json`, спрайти в `assets/sprites/` (масштаб 1×), іконки в `assets/icons/` (SVG з currentColor). Правила описані в скілі `design-handoff`.
- [decision] Задачі створюються в `kb/tasks/` за скілом `task-split`. Паралельні задачі не чіпають одних і тих самих файлів.
- [todo] Узгодити з дизайнером на D-1 і поставити статус accepted.

## Relations
- part_of [[Index]]
- implements [[Decision: browser TS canvas]]
- see_also [[Team roles]]