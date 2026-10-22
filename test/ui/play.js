// The behaviour suite: the reader who does the work gets the message.
// Run: bundle exec rake ui:play (test/ui/play.rb boots the app and writes the plates)
//   node test/ui/play.js BASE_URL PLATES_DIR [CHROMIUM_PATH]
//   BROWSER=chromium|firefox|webkit (default chromium)
//
// Where the stability harness proves that nothing moves, this one reads what
// the page says: the desk's letters, the bench's edition, the board's "Whole
// again", Lectio's ranks, the record, the preview, the grille's quarters. The
// answers come from the files written by play.rb, never from the page (the
// reader's page holds only what the file shows). Then the sounds of silence
// (silent by default; the hand heard after the press), axe-core on every page
// state in both themes, and two budgets.
const fs = require('fs');
const path = require('path');
const playwright = require('playwright');

const [baseUrl, platesDir, executablePath] = process.argv.slice(2);
const BROWSER = process.env.BROWSER || 'chromium';
const answers = JSON.parse(fs.readFileSync(path.join(platesDir, 'answers.json'), 'utf8'));
const MESSAGE = answers.message;
const LONG = 'Meet me at the old abbey after vespers, under the cloister arches by the well';
const BUDGET = { bytes: 160000, longTask: 300 }; // measured 126 to 196 ms on a 14 × 14 plate: a floor for regressions, not a target

// ---------- A small runner ----------
const results = [];
let pageErrors = [];
function check(section, name, ok, detail = '') {
  results.push({ section, name, ok, detail });
  console.log(`${ok ? 'ok   ' : 'FAIL '} ${section.padEnd(9)} ${name}${detail && !ok ? `  (${detail})` : ''}`);
}
const expectEqual = (section, name, actual, expected) => check(section, name, actual === expected, `got ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)}`);

let browser;
async function context(options = {}) {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 2000 }, reducedMotion: 'reduce', ...options });
  ctx.on('page', (page) => page.on('pageerror', (e) => pageErrors.push(`${e.message}`)));
  return ctx;
}

// ---------- Flows ----------
const inscribe = async (page, { message = MESSAGE, layout, condition, key } = {}) => {
  await page.goto(`${baseUrl}/`);
  await page.fill('#message', message);
  if (layout) await page.click(`label.segment:has(input[value="${layout}"])`);
  if (condition) await page.click(`label.segment--${condition}`);
  if (key) await page.fill('#grille', key);
  await Promise.all([page.waitForURL('**/generate'), page.click('[data-submit]')]);
};

// A file brought to Read, as a reader does: it opens as its puzzle
const bringToRead = async (page, file, selector) => {
  await page.goto(`${baseUrl}/decode`);
  await page.setInputFiles('#file', path.join(platesDir, file));
  await Promise.all([page.waitForURL('**/decode'), page.click('.entry [type="submit"]')]);
  await page.waitForSelector(selector, { state: 'attached' });
};

const cellValues = (page) => page.evaluate(() => JSON.parse(document.querySelector('[data-plate]').dataset.plateCells).map((c) => c[2]));
const text = async (page, selector) => (await page.textContent(selector)).trim();
const record = (page) => text(page, '[data-record="play"]');

// ---------- The preview ----------
async function preview() {
  const ctx = await context();
  const page = await ctx.newPage();
  await page.goto(`${baseUrl}/`);
  await page.fill('#message', 'Ora et labora!');
  await page.waitForTimeout(300);
  expectEqual('preview', 'one sign per letter, a space for the rest', await page.locator('[data-preview-signs] li').count(), 'ora et labora'.length);
  expectEqual('preview', 'the counter counts what was typed', await text(page, '[data-count]'), '14');
  await ctx.close();
}

