---
name: handoff
description: Save the current session's state into the kb/ knowledge graph so another agent, teammate or a fresh session can continue without loss. Use before ending a session, when context is getting long, before switching agents/models, when the user says "handoff", "збережи контекст", "передай задачу", "закінчуємо", or after finishing a task.
---

# Handoff to the knowledge graph

Write what a fresh agent needs to continue — not a diary of what you did.

1. Gather facts: `git branch --show-current`, `git status --short`, `git log --oneline -5`.
2. Create `kb/handoffs/YYYY-MM-DD-HHMM-<task-slug>.md` (local time, see `date +%Y-%m-%d-%H%M`):

```markdown
---
title: "Handoff: <task> <YYYY-MM-DD HH:MM>"
type: handoff
status: in-progress | blocked | done
branch: <branch>
date: <YYYY-MM-DD>
---

# Handoff: <task> <YYYY-MM-DD HH:MM>

Одне-два речення: що це за задача і в якому вона стані.

## Done
- ...

## Next
1. Перший конкретний крок (файл, функція, команда)
2. ...

## Files touched
- path/to/file.ts — навіщо

## Observations
- [decision] ... (і окрема нотатка в kb/decisions/, якщо рішення важливе для інших)
- [question] ...
- [risk] ...

## Relations
- part_of [[<task note or concept this belongs to>]]
- follows [[<previous handoff title, if any>]]
- see_also [[<decision/data notes used>]]
```

3. If you made a decision others depend on (contract, format, number), also create or update a note in `kb/decisions/` or `kb/data/` and link it. New facts about NASA data always go to `kb/data/` with a URL.
4. Update existing notes that became wrong (e.g. a `[todo]` that is now done) rather than leaving contradictions.
5. Run `node scripts/kb.mjs check` and fix broken links / orphans.
6. Commit the kb changes on the current branch: `git add kb && git commit -m "kb: handoff <task>"` (only if the user allows commits in this session; otherwise tell them the files are ready).
7. Reply with the handoff path and the "Next" list — that is what the next agent will start from.
