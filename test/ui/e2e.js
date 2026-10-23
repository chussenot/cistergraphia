// The end-to-end suite: every choice the form offers, followed to the reader.
// Run: bundle exec rake ui:e2e (test/ui/e2e.rb boots the app)
//   node test/ui/e2e.js BASE_URL WORK_DIR [CHROMIUM_PATH]
//   BROWSER=chromium|firefox|webkit (default chromium); E2E_ONLY=worn runs the cases whose name has the word
//
// Each case is written on the form as a person writes it: the layout, then the
// reader's puzzle (condition, tablet, path), the message, Inscribe. Then:
// - a plate the server makes is drawn whole on its page: the figure has a size,
//   every stroke ends up inked (the inking runs to its end), a worn plate shows
//   its lacunae hatched, and nothing errs in the page
// - a plate the server refuses comes back with the reason beside its choice
//   and the message kept
// - the file, brought to Read as a reader brings it, opens as its puzzle (the
//   rung the plate was made for), drawn whole too, and Decipher it reads the
//   message back (an edition with its doubts on a worn plate)
// Phone and desktop alternate case by case; a few cases run with motion on, so
// the inking's animation is followed to its end as well.
const fs = require('fs');
const path = require('path');
const playwright = require('playwright');

const [baseUrl, workDir, executablePath] = process.argv.slice(2);
const BROWSER = process.env.BROWSER || 'chromium';
const ONLY = process.env.E2E_ONLY || '';
const PASSPHRASE = 'abbey of molesme';
const MESSAGES = {
  short: 'Ora et labora',
  mid: 'Meet me at the old abbey after vespers',
  long: 'the brothers will gather in the chapter house at dawn and the abbot will speak of the harvest and the vineyards '.repeat(5).slice(0, 500)
};
const LAYOUTS = ['phaistos', 'rongorongo', 'leap', 'furrows', 'unwinding', 'grille'];
const CONDITIONS = ['intact', 'worn', 'broken', 'ruined'];
const normalize = (text) => text.toLowerCase().replace(/[^a-z ]/g, ' ').replace(/ +/g, ' ').trim(); // Cistergraphia.normalize

// What the server refuses, in its own rules (FormParams, Refusals): the choice that carries the reason
function refusal({ layout, condition, path: way, tablet, mode }) {
  const damaged = condition !== 'intact';
  if (mode === 'secret' && damaged) return 'condition';
  if (['broken', 'ruined'].includes(condition) && layout !== 'phaistos') return 'condition';
  if (way === 'withheld' && (mode === 'secret' || layout === 'grille' || ['broken', 'ruined'].includes(condition))) return 'path';
  if (tablet === 'own' && (mode === 'secret' || layout === 'grille' || damaged)) return 'tablet';
  return null;
}

// The rung the plate opens as on Read (views/play.erb), or 'decoded' for a sealed plate
function rungOf({ condition, path: way, tablet, mode }) {
  if (mode === 'secret') return 'decoded';
  if (condition === 'broken' || condition === 'ruined') return condition;
  if (way === 'withheld' && tablet === 'own') return 'expert';
  if (way === 'withheld') return 'pathless';
  if (tablet === 'own') return 'tablet';
  return condition === 'worn' ? 'worn' : 'intact';
}

function cases() {
  const list = [];
  for (const layout of LAYOUTS) {
    for (const condition of CONDITIONS) {
      for (const way of ['shown', 'withheld']) {
        for (const size of Object.keys(MESSAGES)) list.push({ layout, condition, path: way, tablet: 'shared', mode: 'game', size });
      }
    }
    for (const way of ['shown', 'withheld']) list.push({ layout, condition: 'intact', path: way, tablet: 'own', mode: 'game', size: 'mid' });
    list.push({ layout, condition: 'intact', path: 'shown', tablet: 'shared', mode: 'secret', size: 'mid' });
  }
  // With motion on: the inking animated, on worn plates and an intact one
  for (const layout of ['phaistos', 'leap']) list.push({ layout, condition: 'worn', path: 'shown', tablet: 'shared', mode: 'game', size: 'mid', motion: true });
  list.push({ layout: 'phaistos', condition: 'intact', path: 'shown', tablet: 'shared', mode: 'game', size: 'long', motion: true });
  return list.map((c) => ({ ...c, name: [c.mode, c.layout, c.condition, `path-${c.path}`, `tablet-${c.tablet}`, c.size, c.motion ? 'motion' : ''].filter(Boolean).join(' ') }))
    .filter((c) => !ONLY || c.name.split(' ').includes(ONLY));
}

