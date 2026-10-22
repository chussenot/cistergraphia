// Layout stability check: nothing on the page moves under the reader.
// Run: bundle exec rake ui:stability (test/ui/stability.rb boots the app)
//   node test/ui/stability.js BASE_URL PLATE.svg [CHROMIUM_PATH]
//
// Each step snapshots where every element sits on the page (document
// coordinates, so scrolling does not count), does what a reader does, and
// measures the same elements again (tracked by identity, so nodes added or
// removed by the step are ignored). A step either expects stillness (no
// element's top or bottom moves by more than 1 px), or names an anchor, the
// one deliberate movement (the passphrase unfolding, a disclosure opening),
// above which nothing may move. Then every page is compared with JS on and
// off: the script arriving must move nothing.
//
// Runs with reduced motion, so each change settles within a frame and the
// result never depends on animation timing. Fonts are loaded first: a font
// swap on a first visit is not what this measures.
const { chromium } = require('playwright');

const [baseUrl, plateFile, executablePath] = process.argv.slice(2);
const weatheredFile = plateFile.replace(/\.svg$/, '-weathered.svg'); // written beside it by stability.rb
const brokenFile = plateFile.replace(/\.svg$/, '-broken.svg'); // and this one
const talliedFile = plateFile.replace(/\.svg$/, '-tallied.svg'); // and this one, with tally signs
const VIEWPORTS = [
  { width: 320, height: 640 }, // the smallest phone
  { width: 390, height: 844 }, // a common phone
  { width: 1024, height: 768 }, // two columns, the narrowest side leaf
  { width: 1280, height: 900 }
];
const TOLERANCE = 1; // px, for sub-pixel rounding
const MESSAGE = 'Meet me at the old abbey after vespers, under the cloister arches by the well';

// ---------- In the page: where everything is ----------

// The boxes worth measuring: laid-out blocks in the page's flow. Skipped: SVG
// internals (strokes move by design: morphs, the turned plate), inline boxes
// (text that rewraps in place; their block is measured), positioned boxes
// (they follow their container), and anything inside a sticky or fixed box
// (it follows the viewport as you scroll: the side leaf on wide screens).
function measurable() {
  const riding = Array.from(document.body.querySelectorAll('*'))
    .filter((el) => ['sticky', 'fixed'].includes(getComputedStyle(el).position));
  return Array.from(document.body.querySelectorAll('*')).filter((el) => {
    if (el.ownerSVGElement) return false;
    const style = getComputedStyle(el);
    if (['inline', 'contents', 'none'].includes(style.display)) return false;
    if (['fixed', 'absolute', 'sticky'].includes(style.position)) return false;
    if (riding.some((box) => box.contains(el))) return false;
    const r = el.getBoundingClientRect();
    return r.width > 0 || r.height > 0;
  });
}

// [element, top, bottom] for every measurable box, in document coordinates
function snapshot(anchorSelector) {
  const marks = measurable().map((el) => {
    const r = el.getBoundingClientRect();
    return [el, r.top + scrollY, r.bottom + scrollY];
  });
  const anchor = anchorSelector && document.querySelector(anchorSelector);
  window.__stability = { marks, anchor, anchorTop: anchor ? anchor.getBoundingClientRect().top + scrollY : null };
}

// The largest movement among the snapshot's elements, and who moved. With an
// anchor, only what sits above it counts: the anchor itself and what is in it
// are the deliberate movement, and its containers may grow (only their tops count).
function measure() {
  const { marks, anchor, anchorTop } = window.__stability;
  const name = (el) => {
    const cls = typeof el.className === 'string' && el.className.trim() ? `.${el.className.trim().split(/\s+/).join('.')}` : '';
    const text = (el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 30);
    return `${el.tagName.toLowerCase()}${el.id ? `#${el.id}` : ''}${cls}${text ? ` "${text}"` : ''}`;
  };
  let worst = { moved: 0, who: '' };
  for (const [el, top, bottom] of marks) {
    if (!el.isConnected) continue;
    const r = el.getBoundingClientRect();
    if (r.width === 0 && r.height === 0) continue;
    if (anchor && (anchor.contains(el) || top >= anchorTop - 1)) continue;
    const dTop = Math.abs(r.top + scrollY - top);
    const dBottom = anchor && el.contains(anchor) ? 0 : Math.abs(r.bottom + scrollY - bottom);
    const moved = Math.max(dTop, dBottom);
    if (moved > worst.moved) worst = { moved: Math.round(moved * 10) / 10, who: name(el) };
  }
  return worst;
}

