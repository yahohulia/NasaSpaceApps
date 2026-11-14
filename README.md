# Mission Console — NASA Space Apps 2026

Junior Astronaut Mission Trainer. This repository currently contains a minimal React Router framework-mode SPA with React, TypeScript and Vite; game features are not implemented yet.

## Requirements

- Node.js 22.12+ (Node.js 24 LTS recommended)
- npm

## Development

```sh
npm ci
npm run dev
```

Open the local URL printed by the development server (normally http://localhost:5173).

## Checks and production build

```sh
npm run typecheck
npm run build
npm run preview
```

The static site is generated in `build/client/`. No production Node.js server is required (`ssr: false`). The root route is still rendered at build time, so avoid browser-only APIs during initial render; use effects for browser-dependent code.

## App structure

- `app/root.tsx` — document layout, loading state and error boundary
- `app/routes.ts` — route configuration
- `app/routes/home.tsx` — bilingual starter page
- `app/app.css` — base styles
- `react-router.config.ts` — SPA configuration
- `vite.config.ts` — Vite integration

Add route modules under `app/routes/` and register them in `app/routes.ts`.

## Static deployment

Deploy `build/client/`. Hosts must serve `index.html` for client-side routes. GitHub Pages deployment is not configured yet; when deploying to a repository subpath, configure matching Vite `base` and React Router `basename` values, plus a fallback strategy for deep links.

## Project context

Read `CLAUDE.md` for project rules and `kb/index.md` for shared knowledge, concepts and decisions.