// ---------- The desk ----------
async function desk(file, label, { unaided = false } = {}) {
  const ctx = await context();
  const page = await ctx.newPage();
  await bringToRead(page, file, '[data-desk]');
  const values = await cellValues(page);
  const pairs = values.length / 2;
  expectEqual('desk', `${label}: the plate opens at the desk, pair 1 of ${pairs}`, (await text(page, '[data-desk-which]')).startsWith(`Pair 1 of ${pairs}`), true);
  if (unaided) await page.click('[data-desk-set-mode="unaided"]');
  // A wrong pair: marked, never corrected, the text unchanged
  const wrongFirst = values[0] === 1 ? 2 : 1;
  await page.fill('#desk-first', String(wrongFirst));
  await page.fill('#desk-second', String(values[1]));
  await page.click('[data-desk-read]');
  await page.waitForTimeout(100);
  expectEqual('desk', `${label}: a wrong value is marked`, await page.getAttribute('#desk-first', 'aria-invalid'), 'true');
  expectEqual('desk', `${label}: a wrong pair writes nothing`, await text(page, '[data-desk-text]'), '·'.repeat(pairs));
  // Then every pair right
  for (let pair = 0; pair < pairs; pair += 1) {
    await page.fill('#desk-first', String(values[2 * pair]));
    await page.fill('#desk-second', String(values[(2 * pair) + 1]));
    await page.click('[data-desk-read]');
    if (unaided && pair === 2) expectEqual('desk', `${label}: three in a row, unaided, make a monk`, await text(page, '[data-desk-rank]'), 'Monk');
    if (pair < pairs - 1) await page.waitForFunction((n) => document.querySelector('[data-desk-which]').textContent.startsWith(`Pair ${n + 2} of`), pair);
  }
  expectEqual('desk', `${label}: read to the end, the text is the message`, await text(page, '[data-desk-text]'), MESSAGE);
  expectEqual('desk', `${label}: the page says so`, (await text(page, '[data-desk-feedback]')).startsWith('Read to the end'), true);
  expectEqual('desk', `${label}: one plate entered in the scriptorium`, await record(page), 'Entered in your scriptorium: 1 plate read, 1 intact.');
  await ctx.close();
}

// ---------- The bench ----------
async function bench() {
  const ctx = await context();
  const page = await ctx.newPage();
  await bringToRead(page, 'worn.svg', '[data-bench]');
  const lacunae = await page.evaluate(() => JSON.parse(document.querySelector('[data-bench]').dataset.lacunae));
  expectEqual('bench', 'the plate opens at the bench, lacuna 1', (await text(page, '[data-bench-which]')).startsWith(`Lacuna 1 of ${lacunae.length}`), true);
  expectEqual('bench', 'the page holds no lost value', (await cellValues(page)).filter((v) => v === null).length > 0, true);
  // Press the right digit into every lacuna, stepping through them in order
  for (let i = 0; i < lacunae.length; i += 1) {
    const { sign, place, digits } = lacunae[i];
    const digit = Math.floor(answers.worn[sign] / place) % 10;
    if (i === 0) expectEqual('bench', 'the right digit is among those offered', digits.includes(digit), true);
    await page.click(`[data-digit="${digit}"]`);
    if (i < lacunae.length - 1) await page.click('[data-bench-step="1"]');
  }
  expectEqual('bench', 'every lacuna restored', await text(page, '[data-bench-count]'), `${lacunae.length} of ${lacunae.length} restored`);
  expectEqual('bench', 'every pair balances', await text(page, '[data-bench-verdict]'), 'Every pair balances.');
  const edition = (await text(page, '[data-bench-edition]')).replace(/\[·\]/g, '').replace(/[[\]]/g, '').replace(/ /g, ' ');
  expectEqual('bench', 'the edition, brackets aside, is the message', edition, MESSAGE);
  expectEqual('bench', 'one worn plate entered in the scriptorium', await record(page), 'Entered in your scriptorium: 1 plate read, 1 worn.');
  await ctx.close();
}

