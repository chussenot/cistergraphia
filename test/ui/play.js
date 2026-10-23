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
const BUDGET = { bytes: 60000, longTask: 300 }; // transferred bytes of scripts and styles (37 KB compressed today); 126 to 196 ms on a 14 × 14 plate: floors for regressions, not targets

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
  if (condition) {
    if (!(await page.locator('.puzzle[open]').count())) await page.click('.puzzle-summary'); // the reader's puzzle, shut on a plain plate
    await page.click(`label.segment--${condition}`);
  }
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
  // The strip is drawn on the next frame: wait for it, not for a duration
  // (WebKit on a cold runner took longer than 300 ms); when it never comes,
  // say how many signs there are and whether a frame fires at all
  const expected = 'ora et labora'.length;
  const drawn = await page.waitForFunction((n) => document.querySelectorAll('[data-preview-signs] li').length === n, expected, { timeout: 5000 })
    .then(() => true, () => false);
  const detail = drawn ? '' : await page.evaluate(() => new Promise((resolve) => {
    const count = document.querySelectorAll('[data-preview-signs] li').length;
    requestAnimationFrame(() => resolve(`${count} signs; a frame fires; ${document.visibilityState}`));
    setTimeout(() => resolve(`${count} signs; no frame in 1 s; ${document.visibilityState}`), 1000);
  }));
  check('preview', `one sign per letter, a space for the rest (${expected})`, drawn, detail);
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

