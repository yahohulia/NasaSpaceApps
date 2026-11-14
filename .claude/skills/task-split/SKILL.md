---
name: task-split
description: Break a plan, feature or milestone into parallel tasks for several agents/teammates — each with acceptance criteria, owned files and dependencies, so parallel work never collides. Use when the user says "розбий на задачі", "split", "створи задачі/issues", "що можна робити паралельно", plans a milestone (MVP, D+1, D+2), or before launching several agents at once.
---

# Split work into parallel tasks

The biggest risk with 8–10 agents working at once is merge conflicts and duplicated work. A good split prevents both.

## 1. Understand the scope
- Read the relevant notes first (`kb` skill: concept, decisions, open tasks in `kb/tasks/`, latest handoffs).
- Look at the actual code tree (`git ls-files`) — tasks must name real files/folders.
- If the plan has open design questions, list them and ask the user before splitting; don't bake guesses into tasks.

## 2. Design the split
Rules:
- **File ownership:** every task lists the files/folders it may create or change. Two tasks that can run at the same time must not share a file. Shared contracts (types, interfaces, data formats) get their own small task that runs **first**; others depend on it.
- **Size:** one task = one agent session (~1–3 hours). Bigger → split again.
- **Vertical value:** prefer tasks that end in something visible or testable, not "write half a module".
- **Dependencies:** mark `depends_on`; anything without dependencies can start now.
- **Owner role** from `kb/team/roles.md` (Engine, Materials, Gameplay, Data, UI/QA, Design).
- Note which tasks are good for the teammate on free OpenRouter models (well-specified, low-risk: UI, i18n, tests, docs) vs. ones needing a strong model (engine core, tricky physics).

Show the user the split as a table (task · owner · files · depends on · parallel wave) and a short "waves" list (wave 1 can start now, wave 2 after…). Wait for approval before creating anything.

## 3. Create the tasks
For each approved task create `kb/tasks/<slug>.md`:

```markdown
---
title: "Task: <short name>"
type: task
status: todo
owner: <role or name>
wave: 1
---

# Task: <short name>

Що зробити і навіщо — 2–3 речення.

## Files
- src/... (create | change)

## Acceptance criteria
- [todo] Конкретна перевірювана умова
- [todo] `npm run build` проходить, тести зелені

## Observations
- [risk] ...

## Relations
- part_of [[<milestone or concept note>]]
- depends_on [[Task: ...]]
- implements [[Decision: ...]]
```

If the repo has a GitHub remote and `gh auth status` succeeds, also create one issue per task (`gh issue create --title ... --body-file ... --label wave-1,<role>`) and put the issue URL into the task note. Never create issues without the user's approval of the split.

Run `node scripts/kb.mjs check` at the end.

## 4. Launch hint
Finish with ready-to-copy commands for wave 1, one per task, e.g.:
`claude --worktree <slug>` → then in that session: `resume` task "<title>".