// ---------- In the page ----------

// Until the plate's inking has run to its end (app.js inkPlate: ink-press, then ink-dry)
const inked = (page) => page.waitForFunction(() => {
  const svg = document.querySelector('[data-plate] svg');
  return svg && !svg.querySelector('path.ink-press, path.ink-dry');
}, null, { timeout: 30000 }).then(() => true, () => false);

// What the plate on the page shows: its size, its strokes and how many are inked, its lacunae
const plateShown = (page) => page.evaluate(() => {
  const svg = document.querySelector('[data-plate] svg');
  if (!svg) return null;
  const box = svg.getBoundingClientRect();
  const visible = (el) => {
    const style = getComputedStyle(el);
    return style.visibility !== 'hidden' && style.display !== 'none' && Number(style.opacity) > 0.05;
  };
  const strokes = Array.from(svg.querySelectorAll('path')).filter((p) => !p.closest('pattern, defs'));
  const lacunae = Array.from(svg.querySelectorAll('.weathering polygon, .weathering path'));
  return {
    width: Math.round(box.width),
    height: Math.round(box.height),
    strokes: strokes.length,
    unseen: strokes.filter((p) => !visible(p)).length,
    lacunae: lacunae.length,
    lacunaeUnseen: lacunae.filter((p) => !visible(p) || p.getBBox().width === 0).length,
    waiting: document.querySelectorAll('.awaits-script').length
  };
});

// ---------- One case ----------

async function inscribe(page, c) {
  await page.goto(`${baseUrl}/`);
  if (c.mode === 'secret') await page.click('label.segment--secret');
  await page.click(`label.segment:has(input[value="${c.layout}"])`);
  if (c.mode === 'game' && (c.condition !== 'intact' || c.path === 'withheld' || c.tablet === 'own')) {
    await page.click('.puzzle-summary'); // the reader's puzzle, shut on a plain plate
    if (c.condition !== 'intact') await page.click(`label.segment--${c.condition}`);
    if (c.tablet === 'own') await page.click('label.segment--tablet-own');
    if (c.path === 'withheld') await page.click('label.segment--path-withheld');
  }
  await page.fill('#message', MESSAGES[c.size]);
  if (c.mode === 'secret') await page.fill('#passphrase', PASSPHRASE);
  const [response] = await Promise.all([page.waitForNavigation(), page.click('[data-submit]')]);
  return response.status();
}

async function checkRefusal(page, c, expected, problems) {
  const said = await page.evaluate((id) => document.getElementById(id)?.textContent.trim(), `${expected}-error`);
  if (!said) problems.push(`refused without saying why beside ${expected}`);
  const kept = await page.inputValue('#message');
  if (kept !== MESSAGES[c.size]) problems.push('the message was not kept');
}

async function checkPlate(page, where, c, problems) {
  if (!(await inked(page))) problems.push(`${where}: the inking never ran to its end`);
  const shown = await plateShown(page);
  if (!shown) { problems.push(`${where}: no plate`); return; }
  if (shown.width < 100 || shown.height < 100) problems.push(`${where}: the plate is ${shown.width} × ${shown.height}`);
  if (shown.strokes < 4) problems.push(`${where}: ${shown.strokes} strokes`);
  if (shown.unseen) problems.push(`${where}: ${shown.unseen} of ${shown.strokes} strokes never inked`);
  const worn = c.condition === 'worn' || c.condition === 'ruined';
  if (worn && where === 'result' && !shown.lacunae) problems.push(`${where}: a worn plate with no lacunae drawn`);
  if (shown.lacunaeUnseen) problems.push(`${where}: ${shown.lacunaeUnseen} of ${shown.lacunae} lacunae not drawn`);
  if (shown.waiting && where === 'result') problems.push(`${where}: ${shown.waiting} parts still waiting for the script`);
}

