---
title: KB format
type: meta
permalink: sol-sandbox/readme
---

# Як влаштований граф знань

Кожна нотатка — це вузол графа. Посилання `[[Назва нотатки]]` — ребра. Формат сумісний з Basic Memory і Obsidian (теку `kb/` можна відкрити як vault і побачити граф).

## Шаблон нотатки

```markdown
---
title: Унікальна назва          # саме на неї посилаються [[...]]
type: concept | decision | task | handoff | data | team | meta
status: draft | proposed | accepted | done | superseded   # для decision/task
tags: [engine, data]
date: 2026-11-12
---

# Унікальна назва

Коротко: 1–3 речення суті.

## Observations
- [fact] Перевірений факт
- [decision] Що вирішили
- [question] Відкрите питання
- [risk] Ризик
- [todo] Що зробити

## Relations
- part_of [[Батьківська нотатка]]
- depends_on [[Інша нотатка]]
- implements [[Рішення]]
- supersedes [[Старе рішення]]
- see_also [[Пов'язане]]
```

## Правила

- Назва (`title`) унікальна; ім'я файлу — та сама назва в kebab-case.
- Кожна нова нотатка має щонайменше одне посилання **на** вже наявну нотатку (зазвичай `part_of`), інакше вона «висить» поза графом.
- Не переписуй рішення заднім числом: створи нове з `supersedes [[Старе]]`, а старому постав `status: superseded`.
- Цифри про космос — тільки в `kb/data/` і тільки з джерелом (URL).
- Тека → тип: `concept/`, `decisions/` (ім'я `YYYY-MM-DD-slug.md`), `tasks/`, `handoffs/` (`YYYY-MM-DD-HHMM-<task>.md`), `data/`, `team/`.
- Перевірка графа: `node scripts/kb.mjs check`.