// ---------- The board ----------
async function board() {
  const ctx = await context();
  const page = await ctx.newPage();
  await bringToRead(page, 'broken.svg', '[data-rejoin]');
  const total = answers.broken.length;
  expectEqual('board', `the plate opens as the board, ${total} fragments in the tray`, await text(page, '[data-rejoin-status]'), `On the board: 0 of ${total} fragments.`);
  const data = await page.evaluate(() => JSON.parse(document.querySelector('[data-plate]').dataset.fragments));
  const rect = page.locator('[data-plate] svg rect.board');
  const bb = await rect.boundingBox();
  const [cellW, cellH] = [bb.width / data.size, bb.height / data.size];
  for (const [index, row, col, turned] of answers.broken) {
    const group = page.locator(`[data-plate] svg g.fragment[aria-label^="Fragment ${index + 1} of"]`);
    await group.click({ position: { x: 12, y: 12 } }); // picked, and focused
    if (turned) await page.keyboard.press('t');
    await page.mouse.click(bb.x + ((col + 0.5) * cellW), bb.y + ((row + 0.5) * cellH));
    await page.waitForTimeout(50);
  }
  expectEqual('board', 'whole again: every pair balances', await text(page, '[data-rejoin-status]'), 'Whole again: every pair balances.');
  expectEqual('board', 'and it reads the message', await text(page, '[data-rejoin-reading]'), `It reads: ${MESSAGE}`);
  expectEqual('board', 'one broken plate entered in the scriptorium', await record(page), 'Entered in your scriptorium: 1 plate read, 1 broken.');
  await ctx.close();
}

// ---------- Lectio ----------
// The number a drawn sign reads, from its wedges and the glyph table: for each
// place, the digit whose strokes are exactly the ones present
const readSign = (page) => page.evaluate(() => {
  const t = window.Ink.glyphTable();
  const wedges = Array.from(document.querySelectorAll('[data-lectio-sign] svg path'));
  return [1, 10, 100, 1000].reduce((sum, place) => {
    const present = new Set(wedges.filter((w) => Number(w.dataset.place) === place).map((w) => w.dataset.stroke));
    for (let d = 1; d <= 9; d += 1) {
      const lines = (t.lines[d * place] || []).map((c) => c.join(','));
      if (lines.length === present.size && lines.every((l) => present.has(l))) return sum + (d * place);
    }
    return sum;
  }, 0);
});
async function lectio() {
  const ctx = await context();
  const page = await ctx.newPage();
  await page.goto(`${baseUrl}/about`);
  await page.waitForSelector('[data-lectio-answer]:not([disabled])');
  expectEqual('lectio', 'the first sign is the one the server drew', await readSign(page), Number(await page.getAttribute('[data-lectio-sign]', 'data-number')));
  for (let i = 0; i < 3; i += 1) {
    const value = await readSign(page);
    await page.fill('[data-lectio-answer]', String(value));
    await page.click('[data-lectio-submit]');
    await page.waitForFunction((n) => document.querySelector('[data-lectio-streak]').textContent === String(n), i + 1);
    await page.waitForTimeout(400); // the next sign
  }
  expectEqual('lectio', 'three in a row take the vows: a monk', await text(page, '[data-lectio-rank]'), 'Monk');
  const value = await readSign(page);
  expectEqual('lectio', 'a monk reads two-figure signs', value >= 10 && value <= 99, true);
  await page.fill('[data-lectio-answer]', String(value === 10 ? 11 : 10));
  await page.click('[data-lectio-submit]');
  await page.waitForTimeout(100);
  expectEqual('lectio', 'a misread is shown, and the streak ends', (await text(page, '[data-lectio-feedback]')).startsWith(`It reads ${value}.`) && (await text(page, '[data-lectio-streak]')) === '0', true);
  expectEqual('lectio', 'the best is kept', await text(page, '[data-lectio-best]'), '3');
  await ctx.close();
}

// ---------- The grille ----------
async function grille() {
  const ctx = await context();
  const page = await ctx.newPage();
  await inscribe(page, { layout: 'grille', key: 'K7Q2M-ZXB4P' });
  expectEqual('grille', 'the plate shows its key', (await text(page, '.specs')).includes('K7Q2M-ZXB4P'), true);
  const wedges = await page.locator('[data-plate] > svg:not(.grille-sheet) path').count();
  const seen = new Set();
  for (const turn of ['N', 'E', 'S', 'W']) {
    await page.click('[data-action="lay-grille"]');
    await page.waitForTimeout(50);
    const lit = await page.evaluate(() => { const all = Array.from(document.querySelectorAll('[data-plate] > svg:not(.grille-sheet) path')); return all.flatMap((p, i) => (p.classList.contains('is-lit') ? [i] : [])); });
    lit.forEach((i) => seen.add(i));
    const reading = await text(page, '[data-plate-reading]');
    if (turn === 'N') expectEqual('grille', 'laid at N, it lights the first quarter', /^The grille at N: signs 1 to \d+ of \d+, row by row$/.test(reading), true);
    if (turn === 'N') expectEqual('grille', 'the sheet is laid', await page.getAttribute('[data-action="lay-grille"]', 'aria-pressed'), 'true');
  }
  expectEqual('grille', 'four quarters light every stroke once', seen.size, wedges);
  await page.click('[data-action="lay-grille"]');
  expectEqual('grille', 'lifted, nothing is lit', await page.locator('[data-plate] > svg:not(.grille-sheet) path.is-lit').count(), 0);
  await ctx.close();
}