// Read, as a reader brings the file: the passphrase or the grille key with it
async function bringToRead(page, c, file, key) {
  await page.goto(`${baseUrl}/decode`);
  await page.setInputFiles('#file', file);
  if (c.mode === 'secret') await page.fill('#passphrase', PASSPHRASE);
  if (key) await page.fill('#grille', key);
  const [response] = await Promise.all([page.waitForNavigation(), page.click('.entry [type="submit"]')]);
  return response.status();
}

async function checkDecipher(page, c, problems) {
  const message = normalize(MESSAGES[c.size]);
  if (c.mode !== 'secret') {
    const [response] = await Promise.all([page.waitForNavigation(), page.click('.readback [type="submit"]')]);
    if (response.status() !== 200) { problems.push(`decipher: HTTP ${response.status()}`); return; }
  }
  // The whole text (app.js keeps it in data-text while the letters reveal themselves, with motion on)
  const text = (await page.evaluate(() => { const el = document.querySelector('[data-transcription]'); return el && (el.dataset.text ?? el.textContent); }))?.trim();
  if (text == null) { problems.push('decipher: no transcription'); return; }
  if (c.condition === 'worn' || c.condition === 'ruined') {
    // An edition: each doubt a [..] group; the letters outside them are the message's, in order
    const known = text.replace(/\[[^\]]*\]/g, '');
    let at = 0;
    for (const char of known) { at = message.indexOf(char, at); if (at < 0) break; at += 1; }
    if (at < 0) problems.push(`decipher: the edition is not the message: “${text.slice(0, 60)}”`);
  } else if (text !== message) problems.push(`decipher: “${text.slice(0, 60)}” is not the message`);
}

async function run(page, c, errors) {
  const problems = [];
  const status = await inscribe(page, c);
  const expected = refusal(c);
  if (expected) {
    if (status !== 422) problems.push(`expected a refusal beside ${expected}, got HTTP ${status}`);
    else await checkRefusal(page, c, expected, problems);
    return problems;
  }
  if (status !== 200) return [`HTTP ${status} where a plate was expected`];
  await checkPlate(page, 'result', c, problems);
  const svg = await page.inputValue('.readback input[name="svg"]').catch(() => null);
  if (!svg) return [...problems, 'result: no file to send'];
  const key = c.layout === 'grille' ? (await page.textContent('code.grille-key')).trim() : null;
  const file = path.join(workDir, 'plate.svg');
  fs.writeFileSync(file, svg);
  const readStatus = await bringToRead(page, c, file, key);
  if (readStatus !== 200) return [...problems, `read: HTTP ${readStatus}`];
  const rung = rungOf(c);
  const opened = await page.evaluate(() => document.querySelector('[data-play]')?.dataset.play || (document.querySelector('[data-transcription]') ? 'decoded' : 'nothing'));
  if (opened !== rung) problems.push(`read: opened as ${opened}, not ${rung}`);
  if (rung !== 'decoded') await checkPlate(page, 'read', c, problems);
  await checkDecipher(page, c, problems);
  if (errors.length) problems.push(...errors.splice(0).map((e) => `page: ${e}`));
  return problems;
}

// ---------- Run ----------
(async () => {
  const launch = BROWSER === 'chromium' && executablePath ? { executablePath } : {};
  const browser = await playwright[BROWSER].launch(launch);
  console.log(`e2e.js on ${BROWSER}, ${browser.version()}`);
  const list = cases();
  const failed = [];
  const started = Date.now();
  for (const [i, c] of list.entries()) {
    const viewport = i % 2 ? { width: 390, height: 844 } : { width: 1280, height: 900 };
    const ctx = await browser.newContext({ viewport, reducedMotion: c.motion ? 'no-preference' : 'reduce' });
    const page = await ctx.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    let problems;
    try {
      problems = await run(page, c, errors);
    } catch (error) {
      problems = [`threw: ${error.message.split('\n')[0]}`];
    }
    await ctx.close();
    const where = `${viewport.width}px`;
    if (problems.length) failed.push({ c, problems, where });
    console.log(`${problems.length ? 'FAIL' : 'ok  '} ${c.name} (${where})${problems.length ? `\n       ${problems.join('\n       ')}` : ''}`);
  }
  await browser.close();
  console.log(`\n${list.length} cases, ${failed.length} failed on ${BROWSER}, in ${Math.round((Date.now() - started) / 1000)} s`);
  process.exit(failed.length ? 1 : 0);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
