---
name: resume
description: Load project context from the kb/ knowledge graph at the start of a session, or when picking up a task another agent or teammate started. Use when the user says "продовжуй", "resume", "підхопи задачу", "що було зроблено", names a task to continue, or opens a fresh session in this repo.
---

# Resume work from the knowledge graph

Goal: get up to speed in a few tool calls without re-reading the whole repo, then continue the work.

1. Orient:
   - `node scripts/kb.mjs recent 5` — latest handoffs and their "Next" steps.
   - `node scripts/kb.mjs context Index` — the project map.
   - If the `basic-memory` MCP tools are available, use `bm_search` / `bm_context` instead of the script for the searches below.
2. If the user named a task (or a handoff matches the current branch `git branch --show-current`):
   - `node scripts/kb.mjs search <task keywords>` to find the task / handoff notes.
   - `node scripts/kb.mjs context "<note title>"` on the most relevant one to pull its neighbours (decisions, data, related tasks).
   - Read the files listed under "Files touched" in the latest handoff before changing them.
3. Check reality vs. notes: `git status`, `git log --oneline -10`. If code and notes disagree, trust the code and fix the note.
4. Tell the user in 3–6 lines: what the task is, what's done, what's next, any open questions/blockers from the graph. Then continue with the first "Next" item unless the user says otherwise.

Do not paste whole notes into chat. Do not invent decisions that are not in the graph; if something is undecided, say so.
