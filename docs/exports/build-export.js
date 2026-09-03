#!/usr/bin/env node
/* Build the Word export of the SpendTracker design, process and controls from the markdown docs.
 * Diagrams: every ```mermaid block whose heading carries a (D-XXX) id is rendered with Chromium.
 * Tables: read from the source documents at build time (tableAfter), so the export tracks the docs.
 * Usage: node build-export.js   (writes SpendTracker-Design-Process-Controls.docx next to this file) */
'use strict';
const fs = require('fs'); const path = require('path'); const os = require('os'); const cp = require('child_process');
const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(__dirname, 'SpendTracker-Design-Process-Controls.docx');
function req(name) { try { return require(name); } catch (e) { return require(require.resolve(name, { paths: [path.join(process.env.NODE_PATH || '/opt/node22/lib/node_modules'), __dirname] })); } }
const docx = req('docx');
const { Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, WidthType, ShadingType, ImageRun,
  PageBreak, TableOfContents, AlignmentType, BorderStyle, Footer, Header, PageNumber, LevelFormat, PageOrientation, VerticalAlign } = docx;

// ---------- markdown helpers ----------
const read = (rel) => fs.readFileSync(path.join(ROOT, rel), 'utf8');
const lines = (rel) => read(rel).split('\n');
const PIPE = '__ESCAPED_PIPE__';
function tableAfter(rel, anchor, nth = 0) {
  const ls = lines(rel); let i = ls.findIndex((l) => l.includes(anchor));
  if (i < 0) throw new Error(`anchor not found: ${rel} ${anchor}`);
  for (let k = 0; k <= nth; k++) { while (i < ls.length && !ls[i].startsWith('|')) i++; if (k < nth) { while (i < ls.length && ls[i].startsWith('|')) i++; } }
  const rows = []; while (i < ls.length && ls[i].startsWith('|')) { rows.push(ls[i]); i++; }
  const parse = (l) => l.split('\\|').join(PIPE).replace(/^\||\|$/g, '').split('|').map((c) => c.split(PIPE).join('|').trim());
  return rows.filter((r) => !/^\|(\s*:?-+:?\s*\|)+$/.test(r)).map(parse);
}
function listAfter(rel, anchor) { // consecutive bullet or numbered items (with continuation lines) after an anchor
  const ls = lines(rel); let i = ls.findIndex((l) => l.includes(anchor)); if (i < 0) throw new Error(`anchor not found: ${rel} ${anchor}`);
  i++; while (i < ls.length && !/^\s*(-|\d+\.)\s/.test(ls[i])) i++;
  const items = []; while (i < ls.length && (/^\s*(-|\d+\.)\s/.test(ls[i]) || /^\s{2,}\S/.test(ls[i]))) {
    if (/^\s*(-|\d+\.)\s/.test(ls[i])) items.push(ls[i].replace(/^\s*(-|\d+\.)\s/, '')); else items[items.length - 1] += ' ' + ls[i].trim(); i++; }
  return items;
}
function sliceSummary() { // Slice, Goal, Exit criteria from VERTICAL-SLICES.md
  const ls = lines('docs/02-delivery/VERTICAL-SLICES.md'); const out = []; let cur = null;
  for (const l of ls) { const m = l.match(/^## (S\d) — (.+)$/); if (m) { cur = { id: m[1], name: m[2], goal: '', exit: '' }; out.push(cur); continue; }
    if (!cur) continue; const g = l.match(/^- \*\*Goal\*\*: (.+)$/); if (g) cur.goal = g[1]; const e = l.match(/^- \*\*Exit criteria\*\*: (.+)$/); if (e) cur.exit = e[1]; }
  return out;
}
const mono = { font: 'Consolas', size: 18 };
function inline(text, base = {}) { // `code`, **bold**, *italic*, [text](url), ~~x~~ -> runs
  const runs = []; let s = text.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1').replace(/~~([^~]+)~~/g, '$1');
  const re = /(`[^`]+`|\*\*[^*]+\*\*|\*[^*]+\*)/g; let last = 0; let m;
  while ((m = re.exec(s))) { if (m.index > last) runs.push(new TextRun({ text: s.slice(last, m.index), ...base }));
    const t = m[0]; if (t.startsWith('`')) runs.push(new TextRun({ text: t.slice(1, -1), ...base, ...mono, size: base.size ? base.size - 2 : 19 }));
    else if (t.startsWith('**')) runs.push(new TextRun({ text: t.slice(2, -2), ...base, bold: true })); else runs.push(new TextRun({ text: t.slice(1, -1), ...base, italics: true })); last = m.index + t.length; }
  if (last < s.length) runs.push(new TextRun({ text: s.slice(last), ...base })); return runs;
}