// For JS on vs off: the top and bottom of every box, by its path in the DOM
function layoutByPath() {
  const out = {};
  const path = (el) => {
    const parts = [];
    for (let node = el; node && node !== document.body; node = node.parentElement) {
      parts.unshift(`${node.tagName}:${Array.prototype.indexOf.call(node.parentElement.children, node)}`);
    }
    return parts.join('/');
  };
  for (const el of measurable()) {
    if (el.closest('[hidden]')) continue;
    const r = el.getBoundingClientRect();
    out[path(el)] = [Math.round(r.top + scrollY), Math.round(r.bottom + scrollY), el.tagName.toLowerCase() + (el.className && typeof el.className === 'string' ? `.${el.className.trim().split(/\s+/)[0]}` : '')];
  }
  return out;
}

// Runs one of the functions above in the page, with the helper it shares
const inPage = (page, fn, arg = null) => page.evaluate(`(() => { ${measurable}\nreturn (${fn})(${JSON.stringify(arg)}); })()`);

// ---------- Reader actions ----------

const settle = (page) => page.evaluate(() => new Promise((resolve) => {
  requestAnimationFrame(() => requestAnimationFrame(resolve));
}));

// A plate written under a known grille
const openGrillePlate = async (page, decoy = '') => {
  await page.goto(`${baseUrl}/`);
  await page.fill('#message', MESSAGE);
  await page.click('label.segment:has(input[value="grille"])');
  await page.fill('#grille', 'k7q2m-zxb4p');
  if (decoy) await page.fill('#decoy', decoy);
  await page.click('[data-submit]');
  await page.waitForSelector('[data-plate] svg');
};

// A file brought to Read: a damaged plate opens as its puzzle (the bench, the
// board); "Decipher it" below asks the decoder, as the plain submit does for an intact plate
const bringToRead = (file, selector, decipher = false) => async (page) => {
  await page.goto(`${baseUrl}/decode`);
  await page.setInputFiles('#file', file);
  await Promise.all([page.waitForURL('**/decode'), page.click('.entry [type="submit"]')]);
  if (decipher) await Promise.all([page.waitForURL('**/decode'), page.click('.readback [type="submit"]')]);
  await page.waitForSelector(selector, { state: 'attached' }); // the bench and the board await the script
};

// A weathered plate: some strokes lost to the centuries
const openWeatheredPlate = async (page) => {
  await page.goto(`${baseUrl}/`);
  await page.fill('#message', MESSAGE);
  await page.check('input[value="worn"]', { force: true });
  await Promise.all([page.waitForURL('**/generate'), page.click('[data-submit]')]);
  await page.waitForSelector('[data-plate] svg');
};

// A broken plate: its fragments in a tray, below an empty board
const openBrokenPlate = async (page) => {
  await page.goto(`${baseUrl}/`);
  await page.fill('#message', MESSAGE);
  await page.check('input[value="broken"]', { force: true });
  await Promise.all([page.waitForURL('**/generate'), page.click('[data-submit]')]);
  await page.waitForSelector('[data-plate] svg');
};

// Lays the fragment picked on a board cell (its top-left corner), as a tap would
const layOnBoard = (page, x, y) => page.locator('[data-plate] svg rect.board').click({ position: { x, y } });

// One weathered plate page for both the JS-on and JS-off runs: two random
// plates would differ in their editions, which is not what the comparison is about
const pageOnce = new Map();
const openSamePlate = (form) => async (page) => {
  const key = JSON.stringify(form);
  if (!pageOnce.has(key)) {
    const response = await page.request.post(`${baseUrl}/generate`, { form });
    pageOnce.set(key, await response.text());
  }
  await page.goto(`${baseUrl}/`);
  await page.setContent(pageOnce.get(key), { waitUntil: 'load' });
  await page.waitForSelector('[data-plate] svg');
};

