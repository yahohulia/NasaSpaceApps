---
name: kb
description: Read and write the project's knowledge graph in kb/ (concept, decisions, tasks, NASA data facts, team). Use when you need project context, want to record a decision or fact, look up why something was decided, create a task note, or the user mentions "kb", "граф", "запиши рішення", "що ми вирішили про ...".
---

# Project knowledge graph

`kb/` is the team's shared memory: Markdown notes = nodes, `[[Title]]` links = edges. Format and folder rules: `kb/README.md` (read it once before writing).

## Reading
Prefer the `basic-memory` MCP tools when they are available (project `sol-sandbox`):
- `bm_search` — semantic + full-text search (works across Ukrainian/English wording).
- `bm_context` with `memory://sol-sandbox/<path-without-.md>` — a note plus its related notes.
- `bm_read` — one note.

Fallback without MCP (always works):
- `node scripts/kb.mjs list` — all notes with type/status.
- `node scripts/kb.mjs search <text>` — find notes and matching lines.
- `node scripts/kb.mjs context "<title>"` — the note plus summaries of all linked notes. Prefer this over opening many files.
- `node scripts/kb.mjs links "<title>"` — outgoing and incoming edges.

## Writing
- One idea per note; title unique; link it to at least one existing note (`part_of`, `implements`, `depends_on`, `supersedes`, `see_also`).
- Decisions: `kb/decisions/YYYY-MM-DD-slug.md`, `type: decision`, `status: proposed|accepted|superseded`. Never rewrite an accepted decision — add a new one with `supersedes [[Old]]` and mark the old one `superseded`.
- Tasks: `kb/tasks/<slug>.md`, `type: task`, with acceptance criteria as `[todo]` lines.
- NASA numbers: `kb/data/`, each `[fact]` with a source URL and the date checked. Unverified values are `[question]`, never `[fact]`.
- Write either with the normal file tools or with `bm_write`/`bm_edit` (folder = the kb subfolder). Basic Memory adds a `permalink` to frontmatter — that is expected; don't remove it.
- After writing: `node scripts/kb.mjs check`.

Keep notes short (they are loaded into agents' context). Write in Ukrainian; code identifiers in English.
