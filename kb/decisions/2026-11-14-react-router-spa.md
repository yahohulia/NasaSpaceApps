---
title: 'Decision: React Router SPA'
type: decision
status: superseded
date: 2026-11-14
permalink: sol-sandbox/decisions/2026-11-14-react-router-spa
---

# Decision: React Router SPA

На запит користувача ініціалізовано React Router framework mode з React, TypeScript та Vite у корені репозиторію.

## Observations
- [decision] 2026-11-14: скасовано. Команда перейшла на Roblox ([[Decision: Roblox engine]]), а вебзаготовку (`app/`, `package.json`, конфіги Vite і React Router) видалено з репо на прохання Ярослава. Вона лишилася в історії git (коміт `2d713b5`).
- [decision] `react-router.config.ts` використовує `ssr: false`: результат збірки — статичний сайт у `build/client/`, без production Node.js сервера.
- [fact] Початкова версія React Router — 8.5.1; точні залежності зафіксовано у `package-lock.json`.
- [fact] Команди: `npm run dev`, `npm run typecheck`, `npm run build`, `npm run preview`. Потрібен Node.js 22.12+.
- [fact] React Router потребує `@react-router/node` та `isbot` для стандартного entry і build-time rendering навіть у SPA mode.
- [todo] Для GitHub Pages налаштувати repository base path, router basename та обробку deep links; deployment поки не додано.

## Relations
- part_of [[Mission Console concept]]
- see_also [[Decision: browser TS canvas]]