// The number a Lectio sign shows, read from its strokes with the page's own table
const lectioTarget = (page) => page.evaluate(() => {
  const key = (coords) => coords.join(',');
  const shown = Array.from(document.querySelectorAll('[data-lectio-sign] path'))
    .map((wedge) => wedge.dataset.stroke).sort().join(' ');
  for (let n = 0; n <= 9999; n += 1) {
    if (Ink.strokesOf(n).map((s) => key(s.coords)).sort().join(' ') === shown) return n;
  }
  return null;
});

const hoverPlate = async (page) => {
  const svg = page.locator('[data-plate] svg');
  await svg.scrollIntoViewIfNeeded();
  const box = await svg.boundingBox();
  for (const [fx, fy] of [[0.15, 0.15], [0.5, 0.5], [0.85, 0.85], [0.15, 0.85]]) {
    await page.mouse.move(box.x + (box.width * fx), box.y + (box.height * fy));
  }
};

// Flows run in order on one page: each step is measured on its own
const FLOWS = [
  {
    page: 'inscribe',
    open: (page) => page.goto(`${baseUrl}/`),
    steps: [
      { name: 'type a message', act: async (p) => { await p.click('#message'); await p.keyboard.type(MESSAGE); } },
      { name: 'edit at the start', act: async (p) => { await p.keyboard.press('Control+Home'); await p.keyboard.type('Brother, '); } },
      { name: 'delete', act: async (p) => { await p.keyboard.press('Control+End'); for (let i = 0; i < 30; i += 1) await p.keyboard.press('Backspace'); } },
      { name: 'wear the plate', act: (p) => p.click('label.segment--worn') },
      { name: 'break the plate', act: (p) => p.click('label.segment--broken') },
      { name: 'ruin it, along the rows', act: async (p) => { await p.click('label.segment--ruined'); await p.click('input[value="rongorongo"]', { force: true }); } },
      { name: 'back to the snail', act: (p) => p.click('input[value="phaistos"]', { force: true }) },
      { name: 'choose secret', anchor: '.entry-end', act: (p) => p.click('label.segment--secret') },
      { name: 'type a sealed message', act: async (p) => { await p.click('#message'); await p.keyboard.type(' and a seal'); } },
      { name: 'seal with too short a passphrase', act: async (p) => { await p.fill('#passphrase', 'short'); await p.click('[data-submit]'); } },
      { name: 'show the passphrase', act: async (p) => { await p.fill('#passphrase', 'abbey of molesme'); await p.click('[data-reveal="passphrase"]'); } },
      { name: 'back to game', anchor: '.entry-end', act: (p) => p.click('label.segment--game') },
      { name: 'choose rongorongo', act: (p) => p.click('label.segment:has(input[value="rongorongo"])') },
      { name: 'choose grille', anchor: '.entry-end', act: (p) => p.click('label.segment:has(input[value="grille"])') },
      { name: 'type a grille key', act: (p) => p.fill('#grille', 'k7q2m-zxb4p') },
      { name: "type a novice's message", act: async (p) => { await p.click('#decoy'); await p.keyboard.type('Vespers at six'); } },
      { name: 'back to phaistos', anchor: '.entry-end', act: (p) => p.click('label.segment:has(input[value="phaistos"])') },
      { name: 'turn the dials', act: async (p) => { for (const q of ['tens', 'units', 'hundreds', 'thousands']) await p.click(`.quadrant--${q}`); await p.keyboard.press('ArrowUp'); } }
    ]
  },
  {
    page: 'plate',
    open: async (page) => {
      await page.goto(`${baseUrl}/`);
      await page.fill('#message', MESSAGE);
      await page.click('label.segment:has(input[value="rongorongo"])');
      await page.click('[data-submit]');
      await page.waitForSelector('[data-plate] svg');
    },
    steps: [
      { name: 'walk with the keys', act: async (p) => { await p.focus('[data-plate]'); for (let i = 0; i < 10; i += 1) await p.keyboard.press('ArrowRight'); await p.keyboard.press('End'); } },
      { name: 'point at signs', act: hoverPlate },
      { name: 'turn the plate', act: (p) => p.click('[data-action="turn-plate"]') },
      { name: 'walk the turned plate', act: async (p) => { await p.focus('[data-plate]'); await p.keyboard.press('Home'); await p.keyboard.press('ArrowRight'); } },
      { name: 'leave the plate', act: (p) => p.keyboard.press('Escape') }
    ]
  },
  {
    page: 'grille',
    open: openGrillePlate,
    steps: [
      { name: 'lay the grille', act: (p) => p.click('[data-action="lay-grille"]') },
      { name: 'turn it to E, S, W', act: async (p) => { for (let i = 0; i < 3; i += 1) await p.click('[data-action="lay-grille"]'); } },
      { name: 'walk under the grille', act: async (p) => { await p.focus('[data-plate]'); await p.keyboard.press('Home'); await p.keyboard.press('ArrowRight'); } },
      { name: 'lift the grille', act: (p) => p.click('[data-action="lay-grille"]') },
      { name: 'copy the key', act: (p) => p.click('[data-action="copy-key"]') }
    ]
  },
  {
    page: 'two readers',
    open: async (page) => {
      await openGrillePlate(page, 'Vespers at six in the choir');
    },
    steps: [
      { name: "lay the abbot's grille", act: (p) => p.click('[data-action="lay-grille"]') },
      { name: "choose the novice's grille", act: (p) => p.click('[data-grille-choice="novice"]') },
      { name: "lay and turn the novice's", act: async (p) => { for (let i = 0; i < 3; i += 1) await p.click('[data-action="lay-grille"]'); } },
      { name: "copy the novice's key", act: (p) => p.click('[data-action="copy-key"] >> nth=1') }
    ]
  },
  {
    page: 'weathered',
    open: openWeatheredPlate,
    steps: [
      { name: 'walk the worn signs', act: async (p) => { await p.focus('[data-plate]'); for (let i = 0; i < 12; i += 1) await p.keyboard.press('ArrowRight'); await p.keyboard.press('End'); } },
      { name: 'point at signs', act: hoverPlate },
      { name: 'choose a lacuna on the plate', act: (p) => p.click('.bench-target >> nth=2', { force: true }) },
      { name: 'press every digit', act: async (p) => { for (const button of await p.locator('[data-digit]:not([disabled])').all()) await button.click(); } },
      { name: 'take a digit back', act: async (p) => { const pressed = p.locator('[data-digit][aria-pressed="true"]'); if (await pressed.count()) await pressed.click(); } },
      { name: 'step through the lacunae', act: async (p) => { for (let i = 0; i < 4; i += 1) await p.click('[data-bench-step="1"]'); await p.click('[data-bench-step="-1"]'); } }
    ]
  },
  {
    page: 'tallied',
    open: bringToRead(talliedFile, '[data-bench]'),
    steps: [
      { name: 'press digits into a whole sign', act: async (p) => { for (let i = 0; i < 4; i += 1) { const free = p.locator('[data-digit]:not([disabled])'); await free.nth(i % (await free.count())).click(); await p.click('[data-bench-step="1"]'); } } },
      { name: 'step back', act: (p) => p.click('[data-bench-step="-1"]') }
    ]
  },
  {
    page: 'broken',
    open: openBrokenPlate,
    steps: [
      { name: 'pick a fragment', act: (p) => p.click('[data-plate] svg g.fragment >> nth=0', { position: { x: 12, y: 12 } }) },
      { name: 'lay it on the board', act: (p) => layOnBoard(p, 4, 4) },
      { name: 'move it with the keys', act: async (p) => { for (const key of ['ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp']) await p.keyboard.press(key); } },
      { name: 'turn it', act: async (p) => { await p.keyboard.press('t'); await p.click('[data-rejoin-turn]'); } },
      // Laid one above the other, the fragments sometimes rejoin by chance (a
      // plate broken straight across, nothing turned): then what it reads is
      // revealed, the one deliberate movement, so only what is above it counts
      {
        name: 'lay them all with the keys',
        anchor: '[data-rejoin-reading]',
        act: async (p) => {
          const count = await p.locator('[data-plate] svg g.fragment').count();
          for (let i = 0; i < count; i += 1) { // picked, then up and left cell by cell, onto the board
            await p.locator(`[data-plate] svg g.fragment[aria-label^="Fragment ${i + 1} "]`).click({ position: { x: 12, y: 12 } });
            for (let k = 0; k < 16; k += 1) await p.keyboard.press('ArrowUp');
            for (let k = 0; k < 16; k += 1) await p.keyboard.press('ArrowLeft');
          }
        }
      },
      { name: 'back to the tray', anchor: '[data-rejoin-reading]', act: (p) => p.click('[data-rejoin-reset]') }
    ]
  },
  {
    page: 'decoded',
    open: async (page) => {
      await page.goto(`${baseUrl}/decode`);
      await page.setInputFiles('#file', plateFile);
      await page.click('.entry [type="submit"]');
      await page.waitForSelector('[data-transcription]');
    },
    steps: [
      { name: 'copy the text', act: (p) => p.click('[data-action="copy-text"]') }
    ]
  },
  {
    page: 'restore',
    open: bringToRead(weatheredFile, '[data-bench]'),
    steps: [
      { name: 'walk the worn signs', act: async (p) => { await p.focus('[data-plate]'); for (let i = 0; i < 12; i += 1) await p.keyboard.press('ArrowRight'); } },
      { name: 'choose a lacuna on the plate', act: (p) => p.click('.bench-target >> nth=1', { force: true }) },
      { name: 'press every digit', act: async (p) => { for (const button of await p.locator('[data-digit]:not([disabled])').all()) await button.click(); } },
      { name: 'step through the lacunae', act: async (p) => { for (let i = 0; i < 4; i += 1) await p.click('[data-bench-step="1"]'); await p.click('[data-bench-step="-1"]'); } }
    ]
  },
  {
    page: 'rejoin',
    open: bringToRead(brokenFile, '[data-rejoin]'),
    steps: [
      { name: 'pick a fragment', act: (p) => p.click('[data-plate] svg g.fragment >> nth=0', { position: { x: 12, y: 12 } }) },
      { name: 'lay it on the board', act: (p) => layOnBoard(p, 4, 4) },
      { name: 'move it with the keys', act: async (p) => { for (const key of ['ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp']) await p.keyboard.press(key); } },
      { name: 'turn it', act: async (p) => { await p.keyboard.press('t'); await p.click('[data-rejoin-turn]'); } },
      { name: 'back to the tray', anchor: '[data-rejoin-reading]', act: (p) => p.click('[data-rejoin-reset]') }
    ]
  },
  {
    page: 'edition',
    open: bringToRead(weatheredFile, '[data-transcription]', true),
    steps: [
      { name: 'copy the edition', act: (p) => p.click('[data-action="copy-text"]') }
    ]
  },
  {
    page: 'read',
    open: (page) => page.goto(`${baseUrl}/decode`),
    steps: [
      { name: 'choose a file', act: (p) => p.setInputFiles('#file', plateFile) },
      { name: 'type a passphrase', act: async (p) => { await p.fill('#passphrase', 'abbey of molesme'); await p.click('[data-reveal="passphrase"]'); } },
      { name: 'type a grille key', act: (p) => p.fill('#grille', 'k7q2m-zxb4p') },
      { name: 'open the paste box', anchor: 'details.paste', act: (p) => p.click('details.paste summary') }
    ]
  },
  {
    page: 'about',
    open: (page) => page.goto(`${baseUrl}/about`),
    steps: [
      { name: 'playground: type numbers', act: async (p) => { for (const n of ['0', '7', '1153', '9999', '']) await p.fill('[data-playground]', n); } },
      { name: 'playground: presets', act: async (p) => { for (const b of await p.locator('[data-playground-set]').all()) await b.click(); } },
      { name: 'lectio: empty answer', act: (p) => p.click('[data-lectio-submit]') },
      { name: 'lectio: misread every corner', act: async (p) => { await p.fill('[data-lectio-answer]', '5550'); await p.click('[data-lectio-submit]'); } },
      { name: 'lectio: next sign', act: (p) => p.click('[data-lectio-submit]') },
      {
        name: 'lectio: read it right',
        act: async (p) => {
          await p.fill('[data-lectio-answer]', String(await lectioTarget(p)));
          await p.click('[data-lectio-submit]');
          await p.waitForFunction(() => document.querySelector('[data-lectio-answer]').value === ''); // the next sign
        }
      }
    ]
  }
];

