#!/usr/bin/env node
// Tiny knowledge-graph tool for kb/. No dependencies.
// Usage: node scripts/kb.mjs <search|links|context|recent|check|list> [args]
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const KB = join(ROOT, "kb");

function walk(dir) {
  return readdirSync(dir).flatMap((n) => {
    const p = join(dir, n);
    return statSync(p).isDirectory() ? walk(p) : n.endsWith(".md") ? [p] : [];
  });
}

function parse(path) {
  const text = readFileSync(path, "utf8");
  const fm = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  const meta = {};
  if (fm) for (const line of fm[1].split(/\r?\n/)) {
    const m = line.match(/^(\w+):\s*(.*?)\s*(#.*)?$/);
    if (m) meta[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
  const body = fm ? text.slice(fm[0].length) : text;
  const title = meta.title || body.match(/^#\s+(.+)$/m)?.[1] || path;
  const links = [];
  for (const line of body.replace(/```[\s\S]*?```/g, "").replace(/`[^`\n]*`/g, "").split(/\r?\n/)) {
    for (const m of line.matchAll(/\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]/g)) {
      const rel = line.match(/^\s*-\s+(\w+)\s+\[\[/)?.[1] || "mentions";
      links.push({ to: m[1].trim(), rel });
    }
  }
  const summary = body.replace(/^#.*$/m, "").trim().split(/\r?\n\r?\n/)[0].trim();
  return { path: relative(ROOT, path).replace(/\\/g, "/"), title, meta, body, links, summary };
}

const notes = walk(KB).map(parse);
const byTitle = new Map(notes.map((n) => [n.title.toLowerCase(), n]));
const find = (t) => byTitle.get(String(t).toLowerCase()) ||
  notes.find((n) => n.title.toLowerCase().includes(String(t).toLowerCase()));
const backlinks = (n) => notes.flatMap((o) => o.links.filter((l) => l.to.toLowerCase() === n.title.toLowerCase()).map((l) => ({ from: o, rel: l.rel })));

const [cmd, ...args] = process.argv.slice(2);
const q = args.join(" ");

switch (cmd) {
  case "list":
    for (const n of notes) console.log(`${(n.meta.type || "-").padEnd(9)} ${(n.meta.status || "").padEnd(10)} ${n.title}  (${n.path})`);
    break;
  case "search": {
    if (!q) { console.log("usage: search <text>"); break; }
    const needle = q.toLowerCase();
    for (const n of notes) {
      const hits = n.body.split(/\r?\n/).filter((l) => l.toLowerCase().includes(needle));
      if (n.title.toLowerCase().includes(needle) || hits.length) {
        console.log(`# ${n.title}  (${n.path})`);
        for (const h of hits.slice(0, 5)) console.log("   " + h.trim());
      }
    }
    break;
  }
  case "links": {
    const n = find(q); if (!n) { console.log(`not found: ${q}`); break; }
    console.log(`# ${n.title}  (${n.path})`);
    console.log("outgoing:"); for (const l of n.links) console.log(`  ${l.rel} -> [[${l.to}]]${find(l.to) ? "" : "  (MISSING)"}`);
    console.log("incoming:"); for (const b of backlinks(n)) console.log(`  [[${b.from.title}]] ${b.rel} ->`);
    break;
  }
  case "context": {
    // Print a note in full plus one-paragraph summaries of its neighbours.
    const n = find(q); if (!n) { console.log(`not found: ${q}`); break; }
    console.log(`===== ${n.title} (${n.path}) =====\n${n.body.trim()}\n`);
    const seen = new Set([n.title]);
    const neigh = [...n.links.map((l) => [l.rel, find(l.to)]), ...backlinks(n).map((b) => [`<-${b.rel}`, b.from])];
    for (const [rel, m] of neigh) {
      if (!m || seen.has(m.title)) continue; seen.add(m.title);
      console.log(`--- ${rel} [[${m.title}]] (${m.path})\n${m.summary}\n`);
    }
    break;
  }
  case "recent": {
    const k = Number(args[0]) || 5;
    const hs = notes.filter((n) => n.meta.type === "handoff").sort((a, b) => b.path.localeCompare(a.path)).slice(0, k);
    if (!hs.length) console.log("no handoffs yet");
    for (const h of hs) {
      const next = h.body.match(/##\s*Next[^\n]*\n([\s\S]*?)(\n##|$)/i)?.[1].trim() || "";
      console.log(`# ${h.title}  (${h.path})  status=${h.meta.status || "-"}\n${next}\n`);
    }
    break;
  }
  case "check": {
    let bad = 0;
    const titles = new Map();
    for (const n of notes) {
      const t = n.title.toLowerCase();
      if (titles.has(t)) { bad++; console.log(`DUPLICATE title "${n.title}": ${titles.get(t)} and ${n.path}`); }
      titles.set(t, n.path);
      for (const l of n.links) if (!byTitle.has(l.to.toLowerCase())) { bad++; console.log(`BROKEN ${n.path}: [[${l.to}]]`); }
      if (n.title !== "Index" && !n.links.length && !backlinks(n).length) { bad++; console.log(`ORPHAN ${n.path}`); }
    }
    console.log(bad ? `${bad} problem(s)` : `ok: ${notes.length} notes, ${notes.reduce((s, n) => s + n.links.length, 0)} links`);
    process.exitCode = bad ? 1 : 0;
    break;
  }
  default:
    console.log("usage: node scripts/kb.mjs <list | search <text> | links <title> | context <title> | recent [n] | check>");
}
