---
title: 'Decision: git authorship'
type: decision
status: accepted
date: 2026-11-14
permalink: sol-sandbox/decisions/2026-11-14-git-authorship
---

# Decision: git authorship

Агенти ніколи не комітять і не пушать від свого імені. Автор кожного коміту — людина, яка дала задачу.

## Observations
- [decision] Агент комітить або пушить тільки тоді, коли про це прямо просить людина. Він використовує її наявний `git config user.name/email` і нічого в ньому не змінює.
- [decision] Агент не додає жодної AI-атрибуції: ні трейлерів `Co-Authored-By: Claude…`, ні рядків «Generated with Claude Code», ні посилань на сесію в комітах і PR.
- [fact] Вбудована атрибуція Claude Code вимкнена в `.claude/settings.json` (`attribution.commit = ""`, `attribution.pr = ""`, `sessionUrl: false`). Правило записане в `AGENTS.md`, розділ «Git authorship (agents)». `CLAUDE.md` імпортує його через `@AGENTS.md`, тому правило бачать усі агенти.
- [fact] Якщо git identity не налаштовано, агент зупиняється і просить людину налаштувати свою.

## Relations
- part_of [[Index]]
- see_also [[Team roles]]