// Pages to compare with JS on and off (forms post without JS too)
const PAGES = [
  { page: 'inscribe', open: (page) => page.goto(`${baseUrl}/`) },
  {
    page: 'plate',
    open: async (page) => {
      await page.goto(`${baseUrl}/`);
      await page.fill('#message', MESSAGE);
      await page.check('input[value="rongorongo"]', { force: true });
      await Promise.all([page.waitForURL('**/generate'), page.click('[data-submit]')]);
      await page.waitForSelector('[data-plate] svg');
    }
  },
  {
    page: 'grille',
    open: async (page) => {
      await page.goto(`${baseUrl}/`);
      await page.fill('#message', MESSAGE);
      await page.check('input[value="grille"]', { force: true });
      await page.fill('#grille', 'k7q2m-zxb4p');
      await Promise.all([page.waitForURL('**/generate'), page.click('[data-submit]')]);
      await page.waitForSelector('[data-plate] svg');
    }
  },
  { page: 'weathered', open: openSamePlate({ message: MESSAGE, condition: 'worn' }) },
  { page: 'tallied', open: bringToRead(talliedFile, '[data-bench]') },
  { page: 'broken', open: openSamePlate({ message: MESSAGE, condition: 'broken' }) },
  { page: 'worn+broken', open: openSamePlate({ message: MESSAGE, condition: 'ruined' }) },
  { page: 'restore', open: bringToRead(weatheredFile, '[data-bench]') },
  { page: 'rejoin', open: bringToRead(brokenFile, '[data-rejoin]') },
  { page: 'edition', open: bringToRead(weatheredFile, '[data-transcription]', true) },
  { page: 'read', open: (page) => page.goto(`${baseUrl}/decode`) },
  {
    page: 'decoded',
    open: async (page) => {
      await page.goto(`${baseUrl}/decode`);
      await page.setInputFiles('#file', plateFile);
      await Promise.all([page.waitForURL('**/decode'), page.click('.entry [type="submit"]')]);
      await page.waitForSelector('[data-transcription]');
    }
  },
  { page: 'about', open: (page) => page.goto(`${baseUrl}/about`) }
];

