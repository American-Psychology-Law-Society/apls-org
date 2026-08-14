#!/usr/bin/env node
// Accessibility audit for the rendered site, using axe-core.
//
// What it does:
//   1. Starts a temporary local web server for the rendered site in docs/
//      (no separate server step needed).
//   2. Opens every .html page in a headless browser and runs axe-core
//      against the WCAG 2.0/2.1 A and AA rules.
//   3. Prints a summary and writes full details to audit-results.json.
//
// Setup (once):
//   npm install
//
// Run from the project root, AFTER `quarto render`:
//   node scripts/audit-a11y.js                # audit every page
//   node scripts/audit-a11y.js newsletter     # only pages whose path
//                                             # contains "newsletter"
//   node scripts/audit-a11y.js "" 0 100       # first 100 pages only
//                                             # (batches resume from
//                                             # audit-results.json)
//
// Needs a Chrome-family browser installed (Chrome, Brave, Edge, or
// Chromium). Everything else comes from `npm install`.

const fs = require('fs');
const path = require('path');
const http = require('http');
const puppeteer = require('puppeteer-core');

const ROOT = path.resolve(__dirname, '..');
const DOCS = path.join(ROOT, 'docs');
const RESULTS = path.join(ROOT, 'audit-results.json');

const FILTER = process.argv[2] || '';
const START = parseInt(process.argv[3] || '0', 10);
const COUNT = parseInt(process.argv[4] || '100000', 10);

// --- find an installed Chrome-family browser -------------------------------
function findBrowser() {
  const candidates = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  throw new Error(
    'No Chrome-family browser found. Install Google Chrome, Brave, Edge, or Chromium.'
  );
}

// --- tiny static file server for docs/ --------------------------------------
const MIME = {
  '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.gif': 'image/gif', '.svg': 'image/svg+xml', '.webp': 'image/webp',
  '.pdf': 'application/pdf', '.json': 'application/json',
  '.woff': 'font/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf',
};

function serveDocs() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      let rel = decodeURIComponent(req.url.split('?')[0]);
      if (rel.endsWith('/')) rel += 'index.html';
      const file = path.join(DOCS, rel);
      if (!file.startsWith(DOCS) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
        res.writeHead(404); res.end('not found'); return;
      }
      res.writeHead(200, { 'Content-Type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream' });
      fs.createReadStream(file).pipe(res);
    });
    server.listen(0, '127.0.0.1', () => resolve({ server, port: server.address().port }));
  });
}

// --- collect pages ------------------------------------------------------------
function walk(dir) {
  let out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (['site_libs', '_extensions'].includes(e.name) || e.name.endsWith('_files')) continue;
      out = out.concat(walk(p));
    } else if (e.name.endsWith('.html') && e.name !== '404.html') {
      out.push(p);
    }
  }
  return out;
}

(async () => {
  if (!fs.existsSync(DOCS)) {
    console.error('docs/ not found. Run `quarto render` first.');
    process.exit(1);
  }

  let all = walk(DOCS).map((p) => p.slice(DOCS.length)).sort();
  if (FILTER) all = all.filter((p) => p.includes(FILTER));
  const slice = all.slice(START, START + COUNT);

  let results = {};
  if (fs.existsSync(RESULTS)) results = JSON.parse(fs.readFileSync(RESULTS, 'utf8'));

  const { server, port } = await serveDocs();
  const browser = await puppeteer.launch({
    executablePath: findBrowser(),
    headless: 'new',
    args: ['--no-sandbox'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 900 });
  page.setDefaultTimeout(20000);

  const axePath = require.resolve('axe-core/axe.min.js');

  for (const rel of slice) {
    // Quarto renders `draft: true` pages as an empty HTML shell (no
    // <title>, empty or missing <body>) — nothing to audit, and axe
    // would report a spurious document-title violation. Skip them.
    const raw = fs.readFileSync(path.join(DOCS, rel), 'utf8');
    const isDraftShell =
      !/<title[\s>]/i.test(raw) &&
      (/<body>\s*<\/body>/i.test(raw) || !/<body[\s>]/i.test(raw));
    if (isDraftShell) {
      results[rel] = { skipped: 'draft stub (empty render)' };
      console.log('skip ' + rel + ' — draft stub');
      fs.writeFileSync(RESULTS, JSON.stringify(results, null, 1));
      continue;
    }
    try {
      await page.goto(`http://127.0.0.1:${port}${rel}`, { waitUntil: 'domcontentloaded' });
      await new Promise((r) => setTimeout(r, 700));
      await page.addScriptTag({ path: axePath });
      const res = await page.evaluate(async () => {
        const r = await axe.run(document, {
          runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'] },
        });
        return r.violations.map((v) => ({
          id: v.id,
          impact: v.impact,
          help: v.help,
          nodes: v.nodes.length,
          targets: v.nodes.slice(0, 3).map((n) => n.target.join(' ').slice(0, 90)),
        }));
      });
      results[rel] = { violations: res };
      console.log(
        (res.length ? 'FAIL ' : 'ok   ') +
          rel +
          (res.length ? ' — ' + res.map((v) => `${v.id}(${v.nodes})`).join(', ') : '')
      );
    } catch (e) {
      results[rel] = { error: String(e).slice(0, 120) };
      console.log('ERR  ' + rel + ' — ' + String(e).slice(0, 80));
    }
    fs.writeFileSync(RESULTS, JSON.stringify(results, null, 1));
  }

  await browser.close();
  server.close();

  const bad = Object.entries(results).filter(([, v]) => (v.violations || []).length > 0);
  const errs = Object.entries(results).filter(([, v]) => v.error);
  const skipped = Object.entries(results).filter(([, v]) => v.skipped);
  console.log('------------------------------------------------------------');
  console.log(`Audited ${slice.length} page(s) this run, ${Object.keys(results).length} total in ${path.basename(RESULTS)}.`);
  console.log(`Pages with violations: ${bad.length}. Pages with errors: ${errs.length}. Draft stubs skipped: ${skipped.length}.`);
  for (const [p, v] of bad) {
    console.log(`  ${p}: ${v.violations.map((x) => `${x.id}(${x.nodes})`).join(', ')}`);
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