// ---------- The sounds of silence (the Web Audio nodes counted; Chromium) ----------
const COUNTER = `
  window.__audio = { contexts: 0, starts: 0, pans: [], bells: 0 };
  const Ctx = window.AudioContext;
  if (Ctx) window.AudioContext = class extends Ctx {
    constructor(...a) { super(...a); window.__audio.contexts += 1; }
    createStereoPanner() { const p = super.createStereoPanner(); window.__audio.pans.push(p); return p; }
  };
  for (const proto of [AudioBufferSourceNode.prototype, OscillatorNode.prototype]) {
    const start = proto.start;
    proto.start = function (...a) { window.__audio.starts += 1; return start.apply(this, a); };
  }
  document.addEventListener('hand:bell', () => { window.__audio.bells += 1; });
`;
async function sounds() {
  const ctx = await context({ reducedMotion: 'no-preference' });
  await ctx.addInitScript(COUNTER);
  const page = await ctx.newPage();
  const audio = () => page.evaluate(() => ({ contexts: window.__audio.contexts, starts: window.__audio.starts, bells: window.__audio.bells, pans: window.__audio.pans.map((p) => p.pan.value) }));
  await inscribe(page, { message: LONG });
  await page.waitForTimeout(3200);
  expectEqual('sound', 'silent by default: no context, no voice, after a plate is inked', JSON.stringify([(await audio()).contexts, (await audio()).starts]), '[0,0]');
  expectEqual('sound', 'the colophon offers the hand', await text(page, '[data-hear]'), 'Hear the hand');
  await page.click('[data-hear]');
  expectEqual('sound', 'pressed, it says Silence and keeps the choice', `${await text(page, '[data-hear]')} ${await page.evaluate(() => localStorage.getItem('cistergraphia.sound'))}`, 'Silence on');
  await page.reload();
  await page.waitForTimeout(3200);
  const inked = await audio();
  expectEqual('sound', 'the hand heard: one context, voices as the plate is inked', inked.contexts === 1 && inked.starts > 20, true);
  expectEqual('sound', 'heard where it is: pans within ±0.6, left and right', Math.min(...inked.pans) < -0.3 && Math.max(...inked.pans) > 0.3 && inked.pans.every((p) => Math.abs(p) <= 0.6), true);
  // The desk: a wrong pair is silent, the end rings the bell once
  await page.goto(`${baseUrl}/decode`);
  await page.setInputFiles('#file', path.join(platesDir, 'intact.svg'));
  await Promise.all([page.waitForURL('**/decode'), page.click('.entry [type="submit"]')]);
  await page.waitForTimeout(3200);
  const values = await cellValues(page);
  const before = (await audio()).starts;
  await page.fill('#desk-first', String(values[0] === 1 ? 2 : 1));
  await page.fill('#desk-second', String(values[1]));
  await page.click('[data-desk-read]');
  await page.waitForTimeout(150);
  expectEqual('sound', 'a wrong pair is silent', (await audio()).starts - before, 0);
  for (let pair = 0; pair < values.length / 2; pair += 1) {
    await page.fill('#desk-first', String(values[2 * pair]));
    await page.fill('#desk-second', String(values[(2 * pair) + 1]));
    await page.click('[data-desk-read]');
    await page.waitForTimeout(950);
  }
  expectEqual('sound', 'read to the end, the bell rings once', (await audio()).bells, 1);
  await page.click('[data-hear]');
  expectEqual('sound', 'silence again', await page.evaluate(() => localStorage.getItem('cistergraphia.sound')), 'off');
  await ctx.close();
}