// ---------- diagrams ----------
function extractDiagrams() {
  const found = {}; const walk = (d) => { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) walk(p); else if (e.name.endsWith('.md')) scan(p); } };
  const scan = (p) => { const ls = fs.readFileSync(p, 'utf8').split('\n'); let heading = '';
    for (let i = 0; i < ls.length; i++) { if (ls[i].startsWith('#')) heading = ls[i]; if (ls[i].trim() === '```mermaid') { const body = []; let j = i + 1; while (j < ls.length && ls[j].trim() !== '```') body.push(ls[j++]);
      const m = heading.match(/\((D-[A-Z0-9-]+)\)/); if (m) found[m[1]] = { src: body.join('\n'), file: path.relative(ROOT, p) }; i = j; } } };
  walk(path.join(ROOT, 'docs')); return found;
}
function laneVariants(diagrams) { // D-LIFECYCLE is two lanes; render each lane left-to-right so it fits a landscape page
  const src = diagrams['D-LIFECYCLE'].src.split('\n'); const lane = (tag) => { const out = ['flowchart LR']; let on = false; for (const l of src) { if (l.trim().startsWith(`subgraph ${tag}[`)) { on = true; continue; } if (on && l.trim() === 'end') break; if (on && !l.trim().startsWith('direction')) out.push(l); } return out.join('\n'); };
  diagrams['D-LIFECYCLE-BUILDER'] = { src: lane('B'), file: diagrams['D-LIFECYCLE'].file }; diagrams['D-LIFECYCLE-FABLE'] = { src: lane('F'), file: diagrams['D-LIFECYCLE'].file };
}
async function render(diagrams, dir) {
  const { chromium } = req('playwright'); const mermaidSrc = fs.readFileSync(require.resolve('mermaid/dist/mermaid.min.js', { paths: [__dirname, path.join(process.env.NODE_PATH || '', '..')] }), 'utf8');
  const launch = process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}; const browser = await chromium.launch(launch);
  const page = await browser.newPage({ deviceScaleFactor: 2, viewport: { width: 6000, height: 6000 } });
  await page.setContent('<html><body style="margin:0;background:white"><div id="d"></div></body></html>'); await page.addScriptTag({ content: mermaidSrc });
  await page.evaluate(() => mermaid.initialize({ startOnLoad: false, theme: 'neutral', securityLevel: 'loose', fontFamily: 'Helvetica, Arial, sans-serif', flowchart: { htmlLabels: true, curve: 'basis', useMaxWidth: false }, sequence: { useMaxWidth: false }, gantt: { useMaxWidth: false }, er: { useMaxWidth: false }, class: { useMaxWidth: false }, state: { useMaxWidth: false } }));
  for (const [id, d] of Object.entries(diagrams)) {
    if (d.src.trim().startsWith('gantt')) await page.setViewportSize({ width: 1500, height: 1500 }); else await page.setViewportSize({ width: 6000, height: 6000 });
    const size = await page.evaluate(async ([id, src]) => { const r = await mermaid.render('m_' + id.replace(/[^a-z0-9]/gi, '_'), src); document.getElementById('d').innerHTML = r.svg; const s = document.querySelector('#d svg'); s.style.maxWidth = 'none'; const b = s.getBoundingClientRect(); return { w: b.width, h: b.height }; }, [id, d.src]);
    const el = await page.$('#d svg'); const png = path.join(dir, id + '.png'); await el.screenshot({ path: png }); d.png = png; d.w = size.w; d.h = size.h; console.log('rendered', id, Math.round(size.w) + 'x' + Math.round(size.h));
  }
  await browser.close();
}

// ---------- docx helpers ----------
const PORTRAIT_W = 9360, LANDSCAPE_W = 13680; // content width in DXA at 1in margins
const blocks = []; // {wide:false, el} | {wide:true, els:[...]}
const add = (...els) => els.forEach((el) => blocks.push({ wide: false, el }));
const H1 = (t) => add(new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun(t)], pageBreakBefore: true }));
const H2 = (t) => add(new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun(t)] }));
const H3 = (t) => add(new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun(t)] }));
const P = (t, opts = {}) => add(new Paragraph({ children: inline(t, { size: 21 }), spacing: { after: 120 }, ...opts }));
const Bullets = (items) => items.forEach((t) => add(new Paragraph({ children: inline(t, { size: 21 }), numbering: { reference: 'bullets', level: 0 }, spacing: { after: 60 } })));
const numberingConfigs = [{ reference: 'bullets', levels: [{ level: 0, format: LevelFormat.BULLET, text: '\u2022', alignment: AlignmentType.START, style: { paragraph: { indent: { left: 540, hanging: 360 } } } }] }];
let numRefs = 0; const numberedList = (items) => { const ref = 'num' + (++numRefs); numberingConfigs.push({ reference: ref, levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.START, style: { paragraph: { indent: { left: 540, hanging: 360 } } } }] }); items.forEach((t) => add(new Paragraph({ children: inline(t, { size: 21 }), numbering: { reference: ref, level: 0 }, spacing: { after: 60 } }))); };
const border = { style: BorderStyle.SINGLE, size: 4, color: 'BFBFBF' }; const borders = { top: border, bottom: border, left: border, right: border };
function table(rows, opts = {}) {
  const wide = !!opts.wide; const total = wide ? LANDSCAPE_W : PORTRAIT_W; const ncol = Math.max(...rows.map((r) => r.length));
  const weights = opts.widths || Array.from({ length: ncol }, (_, c) => Math.max(6, Math.min(40, Math.max(...rows.map((r) => (r[c] || '').length)))));
  const sum = weights.reduce((a, b) => a + b, 0); const cw = weights.map((w) => Math.round((w / sum) * total)); cw[cw.length - 1] += total - cw.reduce((a, b) => a + b, 0);
  const mk = (r, head) => new TableRow({ tableHeader: head, children: r.concat(Array(ncol - r.length).fill('')).map((c, i) => new TableCell({ width: { size: cw[i], type: WidthType.DXA }, borders, verticalAlign: VerticalAlign.TOP, margins: { top: 40, bottom: 40, left: 80, right: 80 },
    shading: head ? { type: ShadingType.CLEAR, fill: 'E7EEF5', color: 'auto' } : undefined, children: [new Paragraph({ children: inline(c, { size: 18, bold: head }), spacing: { after: 0 } })] })) });
  const t = new Table({ width: { size: total, type: WidthType.DXA }, columnWidths: cw, rows: [mk(rows[0], true), ...rows.slice(1).map((r) => mk(r, false))] });
  if (wide) blocks.push({ wide: true, els: [t, new Paragraph({ children: [], spacing: { after: 120 } })] }); else add(t, new Paragraph({ children: [], spacing: { after: 120 } }));
}
function figure(diagrams, id, caption, force) {
  const d = diagrams[id]; if (!d || !d.png) throw new Error('missing diagram ' + id);
  const wide = force === 'wide' || (force !== 'tall' && d.w / d.h >= 1.35 && d.w > 900); const boxW = wide ? 912 : 624; const boxH = wide ? 560 : 800;
  const scale = Math.min(boxW / d.w, boxH / d.h, 1); const w = Math.round(d.w * scale), h = Math.round(d.h * scale);
  const els = [new Paragraph({ alignment: AlignmentType.CENTER, children: [new ImageRun({ type: 'png', data: fs.readFileSync(d.png), transformation: { width: w, height: h } })], spacing: { before: 120, after: 60 } }),
    new Paragraph({ alignment: AlignmentType.CENTER, children: inline(`${id}: ${caption} (source: ${d.file})`, { size: 18, italics: true, color: '555555' }), spacing: { after: 200 } })];
  if (wide) blocks.push({ wide: true, els }); else add(...els);
}