// ---------- A pathless plate: the way is to find ----------
const Ways = require(path.join(__dirname, '../../public/js/ways.js'));
async function pathless() {
  const ctx = await context();
  const page = await ctx.newPage();
  await bringToRead(page, 'pathless.svg', '[data-desk-pathless]');
  const { way, breaks } = answers.pathless;
  expectEqual('pathless', 'the plate opens without its way', await text(page, '[data-desk-which]'), 'Choose a way to read');
  expectEqual('pathless', 'the pair boxes wait empty', await page.locator('[data-desk-sign] svg').count(), 0);
  const grid = await page.evaluate(() => JSON.parse(document.querySelector('[data-plate]').dataset.plateGrid));
  const byCell = new Map(grid.map(([r, c, up, turned]) => [`${r},${c}`, { up, turned }]));
  const along = (name) => Ways.path(Math.sqrt(grid.length), name).map(([r, c, turned]) => { const cell = byCell.get(`${r},${c}`); return turned ? cell.turned : cell.up; });
  const readPair = async (values, p) => {
    await page.fill('#desk-first', String(values[2 * p]));
    await page.fill('#desk-second', String(values[(2 * p) + 1]));
    await page.click('[data-desk-read]');
    await page.waitForTimeout(80);
  };
  // A wrong way, the one that breaks soonest: letters until it breaks, then the break said and noted
  const [wrong, at] = Object.entries(breaks).filter(([name]) => name !== way).sort((a, b) => a[1] - b[1])[0];
  await page.click(`[data-desk-way="${wrong}"]`);
  const wrongValues = along(wrong);
  await page.focus('[data-plate]');
  await page.keyboard.press('Home');
  expectEqual('pathless', `${wrong} laid: the walk follows it`, await text(page, '[data-plate-reading]'), `Sign 1 of ${wrongValues.length} · ${wrongValues[0]}`);
  for (let p = 0; p < at - 1; p += 1) {
    await readPair(wrongValues, p);
    await page.waitForFunction((n) => document.querySelector('[data-desk-which]').textContent.startsWith(`Pair ${n + 2} of`), p);
  }
  if (wrongValues[2 * (at - 1)] === null || wrongValues[(2 * (at - 1)) + 1] === null) {
    await page.click('[data-desk-read]');
    await page.waitForTimeout(80);
    expectEqual('pathless', `${wrong} breaks at pair ${at}: a sign reads as nothing turned`, (await text(page, '[data-desk-feedback]')).includes('reads as no number'), true);
  } else {
    await readPair(wrongValues, at - 1);
    const named = `The ${wrong === 'phaistos' ? 'snail' : wrong === 'rongorongo' ? 'turning tablet' : wrong}`;
    expectEqual('pathless', `${wrong} breaks at pair ${at}: not on the tablet`, (await text(page, '[data-desk-feedback]')).includes(`not on the tablet. ${named} breaks at pair ${at}`), true);
  }
  expectEqual('pathless', 'the notebook keeps where it broke', (await text(page, '[data-desk-notebook]')).includes(`✗ at pair ${at}`), true);
  // The way: every pair reads, the plate is read along it, one pathless plate in the record
  await page.click(`[data-desk-way="${way}"]`);
  const values = along(way);
  const pairs = values.length / 2;
  for (let p = 0; p < pairs; p += 1) {
    await readPair(values, p);
    if (p < pairs - 1) await page.waitForFunction((n) => document.querySelector('[data-desk-which]').textContent.startsWith(`Pair ${n + 2} of`), p);
  }
  expectEqual('pathless', `along ${way}, the text is the message`, await text(page, '[data-desk-text]'), MESSAGE);
  expectEqual('pathless', 'the page says along which way', (await text(page, '[data-desk-feedback]')).startsWith(`Read to the end, along the ${way}`), true);
  expectEqual('pathless', 'one pathless plate entered in the scriptorium', await record(page), 'Entered in your scriptorium: 1 plate read, 1 pathless.');
  expectEqual('pathless', 'the notebook ticks the way', (await text(page, '[data-desk-notebook]')).includes(`the ${way}: ${MESSAGE} ✓`), true);
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

// ---------- The bench on a pathless plate: the way to find, then the restoration ----------
async function pathlessBench() {
  const ctx = await context();
  const page = await ctx.newPage();
  await bringToRead(page, 'worn-pathless.svg', '[data-bench-pathless]');
  const { way, values } = answers.worn_pathless;
  expectEqual('pathless+', 'the plate opens at the bench without its way', await text(page, '[data-bench-which]'), 'Choose a way to restore');
  expectEqual('pathless+', 'the page holds no lost value', (await cellValues(page)).filter((v) => v === null).length > 0, true);
  const laidLacunae = () => page.evaluate(() => Array.from(document.querySelectorAll('.bench-target')).length);
  expectEqual('pathless+', 'no lacuna is laid before a way is chosen', await laidLacunae(), 0);
  // A wrong way: the edition shows pairs off the tablet at once, and the notebook says so
  const wrong = Ways.NAMES.find((name) => name !== way);
  await page.click(`[data-bench-way="${wrong}"]`);
  const wrongEdition = await text(page, '[data-bench-edition]');
  expectEqual('pathless+', `${wrong} laid: the edition says what it gives`, wrongEdition.includes('[?]') || wrongEdition.includes('[.]'), true);
  expectEqual('pathless+', `${wrong}: the lacunae are laid along it`, (await laidLacunae()) > 0, true);
  const noted = await text(page, '[data-bench-notebook]');
  expectEqual('pathless+', 'the notebook keeps what the wrong way gave', noted.startsWith('Tried: ') && / \d+ off ✗/.test(noted), true);
  expectEqual('pathless+', 'the verdict says the way is wrong', (await text(page, '[data-bench-verdict]')).endsWith('not the way.'), true);
  // The way: the lacunae take their places along it (as the bench lays them: the
  // worn cells in path order, each place the file shows); press the right digit into every one
  await page.click(`[data-bench-way="${way}"]`);
  const worn = await page.evaluate(() => JSON.parse(document.querySelector('[data-bench]').dataset.benchWorn));
  const wornAt = new Map(worn.map((cell) => [`${cell.row},${cell.col}`, cell]));
  const lacunae = Ways.path(Math.sqrt(values.length), way).flatMap(([r, c, turned], sign) => {
    const cell = wornAt.get(`${r},${c}`);
    const entries = cell && (turned ? cell.turned : cell.upright);
    return (entries || []).map((entry) => ({ sign, place: entry.place, digits: entry.digits }));
  });
  expectEqual('pathless+', `${way} laid: the lacunae take their places`, await laidLacunae(), lacunae.length);
  expectEqual('pathless+', `${way} laid: no pair is off the tablet`, (await text(page, '[data-bench-edition]')).includes('[?]'), false);
  for (let i = 0; i < lacunae.length; i += 1) {
    const { sign, place, digits } = lacunae[i];
    const digit = Math.floor(values[sign] / place) % 10;
    if (i === 0) expectEqual('pathless+', 'the right digit is among those offered', digits.includes(digit), true);
    await page.click(`[data-digit="${digit}"]`);
    if (i < lacunae.length - 1) await page.click('[data-bench-step="1"]');
  }
  expectEqual('pathless+', 'every lacuna restored', await text(page, '[data-bench-count]'), `${lacunae.length} of ${lacunae.length} restored`);
  expectEqual('pathless+', 'every pair balances', await text(page, '[data-bench-verdict]'), 'Every pair balances.');
  const edition = (await text(page, '[data-bench-edition]')).replace(/\[·\]/g, '').replace(/[[\]]/g, '').replace(/\u00a0/g, ' ');
  expectEqual('pathless+', 'the edition, brackets aside, is the message', edition, MESSAGE);
  expectEqual('pathless+', 'the notebook ticks the way', (await text(page, '[data-bench-notebook]')).includes(`the ${way}: restored ✓`), true);
  expectEqual('pathless+', 'one pathless plate entered in the scriptorium', await record(page), 'Entered in your scriptorium: 1 plate read, 1 pathless.');
  await ctx.close();
}

// ---------- A tablet of its own: the notebook ----------
async function notebook() {
  const ctx = await context();
  const page = await ctx.newPage();
  await bringToRead(page, 'own-tablet.svg', '[data-notebook]:not(.awaits-script)');
  const tablet = answers.own_tablet; // sum => character, from the seed
  const sums = Object.keys(tablet).map(Number);
  const order = await page.evaluate(() => JSON.parse(document.querySelector('[data-notebook]').dataset.notebookSums));
  expectEqual('notebook', 'the page holds no tablet', await page.evaluate(() => document.querySelector('[data-desk]').dataset.tablet), '{}');
  expectEqual('notebook', 'one entry per sum the pairs make', order.slice().sort((a, b) => a - b).join(), sums.slice().sort((a, b) => a - b).join());
  const write = (sum, char) => page.selectOption(`[data-entry="${sum}"]`, char);
  const ask = async () => { await page.click('[data-notebook-ask]'); await page.waitForFunction(() => !document.querySelector('[data-notebook-verdict]').textContent.endsWith('…')); };
  const inked = () => page.locator('select[data-entry]:disabled').count();
  // The space: the most seen sum of this message, and pencilling it breaks the line into words
  const space = sums.find((sum) => tablet[sum] === ' ');
  await write(space, ' ');
  expectEqual('notebook', 'a pencilled space breaks the line into words', (await page.textContent('[data-desk-text]')).includes(' '), true);
  expectEqual('notebook', 'a pencilled letter is in pencil', await page.locator('[data-desk-text] .is-pencil').count() > 0, true);
  // Two right and one wrong: nothing holds yet, nothing in ink, and the scribe does not say which
  const others = order.filter((sum) => sum !== space);
  const wrongLetter = 'abcdefghijklmnopqrstuvwxyz'.split('').find((c) => !Object.values(tablet).includes(c));
  await write(others[0], tablet[others[0]]);
  await write(others[1], wrongLetter);
  await ask();
  expectEqual('notebook', 'two right entries and a wrong one: nothing holds yet', await text(page, '[data-notebook-verdict]'), 'Nothing holds yet.');
  expectEqual('notebook', 'and nothing goes into ink', await inked(), 0);
  // The third put right, a fourth wrong: three hold, the wrong one stays in pencil
  await write(others[1], tablet[others[1]]);
  await write(others[2], wrongLetter);
  await ask();
  expectEqual('notebook', 'three right entries hold, in ink', await inked(), 3);
  expectEqual('notebook', 'the wrong one stays in pencil', await page.locator(`[data-entry="${others[2]}"]`).isDisabled(), false);
  expectEqual('notebook', 'the count says how far', (await text(page, '[data-notebook-count]')).startsWith(`3 of ${sums.length} in ink · asked 2 times`), true);
  // The rest, right: every sum in ink, the text is the message, one plate in the record
  for (const sum of others.slice(2)) await write(sum, tablet[sum]);
  await ask();
  expectEqual('notebook', 'every sum in ink: the tablet is the reader\'s', await text(page, '[data-notebook-verdict]'), 'Every sum is in ink: the tablet is yours.');
  expectEqual('notebook', 'the text is the message', await text(page, '[data-desk-text]'), MESSAGE);
  expectEqual('notebook', 'one plate with its own tablet in the scriptorium', await record(page), 'Entered in your scriptorium: 1 plate read, 1 with its own tablet.');
  await ctx.close();
}

// ---------- The expert plate: the way on sums alone, then the notebook ----------
async function expert() {
  const ctx = await context();
  const page = await ctx.newPage();
  await bringToRead(page, 'expert.svg', '[data-notebook]:not(.awaits-script)');
  const { way, breaks, tablet } = answers.expert;
  const sums = Object.keys(tablet).map(Number);
  expectEqual('expert', 'the page holds no tablet', await page.evaluate(() => document.querySelector('[data-desk]').dataset.tablet), '{}');
  expectEqual('expert', 'the notebook is shut, with no sum in it', await page.evaluate(() => document.querySelector('[data-notebook]').dataset.notebookSums), '[]');
  expectEqual('expert', 'and the scribe cannot be asked', await page.locator('[data-notebook-ask]').isDisabled(), true);
  const grid = await page.evaluate(() => JSON.parse(document.querySelector('[data-plate]').dataset.plateGrid));
  const byCell = new Map(grid.map(([r, c, up, turned]) => [`${r},${c}`, { up, turned }]));
  const along = (name) => Ways.path(Math.sqrt(grid.length), name).map(([r, c, turned]) => { const cell = byCell.get(`${r},${c}`); return turned ? cell.turned : cell.up; });
  const readPair = async (values, p) => {
    await page.fill('#desk-first', String(values[2 * p]));
    await page.fill('#desk-second', String(values[(2 * p) + 1]));
    await page.click('[data-desk-read]');
    await page.waitForTimeout(80);
  };
  // A wrong way, the one that breaks soonest: on a sum that is no tablet's value, or a sign that reads as nothing turned
  const [wrong, at] = Object.entries(breaks).filter(([name]) => name !== way).sort((a, b) => a[1] - b[1])[0];
  await page.click(`[data-desk-way="${wrong}"]`);
  const wrongValues = along(wrong);
  for (let p = 0; p < at - 1; p += 1) {
    await readPair(wrongValues, p);
    await page.waitForFunction((n) => document.querySelector('[data-desk-which]').textContent.startsWith(`Pair ${n + 2} of`), p);
  }
  if (wrongValues[2 * (at - 1)] === null || wrongValues[(2 * (at - 1)) + 1] === null) await page.click('[data-desk-read]');
  else await readPair(wrongValues, at - 1);
  await page.waitForTimeout(80);
  const broke = await text(page, '[data-desk-feedback]');
  expectEqual('expert', `${wrong} breaks at pair ${at}, no letter said`, (broke.includes('a value of no tablet') || broke.includes('reads as no number')) && !/“[a-z]”/.test(broke), true);
  expectEqual('expert', 'the ways tried keep where it broke', (await text(page, '[data-desk-notebook]')).includes(`✗ at pair ${at}`), true);
  expectEqual('expert', 'and the notebook stays shut', await page.locator('[data-notebook-shut]').count(), 1);
  // The way: pairs that land, their letters unknown, until three open the notebook on every sum along it
  await page.click(`[data-desk-way="${way}"]`);
  const values = along(way);
  const nullMark = Number(await page.evaluate(() => document.querySelector('[data-desk]').dataset.null));
  let landed = 0;
  for (let p = 0; p < values.length / 2 && await page.locator('[data-notebook-shut]').count(); p += 1) {
    if (p) await page.waitForFunction((n) => document.querySelector('[data-desk-which]').textContent.startsWith(`Pair ${n + 1} of`), p);
    await readPair(values, p);
    if (values[(2 * p) + 1] === nullMark) continue;
    landed += 1;
    if (landed === 1) expectEqual('expert', 'a pair that lands is a value of the tablet, its letter to find', (await text(page, '[data-desk-feedback]')).endsWith('a value of the tablet, its letter to find.'), true);
  }
  expectEqual('expert', 'three pairs that land open the notebook', landed, 3);
  expectEqual('expert', 'the page says this is the way', (await text(page, '[data-desk-feedback]')).includes('this is the way'), true);
  const order = await page.evaluate(() => JSON.parse(document.querySelector('[data-notebook]').dataset.notebookSums));
  expectEqual('expert', 'the notebook opens on every sum along the way', order.slice().sort((a, b) => a - b).join(), sums.slice().sort((a, b) => a - b).join());
  expectEqual('expert', 'the other ways are shut', await page.locator('[data-desk-way]:disabled').count(), 4);
  // Away and back: the way and the notebook as left, in this browser
  await page.selectOption(`[data-entry="${order[0]}"]`, tablet[order[0]]);
  await bringToRead(page, 'expert.svg', '[data-notebook]:not(.awaits-script)');
  expectEqual('expert', 'brought back: the notebook open on the way found', await page.locator('[data-notebook-shut]').count(), 0);
  expectEqual('expert', 'and the entry pencilled before', await page.inputValue(`[data-entry="${order[0]}"]`), tablet[order[0]]);
  // Every sum written right, the scribe asked: in ink, the message, one expert plate in the record
  for (const sum of order) await page.selectOption(`[data-entry="${sum}"]`, tablet[sum]);
  await page.click('[data-notebook-ask]');
  await page.waitForFunction(() => !document.querySelector('[data-notebook-verdict]').textContent.endsWith('…'));
  expectEqual('expert', 'every sum in ink', await text(page, '[data-notebook-verdict]'), 'Every sum is in ink: the tablet is yours.');
  expectEqual('expert', 'the text is the message', await text(page, '[data-desk-text]'), MESSAGE);
  expectEqual('expert', 'one expert plate in the scriptorium', await record(page), 'Entered in your scriptorium: 1 plate read, 1 pathless with its own tablet.');
  await ctx.close();
}

// ---------- The reading room: what is read is never a scroll away ----------
async function room() {
  const inView = (box, height) => box && box.y >= -1 && box.y + box.height <= height + 1;
  // A wide screen: the plate beside the desk, held in view while the notebook scrolls
  let ctx = await context({ viewport: { width: 1280, height: 800 } });
  let page = await ctx.newPage();
  await bringToRead(page, 'own-tablet.svg', '[data-notebook]:not(.awaits-script)');
  const [plate, desk] = await Promise.all(['[data-plate]', '[data-desk]'].map((q) => page.locator(q).boundingBox()));
  expectEqual('room', 'on a wide screen the desk sits beside the plate', desk.x >= plate.x + plate.width && Math.abs(desk.y - plate.y) < 120, true);
  await page.locator('[data-entry-row] >> nth=8').scrollIntoViewIfNeeded(); // halfway down the notebook
  expectEqual('room', 'the plate stays in view down the notebook', inView(await page.locator('[data-plate]').boundingBox(), 800), true);
  expectEqual('room', 'and the text line stays in view', inView(await page.locator('.notebook-line').boundingBox(), 800), true);
  expectEqual('room', 'and so does Ask the scribe', inView(await page.locator('[data-notebook-ask]').boundingBox(), 800), true);
  await ctx.close();
  // A phone: the pair set as a sum on paper, each sign beside its value, the letter beneath
  ctx = await context({ viewport: { width: 390, height: 844 } });
  page = await ctx.newPage();
  await bringToRead(page, 'intact.svg', '[data-desk]:not(.awaits-script)');
  const [s1, v1, s2, v2, letter] = await Promise.all(['[data-desk-sign="0"]', '#desk-first', '[data-desk-sign="1"]', '#desk-second', '[data-desk-letter]'].map((q) => page.locator(q).boundingBox()));
  expectEqual('room', 'on a phone each sign has its value beside it', v1.x > s1.x + s1.width - 1 && Math.abs(v1.y + (v1.height / 2) - s1.y - (s1.height / 2)) < 8, true);
  expectEqual('room', 'the second sign below the first, the letter below both', s2.y >= s1.y + s1.height && Math.abs(s2.x - s1.x) < 2 && letter.y >= v2.y + v2.height - 1, true);
  await ctx.close();
}

// ---------- Zoom: a plate of many signs, looked at closely ----------
async function zoom() {
  const ctx = await context({ viewport: { width: 390, height: 844 } });
  const page = await ctx.newPage();
  await inscribe(page, { message: LONG });
  await page.waitForSelector('[data-plate-zoom]:not(.awaits-script)');
  const boxes = () => page.evaluate(() => {
    const frame = document.querySelector('[data-plate]');
    const [f, s] = [frame, frame.querySelector('svg')].map((el) => el.getBoundingClientRect());
    const focus = frame.querySelector('.plate-focus')?.getBoundingClientRect();
    return { frame: [f.width, f.height].map(Math.round), plate: [s.width, s.height].map(Math.round), inside: focus ? focus.left >= f.left - 1 && focus.right <= f.right + 1 && focus.top >= f.top - 1 && focus.bottom <= f.bottom + 1 : null, level: document.querySelector('[data-zoom-level]').textContent };
  });
  const before = await boxes();
  await page.click('[data-zoom-step="1"]');
  await page.click('[data-zoom-step="1"]');
  const zoomed = await boxes();
  expectEqual('zoom', 'the plate grows twice over', zoomed.level === '×2' && Math.abs(zoomed.plate[0] - (2 * before.plate[0])) <= 2, true);
  expectEqual('zoom', 'within a frame that keeps its size', zoomed.frame.join(), before.frame.join());
  await page.focus('[data-plate]');
  for (let i = 0; i < 40; i += 1) await page.keyboard.press('ArrowRight');
  await page.waitForTimeout(400);
  expectEqual('zoom', 'the sign the walk is on stays in view', (await boxes()).inside, true);
  await page.keyboard.press('0');
  expectEqual('zoom', 'zero fits the plate again', (await boxes()).plate.join(), before.plate.join());
  // Ctrl and the wheel, as a trackpad's pinch sends it (dispatched: Playwright's Firefox delivers no wheel to the page)
  await page.evaluate(() => {
    const frame = document.querySelector('[data-plate]');
    const box = frame.getBoundingClientRect();
    frame.dispatchEvent(new WheelEvent('wheel', { deltaY: -120, ctrlKey: true, clientX: box.left + (box.width / 2), clientY: box.top + (box.height / 2), bubbles: true, cancelable: true }));
  });
  expectEqual('zoom', 'ctrl and the wheel zoom in', (await boxes()).level, '×1.5');
  await page.click('[data-zoom-fit]');
  expectEqual('zoom', 'Fit gives the whole plate back', (await boxes()).level, '×1');
  // A small plate has no zoom: its signs are large enough
  await inscribe(page, { message: 'Ora' });
  expectEqual('zoom', 'a small plate has no zoom', await page.locator('[data-plate-zoom]').count(), 0);
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
    expert: (p) => bringToRead(p, 'expert.svg', '[data-notebook]:not(.awaits-script)'),
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
  // What the browser downloads (compressed by the app) and what it unpacks, per file
  const sizes = {};
  const raw = {};
  page.on('response', async (res) => {
    const file = new URL(res.url()).pathname;
    if (!/\.(js|css)$/.test(file) || file in sizes) return; // the first load of each; later ones come from the cache
    try {
      raw[file] = (await res.body()).length;
      await res.finished(); // the sizes are known once the body has arrived
      const { responseBodySize } = await res.request().sizes();
      sizes[file] = responseBodySize >= 0 ? responseBodySize : Number(res.headers()['content-length'] || raw[file]);
    } catch (e) { /* gone */ }
  });
  await inscribe(page, { message: LONG });
  await page.waitForTimeout(3500);
  const bytes = Object.values(sizes).reduce((a, b) => a + b, 0);
  const rawBytes = Object.values(raw).reduce((a, b) => a + b, 0);
  check('budget', `scripts and styles under ${BUDGET.bytes / 1000} KB as transferred (${Math.round(bytes / 1000)} KB; ${Math.round(rawBytes / 1000)} KB unpacked)`, bytes > 0 && bytes <= BUDGET.bytes, JSON.stringify(sizes));
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
  await pathless();
  await bench();
  await pathlessBench();
  await notebook();
  await expert();
  await room();
  await zoom();
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