// ---------- Accessibility: axe-core on every page state, both themes ----------
async function accessibility() {
  const axe = fs.readFileSync(require.resolve('axe-core/axe.min.js'), 'utf8');
  const states = {
    inscribe: (p) => p.goto(`${baseUrl}/`),
    plate: (p) => inscribe(p),
    worn: (p) => inscribe(p, { condition: 'worn' }),
    broken: (p) => inscribe(p, { condition: 'broken' }),
    grille: (p) => inscribe(p, { layout: 'grille' }),
    desk: (p) => bringToRead(p, 'intact.svg', '[data-desk]'),
    bench: (p) => bringToRead(p, 'worn.svg', '[data-bench]'),
    board: (p) => bringToRead(p, 'broken.svg', '[data-rejoin]'),
    read: (p) => p.goto(`${baseUrl}/decode`),
    about: (p) => p.goto(`${baseUrl}/about`),
    erratum: (p) => p.goto(`${baseUrl}/nowhere`)
  };
  const violations = [];
  for (const colorScheme of ['light', 'dark']) {
    const ctx = await context({ colorScheme, bypassCSP: true, viewport: { width: 1024, height: 768 } });
    const page = await ctx.newPage();
    for (const [name, open] of Object.entries(states)) {
      await open(page);
      await page.waitForTimeout(200);
      await page.addScriptTag({ content: axe });
      const found = await page.evaluate(async () => {
        const res = await window.axe.run(document, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'best-practice'] } });
        return res.violations.map((v) => `${v.id} (${v.impact}) at ${v.nodes[0].target[0]}`);
      });
      found.forEach((v) => violations.push(`${name}/${colorScheme}: ${v}`));
    }
    await ctx.close();
  }
  check('a11y', `no axe violation on ${Object.keys(states).length} page states in both themes`, violations.length === 0, violations.slice(0, 5).join('; '));
}

// ---------- Budgets ----------
async function budgets() {
  const ctx = await context({ reducedMotion: 'no-preference' });
  const page = await ctx.newPage();
  await page.addInitScript(() => {
    // Only where the engine reports long tasks (Chromium); elsewhere the check is skipped, not passed empty
    window.__long = (PerformanceObserver.supportedEntryTypes || []).includes('longtask') ? [] : null;
    if (window.__long) new PerformanceObserver((list) => list.getEntries().forEach((e) => window.__long.push(Math.round(e.duration)))).observe({ type: 'longtask', buffered: true });
  });
  const sizes = {};
  page.on('response', async (res) => { const file = new URL(res.url()).pathname; if (/\.(js|css)$/.test(file)) { try { sizes[file] = (await res.body()).length; } catch (e) { /* gone */ } } });
  await inscribe(page, { message: LONG });
  await page.waitForTimeout(3500);
  const bytes = Object.values(sizes).reduce((a, b) => a + b, 0);
  check('budget', `scripts and styles under ${BUDGET.bytes / 1000} KB (${Math.round(bytes / 1000)} KB)`, bytes > 0 && bytes <= BUDGET.bytes, JSON.stringify(sizes));
  const long = await page.evaluate(() => window.__long);
  if (long) check('budget', `no long task over ${BUDGET.longTask} ms inking a 14 × 14 plate (${long.length ? Math.max(...long) : 0} ms)`, long.every((ms) => ms <= BUDGET.longTask), long.join(', '));
  else console.log('skip  budget    long tasks: not observable in this engine');
  await ctx.close();
}

// ---------- Run ----------
(async () => {
  const launch = BROWSER === 'chromium' && executablePath ? { executablePath } : {};
  if (BROWSER === 'chromium') launch.args = ['--autoplay-policy=no-user-gesture-required'];
  browser = await playwright[BROWSER].launch(launch);
  console.log(`play.js on ${BROWSER}, ${browser.version()}`);
  await preview();
  await desk('intact.svg', 'the snail');
  await desk('rongorongo.svg', 'the turning rows', { unaided: true });
  await bench();
  await board();
  await lectio();
  await grille();
  if (BROWSER === 'chromium') await sounds();
  else console.log('skip  sound     the node counts are taken on Chromium');
  await accessibility();
  await budgets();
  await browser.close();
  check('errors', 'no page error anywhere', pageErrors.length === 0, pageErrors.slice(0, 3).join('; '));
  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length} checks, ${failed.length} failed on ${BROWSER}`);
  process.exit(failed.length ? 1 : 0);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