// ---------- content ----------
function build(diagrams) {
  const commit = cp.execSync('git rev-parse --short HEAD', { cwd: ROOT }).toString().trim(); const today = new Date().toISOString().slice(0, 10);
  add(new Paragraph({ children: [new TextRun({ text: 'SpendTracker', size: 72, bold: true, color: '1F3B57' })], spacing: { before: 2400, after: 200 }, alignment: AlignmentType.CENTER }),
    new Paragraph({ children: [new TextRun({ text: 'Design, development process and controls', size: 40, color: '1F3B57' })], alignment: AlignmentType.CENTER, spacing: { after: 600 } }),
    new Paragraph({ children: [new TextRun({ text: 'Multi-layer spend tracking for a developer stack: Claude Code, the Claude API, GitHub, GitHub Copilot, CodeRabbit, MCP servers and any layer added later. Built by two kinds of Claude Code sessions that check and gate each other\u2019s work.', size: 24, color: '444444' })], alignment: AlignmentType.CENTER, spacing: { after: 1200 } }),
    new Paragraph({ children: [new TextRun({ text: `Generated ${today} from repository commit ${commit} by docs/exports/build-export.js. Every diagram and most tables are read from the markdown documents under docs/; the documents remain the source of truth.`, size: 20, italics: true, color: '666666' })], alignment: AlignmentType.CENTER }),
    new Paragraph({ children: [new PageBreak()] }),
    new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun('Contents')] }),
    new TableOfContents('Contents', { hyperlink: true, headingStyleRange: '1-2' }));

  H1('1. Summary');
  P('**What it is.** SpendTracker records what every tool in a developer stack consumes, in that tool\u2019s own unit (tokens, minutes, requests, sessions, actions, credits, reviews), and translates it into money. Everything runs locally first: collectors write usage events into a per-user SQLite database, a pricer turns events into cost lines using effective-dated rate cards and subscriptions, and a local web UI shows trends by app, by measure type and in real currency after subscriptions and budgets are applied. Each user can export append-only files to a shared git repository where a rollup job builds a team view.');
  P('**How it is built.** The repository is worked on by short Claude Code sessions in two roles. The **Fable session** (the most capable model) is architect, reviewer and gate: it answers questions, curates the ledgers, writes one task packet per builder session, verifies CI and acceptance criteria, and is the only session that merges. **Builder sessions** (other models) each take one packet, build it end to end on their own branch and draft PR, and stop. Only Fable holds the full context; a builder sees its packet and what the packet lists. Hooks enforce the roles inside Claude Code, CI enforces the PR-author rule and runs tiered tests scoped by blast radius, and branch protection on `main` is the backstop.');
  P('**What this document contains.** Sections 2 to 8 describe the system design (architecture, data model, cost model, collectors, rollup, web UI, security). Sections 9 to 12 describe the delivery plan, the development process, the controls and the testing and CI strategy. Section 13 describes the work packages and what is expected of every session from start to end. Section 14 records the alignment review that produced this revision.');
  H2('1.1 Design decisions at a glance');
  table(tableAfter('docs/README.md', '## Architecture Decision Records'));
  H2('1.2 The one-paragraph design');
  P('Every app is a **layer**. Every layer emits **usage events** in its native **measure**. Events land in one canonical fact table in a local SQLite file. A **pricer** turns events into **cost lines** using effective-dated **rate cards** and **subscriptions**, producing both a *list* cost (pay-as-you-go price) and an *effective* cost (the share of a flat subscription the usage actually consumed, plus any overage). **Budgets** compare effective cost against allocations. A local web UI renders all of it. **Adapters** are the only per-app code; adding a layer means adding an adapter and a rate card. **Export** produces append-only files that a shared repository rolls up across users.');

  H1('2. System architecture');
  H2('2.1 Goals and how the architecture meets them');
  table(tableAfter('docs/01-architecture/ARCHITECTURE.md', '## 1. Goals and constraints'));
  P('Non-goals for the first releases: real-time streaming dashboards, enforcing spend limits inside the tools, and scraping vendor invoices from web portals.');
  H2('2.2 System context');
  P('A SpendTracker node runs on each developer machine. Push sources (Claude Code hooks and OpenTelemetry export, MCP hooks or proxy) write into it within seconds; pull sources (vendor billing APIs) are collected on a schedule; CSV and manual entries cover everything else. The node exports to a rollup repository that a team lead browses.');
  figure(diagrams, 'D-CTX', 'System context');
  H2('2.3 Containers');
  P('`st serve` is one process hosting the web UI, the OTLP receiver, the spool watcher and, optionally, the scheduler. Every other command is a short-lived process that opens the same SQLite file. Hooks are shell scripts that only write files; they finish in milliseconds and never block Claude Code.');
  figure(diagrams, 'D-CONT', 'Container view');
  H2('2.4 The data path');
  P('Every mechanism ends in the same place: a raw payload is normalized by adapter code into usage-event DTOs, validated (registered measure, UTC time, non-negative quantity, stable source reference), de-duplicated on app + source + source reference + measure, written, priced into cost lines, and read by SQL views that feed the JSON API and the pages.');
  figure(diagrams, 'D-COMP', 'Component view of the data path', 'wide');
  H2('2.5 Domain model');
  figure(diagrams, 'D-CLASS', 'UML class model of the domain');
  H2('2.6 Key flows');
  P('The Claude Code hook path shows the decoupling that keeps hooks fast: the hook writes a spool file and exits; the ingester drains the spool, normalizes, inserts with duplicates ignored, and the pricer and UI read from the database.');
  figure(diagrams, 'D-SEQ-HOOK', 'Claude Code hook to dashboard', 'wide');
  P('Scheduled API pulls keep a cursor per adapter in `adapter_state`, insert with de-duplication on the source reference, record a `collector_run` row and price the new events.');
  figure(diagrams, 'D-SEQ-PULL', 'Scheduled API pull', 'wide');
  P('A collector run moves through a fixed lifecycle; failures retry with backoff and never advance the cursor.');
  figure(diagrams, 'D-STATE', 'Collector run lifecycle', 'tall');
  H2('2.7 Layering rules');
  numberedList(listAfter('docs/01-architecture/ARCHITECTURE.md', '## 7. Layering rules'));
  H2('2.8 Cross-cutting concerns');
  table(tableAfter('docs/01-architecture/ARCHITECTURE.md', '## 9. Cross-cutting concerns'));

  H1('3. Data model');
  P('The DDL in `schema/001_core.sql` is the source of truth; `docs/01-architecture/DATA-MODEL.md` explains it. Every table exists in both the local database and the rollup database. Money is stored as integer micro-units with a currency code, prices as integer nano-units per unit; timestamps are UTC ISO-8601.');
  figure(diagrams, 'D-ERD', 'Entity relationship diagram');
  H2('3.1 Reference tables, facts and pricing');
  table(tableAfter('docs/01-architecture/DATA-MODEL.md', '### Reference tables'));
  table(tableAfter('docs/01-architecture/DATA-MODEL.md', '### Facts'));
  table(tableAfter('docs/01-architecture/DATA-MODEL.md', '### Pricing'));
  H2('3.2 Initial measure catalogue');
  table(tableAfter('docs/01-architecture/DATA-MODEL.md', '## 3. Measure catalogue'));
  H2('3.3 Attribution and migration policy');
  numberedList(listAfter('docs/01-architecture/DATA-MODEL.md', '## 4. Attribution rules'));
  Bullets(listAfter('docs/01-architecture/DATA-MODEL.md', '## 6. Migration policy'));

  H1('4. Cost model');
  P('Three cost kinds are kept apart (ADR-0003): **list** (quantity times the rate-card price), **reported** (an amount the source itself supplied) and **effective** (allocated share of a subscription fee plus overage where a subscription covers the event, otherwise reported if present, otherwise list). Cost lines are derived data and can be recomputed at any time; usage events are never touched.');
  figure(diagrams, 'D-COST', 'Cost derivation pipeline');
  H2('4.1 Definitions');
  table(tableAfter('docs/01-architecture/COST-MODEL.md', '## 2. Definitions'));
  H2('4.2 Allocation methods');
  table(tableAfter('docs/01-architecture/COST-MODEL.md', '## 3. Allocation methods'));
  H2('4.3 Worked example: Claude Max under usage share');
  table(tableAfter('docs/01-architecture/COST-MODEL.md', '## 4. Worked example'));
  P('If the same month had only two requests totalling $3 of list cost, effective cost would still sum to the $100 fee and the Apps page would show a utilization ratio of 3 %, the signal to downgrade. Budgets compare effective cost (including idle lines) against an amount per scope and period; thresholds fire once per period; budgets are informational and never block a tool.');

  H1('5. Collectors and adapters');
  P('Each layer is integrated by an adapter, the only code that knows about a specific app. The mechanisms below all end in the same envelope in the spool or a direct call to the ingest layer.');
  table(tableAfter('docs/01-architecture/COLLECTORS.md', '## 0. Mechanisms'));
  H2('5.1 The adapter contract');
  P('An adapter is a directory with a manifest (`adapter.yaml`), a module implementing `discover`, `collect`, `normalize` and `health`, recorded fixtures and the events they must produce. A shared conformance suite (`st adapter test`) replays the fixtures and enforces the contract (ADR-0005). Push adapters (hooks, OTLP, proxy) implement only `normalize` and `health`.');
  table(tableAfter('docs/01-architecture/ADAPTER-SPEC.md', '## 4. Contract'));
  P('Out-of-process adapters in other languages write envelopes to the spool or `POST /api/v1/ingest`; they still ship a manifest and fixtures. The target for slice S7 is a new pull adapter in under one hour from the scaffold.');

  H1('6. Multi-user rollup');
  P('Each node exports append-only JSONL batches per month with a manifest (event count, first and last event id, SHA-256, redaction level). Batches are committed to a rollup repository by pull request or by direct push to a per-node branch; CI validates on PR and, on merge, rebuilds `rollup.db` with the same schema and re-prices every period with the team\u2019s rate cards, subscriptions and budgets so everyone is priced consistently (ADR-0004). Cost lines are not exported; raw payloads and transcripts never are.');
  figure(diagrams, 'D-ROLLUP', 'Multi-user rollup flow', 'wide');
  H2('6.1 Redaction levels applied at export');
  table(tableAfter('docs/01-architecture/AGGREGATION.md', '## 6. Privacy and redaction levels'));
  P('The rollup adds team-level views: by user, by project (chargeback with weights), subscription utilization (seats paid versus active versus usage) and node freshness. Per-event rows older than 13 months are compacted to daily aggregates.');

  H1('7. Local web interface');
  P('`st serve` binds to `127.0.0.1:8787` only, with no authentication. Pages are server-rendered with htmx partials and Chart.js; all numbers come from SQL views. The same page templates render the static team site for the rollup repository.');
  figure(diagrams, 'D-UI', 'UI navigation map');
  table(tableAfter('docs/01-architecture/WEB-UI.md', '## 2. Pages'), { wide: true });
  P('All money in the JSON API is `{ "micros": n, "currency": "USD" }`; the UI formats. Effective cost is always the solid series, list cost dashed, reported dotted. No external network requests are made from the UI: fonts, scripts and Chart.js are vendored.');

  H1('8. Security and privacy');
  P('The threat model is local-first tooling on developer machines holding usage metadata, vendor tokens by reference and, optionally, raw API payloads. The main risks are tokens leaking into the database or exports, prompt or code content leaking through attributes or raw payloads, and the local UI being exposed to the network.');
  table(tableAfter('docs/01-architecture/SECURITY-PRIVACY.md', '## Rules'));
  H2('8.1 Data classification');
  table(tableAfter('docs/01-architecture/SECURITY-PRIVACY.md', '## Data classification'));

  H1('9. Delivery plan');
  H2('9.1 Capabilities');
  P('Each capability is independently buildable, testable and shippable behind its own CLI command, page or adapter. Vertical slices pick a thin path through several of them. No two capabilities write the same table except through the ingest layer and the pricer.');
  figure(diagrams, 'D-CAPDEP', 'Capability dependency graph', 'wide');
  table(tableAfter('docs/02-delivery/CAPABILITIES.md', '## Catalogue'), { wide: true });
  H2('9.2 Vertical slices');
  P('Slices are ordered so that each is usable on its own and the riskiest assumptions (hooks work, allocation math is right, rollup is idempotent) are tested early. A slice is delivered as one or more builder session packets, each sized to one 40-prompt session.');
  figure(diagrams, 'D-SLICES', 'Vertical slices timeline', 'wide');
  table([['Slice', 'Goal', 'Exit criteria'], ...sliceSummary().map((s) => [`${s.id} ${s.name}`, s.goal, s.exit])]);
  H2('9.3 The phase playbook');
  P('A phase is one pass through a slice, or a research, redesign or update effort. Context does not survive between sessions unless it is written down in known places, so every phase follows the same nine steps and ends with the Fable session updating `CONTEXT.md` and writing the next packet.');
  figure(diagrams, 'D-PHASE', 'Phase steps', 'wide');
  table(tableAfter('docs/02-delivery/PHASE-PLAYBOOK.md', '## The context contract'));

  H1('10. Development process: two roles that gate each other');
  P('Work is divided between the **Fable session** (lead: architect, project manager, designer, the owner\u2019s delegate) and **builder sessions** (developer and tester for one packet). The division exists so that the model that designs and reviews is not the model that builds, and so that every piece of work passes through a reviewer with the full context before it reaches `main`. The mechanics are decided in ADR-0007, ADR-0008, ADR-0009 and ADR-0010, specified in `docs/02-delivery/SESSION-PROTOCOL.md` and enforced by the hooks in `.claude/hooks/`; `docs/PROCESS.md` adds the division of labour and the packet contract.');
  H2('10.1 Roles');
  table(tableAfter('docs/PROCESS.md', '## 1. Roles'), { wide: true });
  H2('10.2 Session lifecycle, start to end');
  P('A builder session starts with the role bound by the hook and its own queue entry injected, reads its packet, builds one checkpoint at a time (each ending green and pushed), asks when something is missing, and ends with the close-out before its 40th prompt. A Fable session starts with the full context, answers, curates, reviews each PR against its packet, merges or sends it back, updates the ledger and writes the next packet.');
  figure(diagrams, 'D-LIFECYCLE-BUILDER', 'Builder session lifecycle', 'wide');
  figure(diagrams, 'D-LIFECYCLE-FABLE', 'Fable session lifecycle', 'wide');
  H2('10.3 What each session must produce');
  table(tableAfter('docs/02-delivery/SESSION-PROTOCOL.md', '### What each session must produce'), { wide: true });
  H2('10.4 Interaction between owner, Fable, builder, CI and the ledgers');
  figure(diagrams, 'D-SESSION', 'Session interaction', 'wide');
  H2('10.5 The task packet');
  P('Fable writes one packet per builder session. A builder starts with no memory of anything, so the packet stands alone with the documents it lists. Its sections, in order:');
  add(new Paragraph({ children: [new TextRun({ text: read('docs/PROCESS.md').split('```')[1].trim(), ...mono, size: 17 })], spacing: { after: 160 }, indent: { left: 360 } }));
  P('Packets in flight at the same time have disjoint file lists. A packet is sized to one session; its checkpoints make it resumable by the next session when the prompt limit is reached.');
  H2('10.6 Questions, close log and Fable\u2019s verification');
  Bullets(listAfter('docs/PROCESS.md', '## 5. Question protocol'));
  P('The close log carries an acceptance-criteria table (MET, NOT MET or UNVERIFIED with evidence), deviations, assumptions and spend. Fable treats it as a report to verify, not as truth: it checks out the PR head, runs lint, type check and all three tiers itself, runs every acceptance criterion, reads the diff against the file list and for architectural fit, and confirms the CI blast radius, the PR author, answered questions and recorded issues. Outcomes are **Accept** (merge with a merge commit, entry done), **Rework** (numbered findings in the queue entry, same branch) or **Redesign** (docs and ADR first, new packet). Fable advises and directs; it never makes the code change itself.');
  H2('10.7 Human decision rights');
  P('Fable stops and asks the owner for:');
  Bullets(listAfter('docs/PROCESS.md', '## 10. Human decision rights'));

  H1('11. Context separation and controls');
  H2('11.1 The context boundary');
  P('Only the Fable session holds the full context (ADR-0010). A builder\u2019s context is `PROCESS.md`, its packet, the documents the packet lists, and the excerpt the start hook injects. This is deliberate: for **quality**, a builder that reads a packet builds to acceptance criteria instead of reinterpreting the design; for **security**, builder sessions run on less capable models and act under the owner\u2019s identity, so limiting what they can see and act on (other builders\u2019 unreviewed branches, the decisions log, owner next actions, other packets) limits what a confused or misdirected session can do, and keeps unreviewed content on one branch out of another session\u2019s context.');
  figure(diagrams, 'D-CONTEXT', 'Context boundary between the roles', 'tall');
  table(tableAfter('docs/02-delivery/SESSION-PROTOCOL.md', '| Material | Fable | Builder |'));
  H2('11.2 How a session gets its role');
  P('ADR-0009 fixes the order of precedence. A role observed from the model or set by the owner is never changed by a prompt; a session that the platform reports no model for is undeclared and fails closed until a prompt states its role; the first declaration binds for the whole session and is marked in the log for audit.');
  table(tableAfter('docs/00-context/adr/ADR-0009-session-role-determination.md', '## Decision'));
  H2('11.3 Gates between a builder branch and main');
  figure(diagrams, 'D-GATES', 'Gates between a builder branch and main', 'wide');
  P('**Gate 1, hooks** (inside Claude Code): role binding, the packet boundary, ledger writes, merges and protected branches. **Gate 2, CI**: the PR-author job, tiered tests selected by blast radius, adapter conformance, schema snapshot, docs checks and an installable build. **Gate 3, the Fable review**: acceptance criteria on the head commit, blast radius covered, questions answered, issues recorded, diff inside the file list. **Gate 4, branch protection**: pull request required, required checks, no force push, no bypass actors (`.github/rulesets/`).');
  H2('11.4 Enforcement map');
  table(tableAfter('docs/02-delivery/SESSION-PROTOCOL.md', '## Enforcement map'), { wide: true });
  H2('11.5 The ledgers');
  table(tableAfter('docs/02-delivery/SESSION-PROTOCOL.md', '## Ledger files'), { wide: true });
  H2('11.6 What the hooks cannot enforce');
  Bullets(listAfter('docs/02-delivery/SESSION-PROTOCOL.md', '## What the hooks cannot enforce'));
  H2('11.7 Branch protection');
  P('Rulesets cannot be created from a Claude Code session, so the owner applies `.github/rulesets/main-protection.json` now (pull request required, no direct pushes, no force pushes, no deletion) and switches the same ruleset to `main-protection-with-checks.json` once slice S0 has installed `ci.yml` and one PR has run it green. Required approving reviews stay at zero because every PR is opened under the owner\u2019s username and GitHub does not let an author approve their own PR; the bypass list is empty because builder sessions act as the owner.');

  H1('12. Testing and CI');
  H2('12.1 The test pyramid');
  table(tableAfter('docs/02-delivery/TESTING.md', '## Pyramid'), { wide: true });
  H2('12.2 Tiers and blast radius');
  P('Every test carries exactly one tier marker (`unit`, `integration`, `system`). CI runs the tiers as separate named checks and selects tests by blast radius (ADR-0008): a map from changed paths to tiers and selectors; a change to schema, core, workflows or dependency manifests forces the full matrix, as does a push to `main`, the `full-ci` label or nightly CT.');
  table(tableAfter('docs/02-delivery/TESTING.md', '| Pyramid level | Tier marker | Runs in |'));
  table(tableAfter('docs/02-delivery/TESTING.md', 'Selection by changed path:'));
  H2('12.3 The CI pipeline');
  figure(diagrams, 'D-PIPE', 'CI, CD and CT pipeline', 'wide');
  table(tableAfter('docs/02-delivery/CI-CD.md', '### `ci.yml` (pull requests and main)'), { wide: true });
  H2('12.4 CI failures feed the known-issues ledger');
  P('A failing tier produces `ci-issues.jsonl` (check, test id, signature, message, paths) as an artifact plus one PR comment. Each signature must appear in `KNOWN-ISSUES.md`, recorded with `issue.sh`, before the PR can merge; the Fable review checks this. The start hook injects open issues into every session so they are not reintroduced, and only the session whose entry is assigned an issue fixes it.');
  H2('12.5 Continuous testing');
  table(tableAfter('docs/02-delivery/TESTING.md', '## Continuous testing (CT)'));
  H2('12.6 Data invariants');
  table(tableAfter('docs/02-delivery/TESTING.md', '## Invariants (data tests)'));

  H1('13. Work packages and the expectation per session');
  P('Work is queued as builder session entries (`BS-nnn`) in `CONTEXT.md`, each expanded by Fable into a standalone packet under `docs/tasks/`. Entries are never deleted; their status moves through open, in progress, blocked and done.');
  H2('13.1 BS-001: S0 walking skeleton');
  table(tableAfter('docs/tasks/BS-001-s0-walking-skeleton.md', '# BS-001'));
  const pk = lines('docs/tasks/BS-001-s0-walking-skeleton.md'); const gi = pk.findIndex((l) => l.startsWith('## 1. Goal')); const goal = []; for (let i = gi + 2; i < pk.length && pk[i].trim() !== ''; i++) goal.push(pk[i].trim());
  P(goal.join(' '));
  H3('Acceptance criteria (Fable runs every one on the PR head)');
  table(tableAfter('docs/tasks/BS-001-s0-walking-skeleton.md', '## 3. Acceptance criteria'), { wide: true });
  H3('Build order with checkpoints');
  numberedList(listAfter('docs/tasks/BS-001-s0-walking-skeleton.md', '## 6. Build order with checkpoints'));
  H3('Tests required');
  table(tableAfter('docs/tasks/BS-001-s0-walking-skeleton.md', '## 8. Tests required'));
  H2('13.2 BS-002: CT and rollup workflows');
  P('Blocked until BS-001 merges. Goal: nightly continuous testing and the rollup workflow run from the repository rather than from `examples/`, with `ci-issues.py` wired so failing tiers upload the artifact and post the PR comment. Exit criteria: a deliberately failing test on a throwaway branch produces the artifact and the comment; the nightly runs green on `main`. Fable writes its packet after BS-001 merges because its interfaces depend on the S0 package layout.');
  H2('13.3 The expectation of every session, start to end');
  P('Both roles stop at 40 prompts; the hook warns at 35, forces the close-out at 40 and blocks prompts after it. Every session ends with a `log.sh close` entry; a session that ends without one is marked `auto` in the log so the next Fable session inspects its branch. The table in section 10.3 is the contract; in short:');
  Bullets(['**Builder, start:** the hook binds the role and injects the current state, its queue entry and packet path, open issues and answered questions; the session logs a start entry and reads `PROCESS.md`, the packet and the packet\u2019s reading list, nothing else.',
    '**Builder, middle:** one checkpoint at a time, each ending green locally (lint, format, type check, all three tiers) and pushed; progress logged per checkpoint; every question through `ask.sh`, every defect or failing check through `issue.sh`; never a merge, a ledger edit, another packet or a second entry.',
    '**Builder, end:** `/close-out` before prompt 40: AC table with evidence, deviations, assumptions, spend; questions and issues filed; branch pushed; draft PR under the owner\u2019s username; `log.sh close`; stop.',
    '**Fable, start:** the hook injects the full context; the session logs a start entry (confirming the model with `get_session` when the role was declared) and answers every pending question on every branch.',
    '**Fable, middle:** curates the known-issues ledger from CI output; for each builder PR runs the checks and the packet\u2019s acceptance criteria on the head, verifies author, blast radius, questions and issues, reads the diff against the file list; merges with a merge commit or writes rework or redesign items.',
    '**Fable, end:** updates `CONTEXT.md` (state, next actions, queue, decisions, questions, history), writes or refreshes the next packet, pushes to `main`, `log.sh close`.']);

  H1('14. Alignment review of 2026-09-03');
  P('This revision of the documents comes from a Fable session review of every design, delivery and process document, the hooks, the skills, the CI templates and the first task packet, checked against each other and against what the sessions so far actually experienced. Findings and resolutions:');
  table([['Finding', 'Resolution'],
    ['The SessionStart hook receives no model in cloud sessions, so every session was classed as a builder and Fable sessions corrected their own state by hand (three times). PR #6 proposed replacing inference with self-declared roles.', 'ADR-0009: role from the observed model when the platform reports one, `SPENDTRACKER_ROLE` as owner override, otherwise undeclared and fail-closed until a `ROLE:` declaration; declarations cannot override an observed role; declared Fable roles are marked in the log and audited. Hooks implemented; self-test extended to 89 checks; issue I-20260903-f7d2 recorded as fixed; PR #6 superseded.'],
    ['Q-6 (how much context a builder receives) was open while the owner had asked twice for separation.', 'ADR-0010: builder context is `PROCESS.md`, its packet and what it lists; the start hook injects only its own entry; other packets are hook-denied. Brief, protocol, process document, playbook and skills changed together.'],
    ['`docs/PROCESS.md` on `main` described a different system (STATUS.md, DECISIONS.md, per-task question files, `task/T-` branches, prompt-declared roles).', 'PR #5\u2019s reconciled version adopted as the base and aligned further (role source, context, branch naming, section 14 resolved).'],
    ['Packets and the close-out skill named `work/<slice>-<topic>` branches, but cloud sessions must push to the `claude/<slug>` branch the harness assigns.', 'PROCESS.md section 8, the packet, the builder brief and the close-out skill now say: push to the branch the session was started on; the packet name applies to local sessions.'],
    ['CI-CD.md still described a pre-tiering `ci.yml` (test-linux, test-macos, ui jobs) alongside the tiered one; the docs job listed checks the template does not run.', 'One job table matching `examples/ci/ci.yml`; unimplemented checks marked as planned; the pipeline diagram updated.'],
    ['TESTING.md\u2019s local commands used a `ui` marker although every test carries exactly one of `unit`, `integration`, `system`; the pyramid levels were not mapped to tiers; the blast-radius table lacked the rollup, cli, hooks and tests rules.', 'Commands rewritten per tier; a pyramid-to-tier mapping table added; the blast-radius table completed.'],
    ['VERTICAL-SLICES S0 said CI runs on Linux and macOS and told builders to record DDL deviations as ADR-0007, a number now taken.', 'S0 now names the installed jobs and says a new ADR; slices are stated to be delivered as packets.'],
    ['The phase playbook\u2019s kickoff prompt told every session to read `CONTEXT.md` in full and finish by updating it, which builders cannot do.', 'Separate builder and Fable kickoff prompts with the role declaration; step 1 and the close checklist attribute the ledger update to Fable.'],
    ['The Fable review skill said to squash; the repository history and PROCESS.md use merge commits; it did not run the packet\u2019s acceptance criteria or write the next packet.', 'Merge commit, acceptance criteria on the head, file-list check, packet writing and the declared-role audit added to the checklist.'],
    ['The diagram index lacked the session diagram and the playbook diagram had no id; the glossary lacked every process term; the root README did not mention the process, hooks or rulesets.', 'Index completed (D-PHASE, D-LIFECYCLE, D-SESSION, D-CONTEXT, D-GATES); thirteen glossary terms added; repository map extended.'],
    ['BS-002 was `open` with a "Blocked by" line, while the brief tells builders to take the first open entry.', 'Status set to `blocked`; the hook resolves entries by status.'],
    ['Two open PRs (#5 and #6) changed the same protocol in incompatible directions.', 'This branch is stacked on #5 and carries #6\u2019s fail-closed mechanics inside ADR-0009; recommended merge order recorded in CONTEXT.md next actions.']], { wide: true });

  H1('Appendix A. Document map and diagram index');
  P('Reading order, from `docs/README.md`:');
  numberedList(lines('docs/README.md').filter((l) => /^\d+\. \[/.test(l)).map((l) => l.replace(/^\d+\. /, '')));
  table(tableAfter('docs/README.md', '## Diagram index'));
  H2('Appendix B. Decisions log');
  table(tableAfter('docs/00-context/CONTEXT.md', '## Decisions log'));
  H2('Appendix C. Glossary');
  table(tableAfter('docs/00-context/GLOSSARY.md', '# Glossary'), { wide: true });
}