async function ready(page, javaScriptEnabled = true) {
  await page.evaluate(() => document.fonts.ready);
  if (javaScriptEnabled) await settle(page); // without JS no frame callback ever runs, and nothing changes
}

const line = (r) => {
  const moved = r.moved > TOLERANCE;
  const scope = r.anchor ? ` (above ${r.anchor})` : '';
  return `${moved ? 'MOVED' : 'still'}  ${String(r.viewport).padStart(4)}px  ${r.page.padEnd(9)} ${r.step}${scope}${moved ? `  ${r.moved}px: ${r.who}` : ''}`;
};
const report = (results, r) => {
  results.push(r);
  console.log(line(r));
};

(async () => {
  const browser = await chromium.launch(executablePath ? { executablePath } : {});
  const results = [];
  const errors = [];

  for (const viewport of VIEWPORTS) {
    const context = await browser.newContext({ viewport, reducedMotion: 'reduce' });
    const page = await context.newPage();
    page.on('pageerror', (error) => errors.push(`${viewport.width}px: ${error.message}`));
    for (const flow of FLOWS) {
      await flow.open(page);
      await ready(page);
      for (const step of flow.steps) {
        await inPage(page, snapshot, step.anchor || null);
        await step.act(page);
        await settle(page);
        report(results, { viewport: viewport.width, page: flow.page, step: step.name, anchor: step.anchor, ...(await inPage(page, measure)) });
      }
    }
    await context.close();

    for (const { page: name, open } of PAGES) {
      const layouts = [];
      for (const javaScriptEnabled of [false, true]) {
        const ctx = await browser.newContext({ viewport, reducedMotion: 'reduce', javaScriptEnabled });
        const p = await ctx.newPage();
        await open(p);
        await ready(p, javaScriptEnabled);
        layouts.push(await inPage(p, layoutByPath));
        await ctx.close();
      }
      const [off, on] = layouts;
      let worst = { moved: 0, who: '' };
      for (const [key, [top, bottom, who]] of Object.entries(on)) {
        if (!(key in off)) continue;
        const moved = Math.max(Math.abs(top - off[key][0]), Math.abs(bottom - off[key][1]));
        if (moved > worst.moved) worst = { moved, who };
      }
      report(results, { viewport: viewport.width, page: name, step: 'the script arrives', ...worst });
    }
  }
  await browser.close();

  const failures = results.filter((r) => r.moved > TOLERANCE);
  errors.forEach((error) => console.log(`ERROR  ${error}`));
  console.log(`\n${results.length} checks, ${failures.length} moved, ${errors.length} page errors`);
  process.exit(failures.length || errors.length ? 1 : 0);
})().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
