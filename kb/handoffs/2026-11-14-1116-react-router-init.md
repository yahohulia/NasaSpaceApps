---
title: 'Handoff: React Router init 2026-11-14 11:16'
type: handoff
status: done
branch: main
date: 2026-11-14
permalink: sol-sandbox/handoffs/2026-11-14-1116-react-router-init
---

# Handoff: React Router init 2026-11-14 11:16

Ініціалізовано мінімальний React Router SPA на запит користувача. Код гри ще не реалізовано; зміни не закомічено.

## Done
- Офіційний starter адаптовано для статичного сайту: React Router 8, React 19, TypeScript, Vite; без Tailwind, Docker та production сервера.
- Додано двомовну стартову сторінку, loading state та error boundary.
- `npm run typecheck` та `npm run build` пройшли; створено `build/client/index.html`.
- Перший typecheck спричинив автоматичне встановлення `isbot` і видалення dev dependencies. `isbot` залишено у manifest, dev dependencies відновлено, повторна перевірка успішна.
- Browser smoke test не виконано: інструмент Playwright у сесії недоступний.

## Next
1. Запустити `npm ci` та `npm run dev`, перевірити стартову сторінку в браузері.
2. Додавати сторінки до `app/routes/` та реєструвати їх у `app/routes.ts`.
3. Перед GitHub Pages deployment налаштувати base path, basename та deep-link fallback.

## Files touched
- `package.json`, `package-lock.json` — залежності та npm scripts.
- `react-router.config.ts`, `vite.config.ts`, `tsconfig.json` — конфігурація SPA та TypeScript.
- `app/root.tsx`, `app/routes.ts`, `app/routes/home.tsx`, `app/app.css` — базова структура застосунку.
- `.gitignore` — generated build та router types.
- `README.md` — запуск, перевірки й обмеження deployment.
- `kb/index.md`, `kb/decisions/2026-11-14-react-router-spa.md` — стан ініціалізації та рішення.

## Relations
- part_of [[Mission Console concept]]
- implements [[Decision: React Router SPA]]