async function main() {
  const diagrams = extractDiagrams(); laneVariants(diagrams);
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'st-export-')); await render(diagrams, tmp);
  build(diagrams);
  const sections = []; let cur = null;
  const pageP = { size: { width: 12240, height: 15840 }, margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } };
  const pageL = { size: { width: 12240, height: 15840, orientation: PageOrientation.LANDSCAPE }, margin: { top: 1080, right: 1080, bottom: 1080, left: 1080 } };
  const hf = () => ({ headers: { default: new Header({ children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: 'SpendTracker: design, process and controls', size: 16, color: '888888' })] })] }) },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ children: ['Page ', PageNumber.CURRENT, ' of ', PageNumber.TOTAL_PAGES], size: 16, color: '888888' })] })] }) } });
  for (const b of blocks) {
    if (b.wide) { sections.push({ properties: { page: pageL }, ...hf(), children: b.els }); cur = null; }
    else { if (!cur) { cur = { properties: { page: pageP }, ...hf(), children: [] }; sections.push(cur); } cur.children.push(b.el); }
  }
  const doc = new Document({ creator: 'SpendTracker docs export', title: 'SpendTracker: design, process and controls', features: { updateFields: true },
    numbering: { config: numberingConfigs },
    styles: { default: { document: { run: { font: 'Calibri', size: 21 } } }, paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: 34, bold: true, color: '1F3B57', font: 'Calibri' }, paragraph: { spacing: { before: 360, after: 200 }, outlineLevel: 0 } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: 27, bold: true, color: '2E5C82', font: 'Calibri' }, paragraph: { spacing: { before: 280, after: 140 }, outlineLevel: 1 } },
      { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { size: 23, bold: true, color: '2E5C82', font: 'Calibri' }, paragraph: { spacing: { before: 200, after: 100 }, outlineLevel: 2 } }] },
    sections });
  fs.writeFileSync(OUT, await Packer.toBuffer(doc)); console.log('wrote', OUT, fs.statSync(OUT).size, 'bytes,', sections.length, 'sections'); fs.rmSync(tmp, { recursive: true, force: true });
}
main().catch((e) => { console.error(e); process.exit(1); });
