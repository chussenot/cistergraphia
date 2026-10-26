// Cistergraphia web UI: progressive enhancement only.
// Every form works without this file. It adds the mode switch, the live
// preview, the dials, the walkable plate, the grille, Lectio, exports and drag & drop.
// Motion comes from ink.js, and only where it carries meaning.
(() => {
  'use strict';

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  const SVG_NS = 'http://www.w3.org/2000/svg';
  const { reducedMotion } = window.Ink;
  const PLACE_NAMES = { 1: 'units', 10: 'tens', 100: 'hundreds', 1000: 'thousands' };
  const TURNS = ['N', 'E', 'S', 'W']; // the grille's four positions
  // The hand's motions beyond ink, told to whoever listens (sound.js)
  const hand = (kind, detail = {}) => document.dispatchEvent(new CustomEvent(`hand:${kind}`, { detail }));

  // ---------- Toast ----------
  let toastTimer;
  function toast(text) {
    const el = $('#toast');
    if (!el) return;
    el.textContent = text;
    el.classList.add('is-visible');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove('is-visible'), 2200);
  }

  // "1 thousand · 0 hundreds · 9 tens · 8 units"
  function reading(num) {
    return [[1000, 'thousand'], [100, 'hundred'], [10, 'ten'], [1, 'unit']].map(([place, one]) => {
      const digit = Math.floor(num / place) % 10;
      return `${digit} ${digit === 1 ? one : PLACE_NAMES[place]}`;
    }).join(' · ');
  }

  // Light (or unlight) the strokes of some places in a sign. Red must mean one
  // thing at a time: lighting dries any wet ink first, so only the lit corner
  // stays in the mode's colour.
  function light(svg, places, on = true) {
    $$('path', svg).forEach((wedge) => {
      if (on) Ink.dry(wedge);
      wedge.classList.toggle('is-lit', on && places.includes(Number(wedge.dataset.place)));
    });
  }

  // ---------- Mode switch (game = red, secret = blue; the ink crossfades in CSS) ----------
  // What shows and hides with the mode is CSS (:has), laid out from the first
  // paint; this only sets the page's ink, the button and the passphrase's rules.
  function initModes() {
    const form = $('[data-entry]');
    if (!form) return;
    const submit = $('[data-submit]', form);
    const passphrase = $('#passphrase', form);
    const rungs = $$('[data-rung]:not([value="intact"])', form);

    const apply = () => {
      const mode = $('input[name="mode"]:checked', form)?.value || 'game';
      document.body.dataset.mode = mode;
      const secret = mode === 'secret';
      if (passphrase) {
        passphrase.disabled = !secret;
        passphrase.required = secret;
      }
      rungs.forEach((rung) => { rung.disabled = secret; }); // a sealed plate cannot weather or break
      if (secret && rungs.some((rung) => rung.checked)) $('[data-rung][value="intact"]', form).checked = true;
      if (submit) submit.textContent = secret ? 'Seal & inscribe' : 'Inscribe';
      if (!secret) explain('');
    };

    // A passphrase that cannot seal is explained in place (the hint's cell),
    // with the server's own words, before anything is sent
    const error = $('[data-passphrase-error]', form);
    const min = Number(passphrase?.getAttribute('minlength')) || 8;
    const explain = (text) => {
      if (!error) return;
      error.textContent = text;
      if (text) passphrase.setAttribute('aria-invalid', 'true');
      else passphrase.removeAttribute('aria-invalid');
    };
    const problem = () => {
      const length = Array.from(passphrase.value).length; // characters, as the server counts them
      if (length === 0) return error.dataset.missing;
      return length < min ? error.dataset.tooShort : '';
    };
    if (passphrase && error) {
      const refuse = (event) => {
        if (passphrase.disabled || !problem()) return;
        event.preventDefault();
        explain(problem());
        passphrase.focus();
      };
      passphrase.addEventListener('invalid', refuse); // instead of the browser's bubble
      form.addEventListener('submit', refuse);
      passphrase.addEventListener('input', () => { if (error.textContent && !problem()) explain(''); });
    }

    $$('input[name="mode"]', form).forEach((radio) => radio.addEventListener('change', apply));
    apply();
  }

  // ---------- Layout: the key's order of reading follows the choice ----------
  // CSS shows the chosen figure in the space both share; this inks its path
  // again, so the new order is written, not swapped in.
  function initLayouts() {
    const form = $('[data-entry]');
    if (!form || reducedMotion) return;
    $$('input[name="layout"]', form).forEach((radio) => radio.addEventListener('change', () => {
      const path = $(`[data-layout-note="${radio.value}"] polyline`);
      if (path) path.replaceWith(path.cloneNode(true));
    }));
  }

  // ---------- Character counter ----------
  function initCounter() {
    const field = $('[data-counted]');
    const counter = $('[data-counter]');
    if (!field || !counter) return;
    const count = $('[data-count]', counter);
    const max = Number(field.getAttribute('maxlength')) || 500;
    const form = field.closest('form');
    const SHORT = 6; // words: under this, a tablet of the plate's own is close to guessing (Cistergraphia::Tablet::SHORT)
    const update = () => {
      count.textContent = field.value.length;
      counter.classList.toggle('is-near', field.value.length > max * 0.9);
      form?.classList.toggle('is-short', field.value.trim().split(/\s+/).filter(Boolean).length < SHORT);
    };
    field.addEventListener('input', update);
    update();
  }

  // ---------- The reader's puzzle: its summary says what it holds ----------
  function initPuzzle() {
    const puzzle = $('[data-puzzle]');
    const state = $('[data-puzzle-state]');
    if (!puzzle || !state) return;
    const checked = (name) => $(`input[name="${name}"]:checked`, puzzle);
    const say = () => {
      const rung = checked('condition')?.closest('label').querySelector('.segment-title').textContent || 'Intact';
      const tablet = checked('tablet')?.value === 'own' ? 'its own tablet' : 'shared tablet';
      const path = checked('path')?.value === 'withheld' ? 'path withheld' : 'path shown';
      state.textContent = `${rung}, ${tablet}, ${path}`; // FormParams#puzzle_state
    };
    puzzle.addEventListener('change', say);
  }

  // ---------- Show / hide passphrase ----------
  function initReveal() {
    $$('[data-reveal]').forEach((button) => {
      const input = document.getElementById(button.dataset.reveal);
      if (!input) return;
      button.addEventListener('click', () => {
        const show = input.type === 'password';
        input.type = show ? 'text' : 'password';
        button.textContent = show ? 'Hide' : 'Show';
        button.setAttribute('aria-pressed', String(show));
        input.focus();
      });
    });
  }

  // ---------- Live preview: each new letter is pressed as you type ----------
  // The strip has a fixed height and scrolls sideways, keeping the letter at
  // the caret in view: typing never moves anything else on the page.
  function initPreview() {
    const preview = $('[data-preview]');
    const field = $('[data-counted]');
    if (!preview || !field || !Ink.glyphTable()) return;
    const list = $('[data-preview-signs]', preview);
    const tablet = Ink.glyphTable().tablet;
    let shown = [];
    let frame;

    const item = (char, delay) => {
      const li = document.createElement('li');
      li.appendChild(Ink.glyph(tablet[char], { inked: true, delay }));
      const caption = document.createElement('span');
      caption.textContent = char === ' ' ? '·' : char;
      if (char === ' ') li.classList.add('is-space');
      li.appendChild(caption);
      return li;
    };

    // Scroll the strip (never the page) so the sign at the caret is visible
    const follow = () => {
      const at = Math.min(Ink.normalize(field.value.slice(0, field.selectionEnd)).length, shown.length) - 1;
      const li = list.children[Math.max(at, 0)];
      if (!li) return;
      const left = li.offsetLeft - list.offsetLeft;
      const right = left + li.offsetWidth;
      let target = list.scrollLeft;
      if (right > list.scrollLeft + list.clientWidth) target = right - list.clientWidth + 8;
      else if (left < list.scrollLeft) target = Math.max(left - 8, 0);
      if (target !== list.scrollLeft) list.scrollTo({ left: target, behavior: reducedMotion ? 'auto' : 'smooth' });
    };

    const render = () => {
      const chars = Array.from(Ink.normalize(field.value));
      let same = 0;
      while (same < shown.length && same < chars.length && shown[same] === chars[same]) same += 1;
      $$('li', list).slice(same).forEach((li) => li.remove());
      chars.slice(same).forEach((char, i) => list.appendChild(item(char, i * 40)));
      shown = chars;
      preview.classList.toggle('is-empty', chars.length === 0);
      follow();
    };
    field.addEventListener('input', () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(render);
    });
    render();
  }

  // ---------- The anatomy: four corners, four dials ----------
  const YEAR = new Date().getFullYear();
  const DATES = {
    1098: 'the founding of Cîteaux',
    1115: 'Bernard founds Clairvaux',
    1153: 'the death of Bernard of Clairvaux',
    [YEAR]: 'this year'
  };

  function initAnatomy() {
    const figure = $('[data-anatomy]');
    if (!figure || !Ink.glyphTable()) return;
    const svg = $('svg.glyph', figure);
    const caption = $('[data-anatomy-caption]', figure);
    const dials = $$('[data-place]', figure);
    let number = Number(figure.dataset.number);
    Ink.adopt(svg, number);

    const update = () => {
      dials.forEach((dial) => {
        const place = Number(dial.dataset.place);
        const digit = Math.floor(number / place) % 10;
        $('[data-digit]', dial).textContent = digit;
        dial.setAttribute('aria-label', `${PLACE_NAMES[place]}: ${digit}. Press, or use the arrow keys, to turn it.`);
      });
      caption.textContent = DATES[number] ? `${number}, ${DATES[number]}` : String(number);
      svg.setAttribute('aria-label', `The sign for ${number}: ${reading(number)}`);
    };

    const turn = (place, delta) => {
      const digit = Math.floor(number / place) % 10;
      number += (((digit + delta + 10) % 10) - digit) * place;
      Ink.morph(svg, number);
      update();
      requestAnimationFrame(() => light(svg, [place]));
    };

    dials.forEach((dial) => {
      const place = Number(dial.dataset.place);
      dial.disabled = false;
      dial.addEventListener('click', () => turn(place, 1));
      dial.addEventListener('keydown', (event) => {
        if (event.key !== 'ArrowUp' && event.key !== 'ArrowDown') return;
        event.preventDefault();
        turn(place, event.key === 'ArrowUp' ? 1 : -1);
      });
      ['pointerenter', 'focus'].forEach((type) => dial.addEventListener(type, () => light(svg, [place])));
      ['pointerleave', 'blur'].forEach((type) => dial.addEventListener(type, () => light(svg, [], false)));
    });
    $('[data-anatomy-hint]', figure).classList.remove('awaits-script');
    update();
  }

  // ---------- Playground: any number, its sign (About page) ----------
  function initPlayground() {
    const input = $('[data-playground]');
    if (!input || !Ink.glyphTable()) return;
    const holder = $('[data-playground-glyph]');
    const text = $('[data-playground-reading]');
    const svg = $('svg', holder);
    Ink.adopt(svg, Number(input.value) || 0);
    const update = () => {
      const value = Math.trunc(Number(input.value));
      if (input.value === '' || !Number.isFinite(value) || value < 0 || value > 9999) {
        input.setAttribute('aria-invalid', 'true');
        return;
      }
      input.removeAttribute('aria-invalid');
      Ink.morph(svg, value, { label: `The Cistercian sign for ${value}` });
      text.textContent = reading(value);
    };
    input.addEventListener('input', update);
    $$('[data-playground-set]').forEach((button) => button.addEventListener('click', () => {
      input.value = button.dataset.playgroundSet;
      update();
    }));
  }

  // ---------- Lectio: read the sign, from novice to abbot ----------
  const RANKS = [
    { from: 0, name: 'Novice', min: 1, max: 9 },
    { from: 3, name: 'Monk', min: 10, max: 99 },
    { from: 6, name: 'Prior', min: 100, max: 999 },
    { from: 9, name: 'Abbot', min: 1000, max: 9999 }
  ];
  const BEST_KEY = 'cistergraphia.lectio.best';
  const rankFor = (streak) => RANKS.filter((rank) => streak >= rank.from).pop();

  function storedBest() {
    try { return Number(localStorage.getItem(BEST_KEY)) || 0; } catch (error) { return 0; }
  }
  function storeBest(best) {
    try { localStorage.setItem(BEST_KEY, String(best)); } catch (error) { /* private mode: keep it in memory */ }
  }

  function initLectio() {
    const game = $('[data-lectio]');
    if (!game || !Ink.glyphTable()) return;
    const holder = $('[data-lectio-sign]', game);
    const form = $('[data-lectio-form]', game);
    const answer = $('[data-lectio-answer]', game);
    const submit = $('[data-lectio-submit]', game);
    const feedback = $('[data-lectio-feedback]', game);
    let streak = 0;
    let best = storedBest();
    let target;
    let reviewing = false;

    const standing = () => {
      $('[data-lectio-rank]', game).textContent = rankFor(streak).name;
      $('[data-lectio-streak]', game).textContent = streak;
      $('[data-lectio-best]', game).textContent = best;
    };

    const next = () => {
      const { min, max } = rankFor(streak);
      target = min + Math.floor(Math.random() * (max - min + 1));
      holder.replaceChildren(Ink.glyph(target, { label: 'A Cistercian sign to read', inked: true }));
      answer.value = '';
      reviewing = false;
      submit.textContent = 'Read';
    };

    form.addEventListener('submit', (event) => {
      event.preventDefault();
      if (reviewing) {
        next();
        answer.focus();
        return;
      }
      if (answer.value.trim() === '') {
        feedback.textContent = 'Type the number you read.';
        return;
      }
      const value = Math.trunc(Number(answer.value));
      const svg = $('svg', holder);
      if (value === target) {
        const before = rankFor(streak).name;
        streak += 1;
        best = Math.max(best, streak);
        storeBest(best);
        const after = rankFor(streak).name;
        feedback.textContent = after === before ? `Yes: ${target}.` : `Yes: ${target}. ${streak} in a row: you are now ${after === 'Abbot' ? 'an' : 'a'} ${after.toLowerCase()}.`;
        light(svg, [1, 10, 100, 1000]);
        standing();
        setTimeout(next, reducedMotion ? 300 : 900);
      } else {
        const misread = Ink.PLACES.filter((place, i) => Ink.digitsOf(value)[i] !== Ink.digitsOf(target)[i]);
        light(svg, misread);
        // An empty corner is a zero: easy to miss, so say it (grouped, to stay short)
        const isEmpty = (place) => Math.floor(target / place) % 10 === 0;
        const names = (places) => places.map((place) => PLACE_NAMES[place]).join(', ').replace(/, ([^,]*)$/, ' and $1');
        const filled = misread.filter((place) => !isEmpty(place));
        const empty = misread.filter(isEmpty);
        const parts = [];
        if (filled.length) parts.push(`the ${names(filled)}`);
        if (empty.length) parts.push(`the empty ${names(empty)} ${empty.length > 1 ? 'corners' : 'corner'} (0)`);
        feedback.textContent = `It reads ${target}. Look again at ${parts.join(', and ')}.`;
        streak = 0;
        reviewing = true;
        submit.textContent = 'Next sign';
        standing();
      }
    });

    // The first sign is the one the server drew: take it over, don't redraw it
    target = Number(holder.dataset.number);
    Ink.adopt($('svg', holder), target);
    answer.disabled = false;
    submit.disabled = false;
    standing();
  }

  // ---------- The scriptorium record: plates read on this browser, by rung ----------
  // Counts only, no times, no streaks: a record of a scribe's and a reader's
  // exchange, not a leaderboard. The Read page shows it; a plate won on the
  // reader's page (read to the end, every pair balanced, whole again) adds one
  const RECORD_KEY = 'cistergraphia.record';
  const RUNGS = ['intact', 'worn', 'broken', 'ruined', 'pathless', 'tablet', 'expert'];
  // How a count is said in the record: a rung's name, or its phrase
  const RUNG_WORDS = {
    tablet: (n) => (n === 1 ? 'with its own tablet' : 'with their own tablets'),
    expert: (n) => (n === 1 ? 'pathless with its own tablet' : 'pathless with their own tablets')
  };
  function storedRecord() {
    const empty = Object.fromEntries(RUNGS.map((rung) => [rung, 0]));
    try {
      const stored = JSON.parse(localStorage.getItem(RECORD_KEY) || '{}');
      return Object.fromEntries(RUNGS.map((rung) => [rung, Math.max(0, Math.trunc(Number(stored[rung])) || 0)]));
    } catch (error) { return empty; }
  }
  function recordLine(record) {
    const total = RUNGS.reduce((sum, rung) => sum + record[rung], 0);
    if (!total) return '';
    const parts = RUNGS.filter((rung) => record[rung]).map((rung) => `${record[rung]} ${RUNG_WORDS[rung] ? RUNG_WORDS[rung](record[rung]) : rung}`);
    const listed = parts.length > 1 ? `${parts.slice(0, -1).join(', ')} and ${parts.at(-1)}` : parts[0];
    return `${total} ${total === 1 ? 'plate' : 'plates'} read, ${listed}.`;
  }
  // The day's chapters read, by date (2026-10-26): a count, never a streak.
  // A chapter read twice is counted once, as a plate is not read twice
  const CHAPTERS_KEY = 'cistergraphia.chapters';
  function storedChapters() {
    try {
      const stored = JSON.parse(localStorage.getItem(CHAPTERS_KEY) || '[]');
      return Array.isArray(stored) ? stored.filter((date) => /^\d{4}-\d{2}-\d{2}$/.test(date)) : [];
    } catch (error) { return []; }
  }
  function chaptersLine(chapters) {
    return chapters.length ? `${chapters.length} ${chapters.length === 1 ? 'chapter' : 'chapters'} of the day.` : '';
  }
  // A chapter read: its date entered once, and its source shown
  function recordChapter() {
    const date = $('[data-chapter]')?.dataset.chapter;
    if (!date) return '';
    const source = $('[data-chapter-source]');
    if (source) source.hidden = false;
    const chapters = storedChapters();
    if (!chapters.includes(date)) {
      chapters.push(date);
      try { localStorage.setItem(CHAPTERS_KEY, JSON.stringify(chapters.sort())); } catch (error) { /* private mode: not kept */ }
    }
    return chaptersLine(chapters);
  }
  let recordedHere = false;
  function recordWin() {
    const rung = $('[data-play]')?.dataset.play;
    if (!rung || !RUNGS.includes(rung) || recordedHere) return;
    recordedHere = true;
    hand('bell');
    const record = storedRecord();
    record[rung] += 1;
    try { localStorage.setItem(RECORD_KEY, JSON.stringify(record)); } catch (error) { /* private mode: not kept */ }
    const chapters = recordChapter();
    const line = $('[data-record="play"]');
    if (line) line.textContent = `Entered in your scriptorium: ${recordLine(record)}${chapters ? ` ${chapters}` : ''}`;
  }
  function initRecord() {
    // A chapter already read on this browser says so, before it is read again
    const date = $('[data-chapter]')?.dataset.chapter;
    const play = $('[data-record="play"]');
    if (date && play && storedChapters().includes(date)) play.textContent = 'This chapter is in your scriptorium already.';
    const line = $('[data-record="read"]');
    if (!line) return;
    // One line of standing: the rank Lectio or the desk earned, then the plates read
    const text = [recordLine(storedRecord()), chaptersLine(storedChapters())].filter(Boolean).join(' ');
    const rank = rankFor(storedBest()).name;
    line.textContent = text ? `Your scriptorium: ${rank} · ${text}` : (storedBest() ? `Your scriptorium: ${rank}.` : '');
  }

  // ---------- The plate: inked along the snail, walkable sign by sign ----------
  function plateSvg() {
    return $('[data-plate] svg');
  }

  // Press each stroke in reading order (one wedge path per stroke, in that
  // order): the wet rubric front follows the path, coiling in or climbing the rows.
  // Drawing every stroke holds 60 fps up to about a thousand wedges (measured in
  // Chromium); beyond, the signs are too small to see a stroke run and the
  // browser too busy to draw them, so the plate is there at once and only its
  // ink dries along the path.
  const DRAWN_WEDGES = 1200;
  function inkPlate() {
    const svg = plateSvg();
    if (!svg || reducedMotion) return;
    const wedges = $$('path', svg);
    const step = Math.min(70, 2800 / (wedges.length || 1));
    const ink = wedges.length <= DRAWN_WEDGES ? Ink.press : Ink.wet;
    wedges.forEach((wedge, i) => ink(wedge, i * step));
  }

  function initPlateWalk() {
    const frame = $('[data-plate]');
    const svg = plateSvg();
    if (!frame || !svg || !frame.dataset.plateCells) return;
    let cells = JSON.parse(frame.dataset.plateCells);
    const layout = JSON.parse(frame.dataset.plateLayout);
    // The live reading and the resting caption share one cell (CSS): walking
    // swaps them in place, so nothing below the plate moves
    const readingEl = $('[data-plate-reading]');
    const caption = readingEl.closest('.plate-reading');
    const index = new Map(cells.map(([row, col], i) => [`${row},${col}`, i]));
    // A pathless plate's desk lays a way over the grid: the walk follows it
    const follow = (next) => {
      cells = next;
      index.clear();
      next.forEach(([row, col], i) => index.set(`${row},${col}`, i));
      show(-1);
    };
    const [cellWidth, cellHeight] = layout.cell;

    const focus = document.createElementNS(SVG_NS, 'rect');
    focus.setAttribute('class', 'plate-focus');
    focus.setAttribute('width', cellWidth);
    focus.setAttribute('height', cellHeight);
    focus.setAttribute('rx', 6);
    svg.insertBefore(focus, $('g', svg));

    // Rongorongo plates can be turned half round, as the tablets were
    const turnButton = $('[data-action="turn-plate"]');
    const isTurned = () => frame.classList.contains('is-turned');

    let current = -1;
    let revealing = true; // the desk, unaided, walks the signs without saying what they read
    const show = (i) => {
      current = i;
      if (i < 0) {
        focus.classList.remove('is-visible');
        readingEl.textContent = '';
        caption.classList.remove('is-walking');
        return;
      }
      const [row, col, value, turned] = cells[i];
      const x = layout.padding + (col * cellWidth) + layout.offset;
      const y = layout.padding + (row * cellHeight) + layout.offset;
      // Appear in place, glide only from sign to sign
      const appearing = !focus.classList.contains('is-visible');
      if (appearing) focus.style.transition = 'none';
      focus.style.transform = `translate(${x}px, ${y}px)`;
      if (appearing) {
        focus.getBoundingClientRect();
        focus.style.removeProperty('transition');
      }
      focus.classList.add('is-visible');
      const upsideDown = Boolean(turned) !== isTurned() ? ' · upside down: turn the plate' : '';
      const underGrille = layout.grille ? ` · under the grille at ${TURNS[Math.floor((4 * i) / cells.length)]}` : '';
      const read = value === null ? ' · worn: part of this sign is lost' : (revealing ? ` · ${value}` : '');
      readingEl.textContent = `Sign ${i + 1} of ${cells.length}${read}${upsideDown}${underGrille}`;
      caption.classList.add('is-walking');
    };

    if (turnButton) {
      turnButton.classList.remove('awaits-script');
      turnButton.addEventListener('click', () => {
        const turned = !isTurned();
        frame.classList.toggle('is-turned', turned);
        hand('turn');
        turnButton.setAttribute('aria-pressed', String(turned));
        if (current >= 0) show(current);
      });
    }

    // From the box and the viewBox, not getScreenCTM: Chrome gets the origin of
    // the CSS half turn wrong there. A turned plate mirrors both ways.
    const cellAt = (event) => {
      const rect = svg.getBoundingClientRect();
      const view = svg.viewBox.baseVal;
      let fx = (event.clientX - rect.left) / rect.width;
      let fy = (event.clientY - rect.top) / rect.height;
      if (isTurned()) [fx, fy] = [1 - fx, 1 - fy];
      const col = Math.floor(((view.x + (fx * view.width)) - layout.padding - layout.offset) / cellWidth);
      const row = Math.floor(((view.y + (fy * view.height)) - layout.padding - layout.offset) / cellHeight);
      const i = index.get(`${row},${col}`);
      return i === undefined ? -1 : i;
    };

    svg.addEventListener('pointermove', (event) => {
      const i = cellAt(event);
      if (i !== current) show(i);
    });
    svg.addEventListener('pointerleave', () => { if (document.activeElement !== frame) show(-1); });
    frame.addEventListener('focus', () => { if (current < 0) show(0); });
    frame.addEventListener('blur', () => show(-1));
    frame.addEventListener('keydown', (event) => {
      const moves = {
        ArrowRight: current + 1, ArrowDown: current + 1, ArrowLeft: current - 1, ArrowUp: current - 1,
        Home: 0, End: cells.length - 1
      };
      if (event.key === 'Escape') {
        show(-1);
        return;
      }
      if (!(event.key in moves)) return;
      event.preventDefault();
      show(Math.min(Math.max(moves[event.key], 0), cells.length - 1));
    });
    $('[data-plate-hint]').classList.remove('awaits-script');
    // For the desk: move the field, find a sign under a tap, say or keep the values
    frame.plateWalk = { show, cellAt, follow, reveal: (on) => { revealing = on; if (current >= 0) show(current); } };
  }

  // ---------- Zoom: a plate of many signs, looked at closely ----------
  // The frame keeps its size and becomes a window the plate grows behind: its
  // width and height grow, never a transform, so the walk, the bench and the
  // grille read the plate's box as they always do. The window scrolls, or is
  // dragged with the mouse; the point under the pointer (the window's centre,
  // from the buttons) stays where it is, and the sign the walk is on is kept
  // in view. Ctrl or ⌘ with the wheel (a trackpad's pinch) zooms, and + − 0
  // on the focused plate
  const ZOOMS = [1, 1.5, 2, 3, 4];
  function initPlateZoom() {
    const controls = $('[data-plate-zoom]');
    const frame = $('[data-plate]');
    const svg = frame && plateSvg();
    if (!controls || !svg) return;
    const [out, into] = ['-1', '1'].map((k) => $(`[data-zoom-step="${k}"]`, controls));
    const level = $('[data-zoom-level]', controls); // the level, a button that fits the whole plate again
    const said = $('[data-zoom-said]', controls);
    let zoom = 1;
    let base = null; // the plate's box and the frame's height at ×1
    const set = (next, at) => {
      if (next === zoom) return;
      if (zoom === 1) {
        const plate = svg.getBoundingClientRect();
        base = { width: plate.width, height: plate.height, frame: frame.getBoundingClientRect().height };
      }
      // The point that stays, as a fraction of the plate
      const box = frame.getBoundingClientRect();
      const before = svg.getBoundingClientRect();
      const [px, py] = at ? [at.clientX, at.clientY] : [box.left + (box.width / 2), box.top + (box.height / 2)];
      const [fx, fy] = [(px - before.left) / before.width, (py - before.top) / before.height];
      zoom = next;
      frame.classList.toggle('is-zoomed', zoom > 1);
      if (zoom === 1) {
        ['width', 'height'].forEach((name) => svg.style.removeProperty(name));
        frame.style.removeProperty('height');
      } else {
        frame.style.height = `${base.frame}px`;
        svg.style.width = `${base.width * zoom}px`;
        svg.style.height = `${base.height * zoom}px`;
        const after = svg.getBoundingClientRect();
        frame.scrollLeft += (after.left + (fx * after.width)) - px;
        frame.scrollTop += (after.top + (fy * after.height)) - py;
      }
      level.textContent = `×${zoom}`;
      level.setAttribute('aria-label', zoom === 1 ? '×1: the whole plate' : `×${zoom}: back to the whole plate`);
      said.textContent = `Zoom ×${zoom}`;
      out.disabled = zoom === 1;
      level.disabled = zoom === 1;
      into.disabled = zoom === ZOOMS.at(-1);
    };
    const step = (by, at) => set(ZOOMS[Math.min(Math.max(ZOOMS.indexOf(zoom) + by, 0), ZOOMS.length - 1)], at);

    // The sign the walk is on, kept in the window: from the focus's place in the plate's own units
    const keepInView = () => {
      const focus = $('.plate-focus', svg);
      const at = focus?.style.transform.match(/translate\((-?[\d.]+)px, (-?[\d.]+)px\)/);
      if (zoom === 1 || !at || !focus.classList.contains('is-visible')) return;
      const view = svg.viewBox.baseVal;
      const plate = svg.getBoundingClientRect();
      const turned = frame.classList.contains('is-turned');
      const edge = (offset, size, origin, span, length) => {
        const from = (offset - origin) / span;
        const to = (offset + size - origin) / span;
        return turned ? [1 - to, 1 - from].map((f) => f * length) : [from * length, to * length];
      };
      const [left, right] = edge(Number(at[1]), Number(focus.getAttribute('width')), view.x, view.width, plate.width);
      const [top, bottom] = edge(Number(at[2]), Number(focus.getAttribute('height')), view.y, view.height, plate.height);
      const box = frame.getBoundingClientRect();
      const margin = 24;
      const [x0, x1, y0, y1] = [plate.left + left, plate.left + right, plate.top + top, plate.top + bottom];
      if (x0 < box.left + margin) frame.scrollLeft -= (box.left + margin) - x0;
      else if (x1 > box.right - margin) frame.scrollLeft += x1 - (box.right - margin);
      if (y0 < box.top + margin) frame.scrollTop -= (box.top + margin) - y0;
      else if (y1 > box.bottom - margin) frame.scrollTop += y1 - (box.bottom - margin);
    };
    if (frame.plateWalk) { // the desk and the bench move the walk too
      const { show } = frame.plateWalk;
      frame.plateWalk.show = (i) => { show(i); keepInView(); };
    }

    into.addEventListener('click', () => step(1));
    out.addEventListener('click', () => step(-1));
    level.addEventListener('click', () => set(1));
    frame.addEventListener('keydown', (event) => {
      if (event.ctrlKey || event.metaKey || event.altKey) return;
      if (event.key === '+' || event.key === '=') step(1);
      else if (event.key === '-' || event.key === '_') step(-1);
      else if (event.key === '0') set(1);
      else if (['ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp', 'Home', 'End'].includes(event.key)) requestAnimationFrame(keepInView);
      else return;
      event.preventDefault();
    });
    // Ctrl or ⌘ and the wheel, or a pinch on a trackpad (the same events): a step per notch
    let wheel = 0;
    frame.addEventListener('wheel', (event) => {
      if (!event.ctrlKey && !event.metaKey) return;
      event.preventDefault();
      wheel += event.deltaY * ([1, 40, 800][event.deltaMode] || 1); // pixels, lines (Firefox) or pages
      if (Math.abs(wheel) < 40) return;
      step(wheel < 0 ? 1 : -1, event);
      wheel = 0;
    }, { passive: false });
    // Dragged with the mouse when zoomed (a finger scrolls the window as it is);
    // a drag is not a click on a sign
    let drag = null;
    frame.addEventListener('pointerdown', (event) => {
      if (zoom === 1 || event.pointerType !== 'mouse' || event.button !== 0) return;
      drag = { x: event.clientX, y: event.clientY, left: frame.scrollLeft, top: frame.scrollTop, moved: false };
    });
    window.addEventListener('pointermove', (event) => {
      if (!drag) return;
      const [dx, dy] = [event.clientX - drag.x, event.clientY - drag.y];
      if (!drag.moved && Math.hypot(dx, dy) < 4) return;
      drag.moved = true;
      frame.classList.add('is-panning');
      frame.scrollLeft = drag.left - dx;
      frame.scrollTop = drag.top - dy;
    });
    window.addEventListener('pointerup', () => {
      if (drag?.moved) {
        const swallow = (event) => { event.stopPropagation(); event.preventDefault(); };
        frame.addEventListener('click', swallow, { capture: true });
        setTimeout(() => frame.removeEventListener('click', swallow, { capture: true }), 0);
      }
      drag = null;
      frame.classList.remove('is-panning');
    });
    // A new width for the page: back to the whole plate, measured again when zoomed next
    // (a phone's toolbar sliding away changes only the height: the zoom stays)
    let width = window.innerWidth;
    window.addEventListener('resize', () => {
      if (window.innerWidth === width) return;
      width = window.innerWidth;
      set(1);
    });
    controls.classList.remove('awaits-script');
  }

  // ---------- The reading desk: an intact plate, read pair by pair ----------
  // The current pair is shown large; the reader types the two numbers; the
  // page adds them and finds the letter on the tablet; the text grows below.
  // Guided, a tap on a sign (on the plate or on the desk) shows its value.
  // Unaided, a wrong value is marked and never corrected, the walk keeps the
  // values to itself, and three right pairs in a row earn the Lectio's ranks
  // (the same best, kept in the browser).
  const DESK_MODE_KEY = 'cistergraphia.desk.mode';
  // A pathless plate (docs/design.md, "Find the path"): the desk asks which
  // way the plate runs, lays the way chosen over the grid (Ways), and reads
  // along it: the pairs balance to letters, or break ("not on the tablet",
  // or a sign that reads as nothing turned). The notebook keeps what each
  // way gave and where it broke; the plate is read when a way runs to the end.
  // The expert plate (pathless, with a tablet of its own): the way is found on
  // sums alone, a sum that is a value of no tablet breaks it, and three pairs
  // that land (fewer on a plate with fewer) open the notebook on that way,
  // once the page has checked every pair along it; the ways are then shut
  const WAY_NAMES = { phaistos: 'the snail', rongorongo: 'the turning tablet', leap: 'the leap', furrows: 'the furrows', unwinding: 'the unwinding' };
  const capital = (words) => words.charAt(0).toUpperCase() + words.slice(1);
  function initDesk() {
    const desk = $('[data-desk]');
    const frame = $('[data-plate]');
    if (!desk || !frame || !frame.dataset.plateCells || !Ink.glyphTable()) return;
    const cells = JSON.parse(frame.dataset.plateCells);
    const pathless = 'deskPathless' in desk.dataset;
    const own = 'deskOwn' in desk.dataset; // a tablet of its own: the notebook names the sums (initNotebook)
    const expert = pathless && own; // the way first, on sums alone; then the notebook, on it
    const onTablet = own ? new Set(JSON.parse(desk.dataset.values)) : null; // the values every tablet deals out
    const grid = pathless ? JSON.parse(frame.dataset.plateGrid) : null;
    let values = cells.map(([, , value]) => value);
    const tablet = JSON.parse(desk.dataset.tablet);
    const nullMark = Number(desk.dataset.null);
    let pairs = values.length / 2;
    const form = $('[data-desk-form]', desk);
    const inputs = [0, 1].map((k) => $(`[data-desk-value="${k}"]`, desk));
    const signs = [0, 1].map((k) => $(`[data-desk-sign="${k}"]`, desk));
    const [which, letterEl, feedback, notebookEl] = ['which', 'letter', 'feedback', 'notebook'].map((n) => $(`[data-desk-${n}]`, desk));
    const textEl = $('[data-desk-text]'); // the desk's, or the notebook's on a plate with a tablet of its own
    let read = new Array(pairs).fill(null); // the letter of each pair once read ('' for a null pair, '?' for a break)
    let way = null; // a pathless plate: the way laid, once chosen
    const tried = new Map(); // way => { read, broke }: the notebook
    let pair = 0;
    let mode = 'guided';
    let streak = 0;
    let best = storedBest();
    try { mode = localStorage.getItem(DESK_MODE_KEY) === 'unaided' ? 'unaided' : 'guided'; } catch (error) { /* keep guided */ }

    const letterOf = (p) => {
      const [a, b] = [values[2 * p], values[(2 * p) + 1]];
      if (a === null || b === null) return '?'; // a sign that reads as nothing the way it is laid
      if (b === nullMark) return '';
      if (expert) return onTablet.has(a + b) ? 'read' : '?'; // a value of the tablet, its letter unknown
      return tablet[a + b] ?? '?';
    };
    const waiting = () => pathless && !way;
    // A pair that lands is + (its letter the notebook's), a pair that breaks ×,
    // and before the expert's notebook opens a null pair is ø: Latin marks
    // every monospace face has, one per pair, so the line keeps its width ('?'
    // would let it wrap after the mark, a line early)
    const mark = (letter) => (letter === 'read' ? '+' : (letter === '' && expert && !notes ? 'ø' : letter));
    const text = () => read.map((letter) => (letter === null ? '·' : (letter === '?' ? '×' : mark(letter)))).join('');
    let notes = own && !expert ? initNotebook(cells.map(([, , value]) => value), textEl, nullMark) : null;
    const writeText = () => { if (notes) notes.render(); else textEl.textContent = text(); };
    const sumOf = (p) => values[2 * p] + values[(2 * p) + 1];
    const said = (letter) => (letter === ' ' ? 'space' : letter);
    const standing = () => {
      $('[data-desk-rank]', desk).textContent = rankFor(streak).name;
      $('[data-desk-streak]', desk).textContent = streak;
      $('[data-desk-best]', desk).textContent = best;
    };
    const setMode = (next) => {
      mode = next;
      desk.dataset.deskMode = mode;
      $$('[data-desk-set-mode]', desk).forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.deskSetMode === mode)));
      frame.plateWalk?.reveal(mode === 'guided');
      notes?.guided(mode === 'guided');
      try { localStorage.setItem(DESK_MODE_KEY, mode); } catch (error) { /* private mode */ }
    };
    // The desk moves on by itself a moment after a pair is read; any other
    // move (a way chosen, a step, a sign tapped) cancels it, or the move
    // meant for one way would land on the next, a pair skipped
    let moving = null;
    const moveOn = (p) => {
      clearTimeout(moving);
      moving = setTimeout(() => { show(p); inputs[0].focus(); }, reducedMotion ? 300 : 900);
    };
    const show = (p) => {
      clearTimeout(moving);
      if (waiting()) return;
      pair = Math.min(Math.max(p, 0), pairs - 1);
      which.textContent = `Pair ${pair + 1} of ${pairs} · signs ${(2 * pair) + 1} and ${(2 * pair) + 2}`;
      [0, 1].forEach((k) => {
        const value = values[(2 * pair) + k];
        if (value === null) signs[k].replaceChildren('∅'); // turned half round, it reads as nothing
        else signs[k].replaceChildren(Ink.glyph(value, { label: `The ${k ? 'second' : 'first'} sign of the pair`, inked: true }));
        inputs[k].value = '';
        inputs[k].removeAttribute('aria-invalid');
      });
      if (notes) letterEl.textContent = values[(2 * pair) + 1] === nullMark ? '∅' : (notes.letter(sumOf(pair)) ?? '?');
      else letterEl.textContent = read[pair] === null || read[pair] === 'read' ? '?' : (read[pair] === '' ? '∅' : read[pair]);
      frame.plateWalk?.show(2 * pair);
    };
    const nextUnread = () => {
      for (let k = 1; k <= pairs; k += 1) if (read[(pair + k) % pairs] === null) return (pair + k) % pairs;
      return -1;
    };
    // The notebook of a pathless plate: what each way gave, and where it broke
    const notebook = () => {
      if (!notebookEl) return;
      const lines = Array.from(tried, ([name, t]) => {
        const given = t.read.map((l) => (l === null || l === '?' ? '·' : mark(l))).join('').replace(/·+$/, '');
        const end = t.broke ? ` ✗ at pair ${t.broke}` : (t.found || t.read.every((l) => l !== null && l !== '?') ? ' ✓' : '');
        return `${WAY_NAMES[name]}${given ? `: ${given}` : ''}${end}`;
      });
      notebookEl.textContent = lines.length ? `Tried: ${lines.join(' · ')}` : (expert ? 'The ways tried, and where each broke.' : 'The notebook: what each way gave, and where it broke.');
    };
    // The expert plate: whether every pair along the way laid lands (a value
    // of the tablet, or a null pair), and how many must be read to open the notebook
    const holds = () => values.every((v) => v !== null) &&
      Array.from({ length: pairs }, (_, p) => p).every((p) => values[(2 * p) + 1] === nullMark || onTablet.has(sumOf(p)));
    const toOpen = () => Math.min(3, Array.from({ length: pairs }, (_, p) => p).filter((p) => values[(2 * p) + 1] !== nullMark).length);
    // The way found: the ways shut, and the notebook opens on every sum along it
    const openNotebook = (kept) => {
      $$('[data-desk-way]', desk).forEach((b) => { b.disabled = b.dataset.deskWay !== way; });
      textEl.style.minHeight = `${textEl.offsetHeight}px`; // the line keeps its room: the null pairs leave it
      textEl.classList.add('desk-text--notebook');
      notes = initNotebook(values, textEl, nullMark, way);
      read.forEach((letter, p) => { if (letter === 'read') notes.seen(sumOf(p)); });
      notes.guided(mode === 'guided');
      tried.get(way).found = true;
      const count = $$('[data-entry]').length;
      feedback.textContent = kept ? `Along ${WAY_NAMES[way]}, as you left it: the notebook is open on its ${count} sums.`
        : `Along ${WAY_NAMES[way]} the pairs land on the tablet: this is the way. The notebook opens on its ${count} sums.`;
      notebook();
    };
    // Lay a way over the grid: the signs along it (turned where it says so),
    // the walk following, the reading kept per way
    const lay = (name, focus = true) => {
      const byCell = new Map(grid.map(([row, col, upright, turned]) => [`${row},${col}`, { upright, turned }]));
      const laid = Ways.path(Math.sqrt(grid.length), name).map(([row, col, turned]) => {
        const cell = byCell.get(`${row},${col}`);
        return [row, col, turned ? cell.turned : cell.upright, turned];
      });
      way = name;
      values = laid.map(([, , value]) => value);
      pairs = values.length / 2;
      if (!tried.has(name)) tried.set(name, { read: new Array(pairs).fill(null), broke: null });
      read = tried.get(name).read;
      $$('[data-desk-way]', desk).forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.deskWay === name)));
      frame.plateWalk?.follow(laid);
      feedback.textContent = `Along ${WAY_NAMES[name]}: the pairs form. Read them.`;
      writeText();
      notebook();
      pair = 0;
      const next = read[0] === null ? 0 : nextUnread();
      show(next < 0 ? 0 : next);
      if (focus) inputs[0].focus();
    };
    const reveal = (sign) => { // guided: a tapped sign shows its value in its box
      if (mode !== 'guided' || waiting()) return;
      const p = Math.floor(sign / 2);
      if (p !== pair) show(p);
      inputs[sign % 2].value = values[sign];
      inputs[sign % 2].removeAttribute('aria-invalid');
      inputs[sign % 2].focus();
    };

    form.addEventListener('submit', (event) => {
      event.preventDefault();
      if (waiting()) {
        feedback.textContent = 'Choose a way first: the plate says nothing of where it begins.';
        return;
      }
      if (values[2 * pair] === null || values[(2 * pair) + 1] === null) { // a sign that reads as nothing turned
        read[pair] = '?';
        tried.get(way).broke ??= pair + 1;
        feedback.textContent = `Turned half round, a sign reads as no number: ${WAY_NAMES[way]} is not the way.`;
        letterEl.textContent = '✗';
        writeText();
        notebook();
        return;
      }
      const typed = inputs.map((input) => (input.value.trim() === '' ? null : Math.trunc(Number(input.value))));
      if (typed.some((v) => v === null)) {
        feedback.textContent = 'Type what each sign reads.';
        inputs[typed.indexOf(null)].focus();
        return;
      }
      const wrong = [0, 1].filter((k) => typed[k] !== values[(2 * pair) + k]);
      if (wrong.length) {
        wrong.forEach((k) => inputs[k].setAttribute('aria-invalid', 'true'));
        const which = wrong.length === 2 ? 'Neither sign reads' : `The ${wrong[0] ? 'second' : 'first'} sign does not read`;
        feedback.textContent = `${which} that. Look again${mode === 'guided' ? ', or tap a sign to see it' : ''}.`;
        if (mode === 'unaided') { streak = 0; standing(); }
        inputs[wrong[0]].focus();
        return;
      }
      const letter = notes ? (values[(2 * pair) + 1] === nullMark ? '' : 'read') : letterOf(pair);
      read[pair] = letter;
      const [a, b] = [values[2 * pair], values[(2 * pair) + 1]];
      if (notes && letter === 'read') { // a tablet of its own: the sum goes into the notebook, its letter is the notebook's
        notes.seen(a + b);
        const known = notes.letter(a + b);
        feedback.textContent = `${a} + ${b} = ${a + b}. ${known ? `In the notebook: “${said(known)}”.` : 'Not yet in the notebook.'}`;
        letterEl.textContent = known ?? '?';
      }
      if (letter === '?') { // along a way laid over a pathless plate: the pair does not balance
        tried.get(way).broke ??= pair + 1;
        const off = expert ? 'a value of no tablet' : 'not on the tablet';
        feedback.textContent = `${a} + ${b} = ${a + b}: ${off}. ${capital(WAY_NAMES[way])} breaks at pair ${pair + 1}.`;
        letterEl.textContent = '✗';
        writeText();
        notebook();
        const next = nextUnread();
        if (next >= 0) moveOn(next);
        return;
      }
      if (letter === '') feedback.textContent = `${a} + ${b}: the second sign is ${nullMark}, a null pair. Nothing to read.`;
      else if (letter === 'read' && !notes) feedback.textContent = `${a} + ${b} = ${a + b}: a value of the tablet, its letter to find.`;
      else if (!notes) feedback.textContent = `${a} + ${b} = ${a + b}: ${letter === ' ' ? 'a space' : `“${letter}”`}.`;
      if (letter === '') letterEl.textContent = '∅';
      else if (letter === 'read' && !notes) letterEl.textContent = '?';
      else if (!notes) letterEl.textContent = letter;
      hand('bite'); // the letter written down
      writeText();
      notebook();
      if (mode === 'unaided') {
        const before = rankFor(streak).name;
        streak += 1;
        best = Math.max(best, streak);
        storeBest(best);
        const after = rankFor(streak).name;
        if (after !== before) feedback.textContent += ` ${streak} in a row: you are now ${after === 'Abbot' ? 'an' : 'a'} ${after.toLowerCase()}.`;
        standing();
      }
      if (expert && !notes && !tried.get(way).broke && read.filter((l) => l === 'read').length >= toOpen() && holds()) {
        openNotebook(false);
        const after = nextUnread();
        if (after >= 0) moveOn(after);
        return;
      }
      const next = nextUnread();
      if (next < 0 && notes) {
        feedback.textContent = 'Every pair read: their sums are in the notebook. Now its tablet.';
        return;
      }
      if (next < 0) {
        const breaks = read.filter((l) => l === '?').length;
        if (breaks) {
          feedback.textContent = `Read to the end along ${WAY_NAMES[way]}: ${breaks} ${breaks === 1 ? 'pair' : 'pairs'} not on the tablet. Not the way.`;
          return;
        }
        feedback.textContent = way ? `Read to the end, along ${WAY_NAMES[way]}: “${text().trim()}”.` : `Read to the end: “${text().trim()}”.`;
        recordWin();
        return;
      }
      moveOn(next);
    });
    $$('[data-desk-way]', desk).forEach((button) => button.addEventListener('click', () => lay(button.dataset.deskWay)));

    $$('[data-desk-step]', desk).forEach((button) => button.addEventListener('click', () => {
      show((pair + Number(button.dataset.deskStep) + pairs) % pairs);
    }));
    $$('[data-desk-set-mode]', desk).forEach((button) => button.addEventListener('click', () => setMode(button.dataset.deskSetMode)));
    signs.forEach((holder, k) => holder.addEventListener('click', () => reveal((2 * pair) + k)));
    const svg = plateSvg();
    svg.addEventListener('click', (event) => {
      const i = frame.plateWalk?.cellAt(event) ?? -1;
      if (i < 0) return;
      if (mode === 'guided') reveal(i);
      else show(Math.floor(i / 2));
    });

    // The first pair is the one the server drew: take it over, don't redraw it
    // (a pathless plate's desk waits empty for a way)
    if (!pathless) [0, 1].forEach((k) => Ink.adopt($('svg', signs[k]), values[k]));
    setMode(mode);
    standing();
    if (expert) { // the notebook shut until the way is found, or open on the way found before, in this browser
      $('[data-notebook]').classList.remove('awaits-script');
      const kept = keptNotebook();
      if (kept && WAY_NAMES[kept.way]) {
        lay(kept.way, false); // on arrival: nothing scrolls
        if (holds()) openNotebook(true);
      }
    }
    desk.classList.remove('awaits-script');
  }

  // ---------- The notebook: a plate with a tablet of its own ----------
  // One entry per sum the pairs make (the server drew them, the most seen
  // first). A letter written against a sum is in pencil: the text line takes
  // it at once, in grey italics; a letter is used by one sum at a time, so
  // writing it elsewhere moves it. Ask the scribe sends the pencilled entries
  // (POST /ask); those that hold come back, only when three or more do (or
  // the last ones, together), and go into ink, upright, for good. Guided, every
  // sum is in the notebook from the start; unaided, a sum enters it once its
  // pair is read right at the desk. Kept in this browser, by the plate's seed.
  // The expert plate's notebook is shut until the desk finds the way: then it
  // is built here, from the way's values, as the server draws the others.
  const NOTEBOOK_KEY = 'cistergraphia.notebook.';
  const SPELLINGS = 3; // spellings shown per entry (Cistergraphia::Notebook::SPELLINGS)
  const plateSeed = () => ($('.readback input[name="svg"]')?.value.match(/data-tablet="([^"]+)"/) || [])[1];
  // What this browser kept of the plate's notebook, or null
  function keptNotebook() {
    const seed = plateSeed();
    if (!seed) return null;
    try { return JSON.parse(localStorage.getItem(NOTEBOOK_KEY + seed) || 'null'); } catch (error) { return null; }
  }
  // One entry per sum of the pairs (null pairs aside), the most seen first,
  // then by sum: Cistergraphia::Notebook.entries
  function notebookEntries(values, nullMark) {
    const bySum = new Map();
    for (let k = 0; k < values.length; k += 2) {
      const [a, b] = [values[k], values[k + 1]];
      if (b === nullMark) continue;
      const entry = bySum.get(a + b) ?? { sum: a + b, seen: 0, spellings: [] };
      entry.seen += 1;
      if (!entry.spellings.some(([x, y]) => x === a && y === b)) entry.spellings.push([a, b]);
      bySum.set(a + b, entry);
    }
    return [...bySum.values()].sort((x, y) => (y.seen - x.seen) || (x.sum - y.sum));
  }
  // A row of the notebook from its template (_notebook_row.erb), for one entry
  function notebookRow(template, { sum, seen, spellings }) {
    const pad = (n) => String(n).padStart(4, '0');
    const span = (css, text) => Object.assign(document.createElement('span'), { className: css, textContent: text });
    const row = template.content.firstElementChild.cloneNode(true);
    row.dataset.entryRow = sum;
    $('.notebook-sum', row).textContent = pad(sum);
    $('.notebook-seen', row).textContent = seen;
    const spelled = spellings.slice(0, SPELLINGS).map(([a, b]) => span('spelling', `${pad(a)} + ${pad(b)}`));
    if (spellings.length > 1) spelled.push(span(`spelling-more${spellings.length > SPELLINGS ? ' spelling-more--wide' : ''}`, '…'));
    $('.notebook-spellings', row).replaceChildren(...spelled);
    Object.assign($('label', row), { htmlFor: `entry-${sum}`, textContent: `What ${sum} reads as` });
    const select = $('select', row);
    select.id = `entry-${sum}`;
    select.dataset.entry = sum;
    return row;
  }
  // The shut notebook opened on a way's values: its rows, its note, its scribe
  function openShutNotebook(book, values, nullMark) {
    const entries = notebookEntries(values, nullMark);
    const template = $('[data-notebook-row]', book);
    $('[data-notebook-rows]', book).replaceChildren(...entries.map((entry) => notebookRow(template, entry)));
    book.dataset.notebookSums = JSON.stringify(entries.map((entry) => entry.sum));
    $('[data-notebook-note]', book).textContent = book.dataset.notebookOpenNote;
    $('[data-notebook-ask]', book).disabled = false;
    book.classList.remove('is-shut');
    delete book.dataset.notebookShut;
  }
  function initNotebook(values, textEl, nullMark, way = null) {
    const book = $('[data-notebook]');
    if ('notebookShut' in book.dataset) openShutNotebook(book, values, nullMark);
    const sums = JSON.parse(book.dataset.notebookSums);
    const selects = new Map($$('[data-entry]', book).map((el) => [Number(el.dataset.entry), el]));
    const rows = new Map($$('[data-entry-row]', book).map((el) => [Number(el.dataset.entryRow), el]));
    const [countEl, verdict, ask] = ['[data-notebook-count]', '[data-notebook-verdict]', '[data-notebook-ask]'].map((q) => $(q, book));
    const svgField = $('.readback input[name="svg"]');
    const seed = plateSeed();
    const pairs = [];
    for (let k = 0; k < values.length; k += 2) if (values[k + 1] !== nullMark) pairs.push(values[k] + values[k + 1]);
    const pencil = new Map();
    const ink = new Map();
    const seen = new Set();
    let asked = 0;
    let guided = true;
    let busy = false;

    const save = () => {
      if (!seed) return;
      try { localStorage.setItem(NOTEBOOK_KEY + seed, JSON.stringify({ pencil: [...pencil], ink: [...ink], seen: [...seen], asked, way })); } catch (error) { /* private mode */ }
    };
    const restore = () => {
      try {
        const kept = keptNotebook();
        if (!kept) return;
        kept.ink.forEach(([sum, char]) => { if (selects.has(sum)) ink.set(sum, char); });
        kept.pencil.forEach(([sum, char]) => { if (selects.has(sum) && !ink.has(sum)) pencil.set(sum, char); });
        kept.seen.forEach((sum) => seen.add(sum));
        asked = Number(kept.asked) || 0;
      } catch (error) { /* nothing kept */ }
    };
    const letter = (sum) => ink.get(sum) ?? pencil.get(sum);
    const inkedLetters = () => new Set(ink.values());

    // The text line: every pair that reads, its letter in ink, in pencil, or a dot
    const render = () => {
      textEl.replaceChildren(...pairs.map((sum) => {
        const span = document.createElement('span');
        if (ink.has(sum)) { span.className = 'is-ink'; span.textContent = ink.get(sum); } else if (pencil.has(sum)) { span.className = 'is-pencil'; span.textContent = pencil.get(sum); } else span.textContent = '·';
        return span;
      }));
      const used = inkedLetters();
      selects.forEach((select, sum) => {
        const inked = ink.has(sum);
        select.value = letter(sum) ?? '';
        select.disabled = inked;
        select.classList.toggle('is-ink', inked);
        select.classList.toggle('is-pencil', !inked && pencil.has(sum));
        $$('option', select).forEach((option) => { option.disabled = option.value !== '' && used.has(option.value) && ink.get(sum) !== option.value; });
        rows.get(sum).classList.toggle('is-unseen', !guided && !inked && !seen.has(sum));
      });
      countEl.textContent = `${ink.size} of ${sums.length} in ink · asked ${asked} ${asked === 1 ? 'time' : 'times'}`;
    };

    selects.forEach((select, sum) => select.addEventListener('change', () => {
      const char = select.value;
      if (char === '') pencil.delete(sum);
      else {
        pencil.forEach((other, key) => { if (other === char && key !== sum) pencil.delete(key); }); // a letter is one sum's
        pencil.set(sum, char);
      }
      hand(char === '' ? 'lift' : 'bite');
      render();
      save();
    }));

    ask.addEventListener('click', async () => {
      if (busy) return;
      const open = sums.filter((sum) => !ink.has(sum));
      const written = open.filter((sum) => pencil.has(sum));
      if (!open.length) return;
      if (written.length < Math.min(3, open.length)) {
        verdict.textContent = open.length < 3 ? 'Pencil every sum left: the scribe confirms the last ones together.' : 'Pencil three entries at least: the scribe confirms three at a time.';
        return;
      }
      busy = true;
      verdict.textContent = 'The scribe reads the notebook…';
      try {
        const body = new URLSearchParams({ svg: svgField.value, pencil: JSON.stringify(Object.fromEntries(written.map((sum) => [sum, pencil.get(sum)]))), inked: JSON.stringify([...ink.keys()]) });
        const response = await fetch('/ask', { method: 'POST', body, headers: { Accept: 'application/json' } });
        if (!response.ok) throw new Error(String(response.status));
        const { held } = await response.json();
        asked += 1;
        const confirmed = Object.entries(held).map(([sum, char]) => [Number(sum), char]);
        confirmed.forEach(([sum, char]) => { ink.set(sum, char); pencil.delete(sum); });
        if (ink.size === sums.length) {
          verdict.textContent = 'Every sum is in ink: the tablet is yours.';
          recordWin(); // the bell
        } else if (confirmed.length) {
          verdict.textContent = `${confirmed.length} ${confirmed.length === 1 ? 'entry holds' : 'entries hold'}: now in ink.`;
        } else verdict.textContent = 'Nothing holds yet.';
        render();
        save();
      } catch (error) {
        verdict.textContent = 'The scribe could not read the notebook: ask again.';
      } finally {
        busy = false;
      }
    });

    restore();
    render();
    book.classList.remove('awaits-script');
    return {
      render,
      letter,
      seen: (sum) => { if (!seen.has(sum)) { seen.add(sum); render(); save(); } },
      guided: (on) => { guided = on; render(); }
    };
  }

  // ---------- The grille: a parchment laid on the plate, turned N, E, S, W ----------
  // The stencil is the server's (the file Download the stencil saves). It shares
  // the plate's viewBox, so given the plate's box it lies exactly over it. Each
  // quarter turn lights the signs under its holes: the next quarter of the
  // reading order, row by row. A wedge's cell is read from its bite (where
  // Cistergraphia::Stylus starts it: between the first and third points).
  function initGrille() {
    const frame = $('[data-plate]');
    const svg = plateSvg();
    const templates = $$('template[data-stencil]');
    const button = $('[data-action="lay-grille"]');
    if (!frame || !svg || !templates.length || !button || !frame.dataset.plateCells) return;
    const layout = JSON.parse(frame.dataset.plateLayout);
    const readingEl = $('[data-plate-reading]');
    const caption = readingEl.closest('.plate-reading');

    // Each grille: its stencil over the plate, its reading path and its name.
    // A plate with two readers has two (the abbot's and the novice's), one laid at a time
    const grilles = templates.map((template) => {
      const sheet = template.content.querySelector('svg').cloneNode(true);
      sheet.setAttribute('class', 'grille-sheet');
      sheet.setAttribute('aria-hidden', 'true');
      frame.appendChild(sheet);
      return { part: template.dataset.stencil, label: template.dataset.label, sheet, path: JSON.parse(template.dataset.path) };
    });
    const place = () => grilles.forEach(({ sheet }) => Object.assign(sheet.style, {
      left: `${svg.offsetLeft}px`, top: `${svg.offsetTop}px`, width: `${svg.offsetWidth}px`, height: `${svg.offsetHeight}px`
    }));
    place();
    if (window.ResizeObserver) new ResizeObserver(place).observe(svg);

    const [cellWidth, cellHeight] = layout.cell;
    const wedges = new Map();
    $$('path', svg).forEach((wedge) => {
      const n = (wedge.getAttribute('d').match(/-?\d+(?:\.\d+)?/g) || []).map(Number);
      if (n.length < 6) return;
      const key = [Math.floor((((n[1] + n[5]) / 2) - layout.padding) / cellHeight),
        Math.floor((((n[0] + n[4]) / 2) - layout.padding) / cellWidth)].join(',');
      if (!wedges.has(key)) wedges.set(key, []);
      wedges.get(key).push(wedge);
    });

    let active = grilles[0];
    let turn = -1;
    const show = () => {
      const quarter = active.path.length / 4;
      $$('path.is-lit', svg).forEach((wedge) => wedge.classList.remove('is-lit'));
      if (turn >= 0) {
        active.path.slice(turn * quarter, (turn + 1) * quarter).forEach(([row, col]) => {
          (wedges.get(`${row},${col}`) || []).forEach((wedge) => {
            Ink.dry(wedge); // red means one thing at a time
            wedge.classList.add('is-lit');
          });
        });
      }
      grilles.forEach(({ sheet }) => sheet.classList.toggle('is-laid', turn >= 0 && sheet === active.sheet));
      button.setAttribute('aria-pressed', String(turn >= 0));
      button.textContent = turn < 0 ? 'Lay the grille' : turn === 3 ? 'Lift the grille' : `Turn it to ${TURNS[turn + 1]}`;
      const name = active.label.charAt(0).toUpperCase() + active.label.slice(1);
      readingEl.textContent = turn < 0 ? ''
        : `${name} at ${TURNS[turn]}: signs ${(turn * quarter) + 1} to ${(turn + 1) * quarter} of ${active.path.length}, row by row`;
      caption.classList.toggle('is-walking', turn >= 0);
    };

    // Laid again, or another grille laid: from N, without turning back through W, S, E
    const reset = (sheet) => {
      sheet.style.transition = 'none';
      sheet.style.setProperty('--turn', 0);
      sheet.getBoundingClientRect();
      sheet.style.removeProperty('transition');
    };

    $$('.grille-actions .awaits-script').forEach((el) => el.classList.remove('awaits-script'));
    button.addEventListener('click', () => {
      turn = turn === 3 ? -1 : turn + 1;
      hand('parchment', { kind: turn === 0 ? 'lay' : turn < 0 ? 'lift' : 'turn' });
      if (turn === 0) reset(active.sheet);
      else if (turn > 0) active.sheet.style.setProperty('--turn', turn);
      show();
    });
    $$('[data-grille-choice]').forEach((choice) => choice.addEventListener('click', () => {
      $$('[data-grille-choice]').forEach((other) => other.setAttribute('aria-pressed', String(other === choice)));
      active = grilles.find((grille) => grille.part === choice.dataset.grilleChoice) || grilles[0];
      turn = -1;
      grilles.forEach(({ sheet }) => reset(sheet));
      show();
    }));
  }

  // The exported file is the plain SVG the decoder reads: the server's own,
  // as Ask the decoder sends it, never the shown plate (ink, highlight and walk
  // are added to it for display). Its classes are part of the file: a
  // weathered plate's lacunae, read without theirs, would be taken for strokes
  function plainSvgSource() {
    return $('.readback input[name="svg"]')?.value ?? null;
  }

  function download(blob, filename) {
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  function downloadPng(source) {
    const svg = plateSvg();
    const width = Number(svg.getAttribute('width'));
    const height = Number(svg.getAttribute('height'));
    const url = URL.createObjectURL(new Blob([source], { type: 'image/svg+xml' }));
    const image = new Image();
    image.onload = () => {
      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      const context = canvas.getContext('2d');
      context.fillStyle = '#ffffff';
      context.fillRect(0, 0, width, height);
      context.drawImage(image, 0, 0, width, height);
      URL.revokeObjectURL(url);
      canvas.toBlob((blob) => {
        if (blob) download(blob, 'cistergraphia.png');
        else toast('Could not create the PNG');
      }, 'image/png');
    };
    image.onerror = () => {
      URL.revokeObjectURL(url);
      toast('Could not create the PNG');
    };
    image.src = url;
  }

  async function copy(text, done) {
    try {
      await navigator.clipboard.writeText(text);
      toast(done);
    } catch (error) {
      toast('Copy is not available here');
    }
  }

  function initActions() {
    document.addEventListener('click', (event) => {
      const button = event.target.closest('[data-action]');
      if (!button) return;
      const action = button.dataset.action;
      if (action === 'copy-text') {
        const transcription = $('[data-transcription]');
        copy(transcription?.dataset.text ?? transcription?.textContent ?? '', 'Message copied');
        return;
      }
      if (action === 'copy-key') {
        copy(button.dataset.key, 'Grille key copied');
        return;
      }
      if (action === 'download-stencil') {
        $$('template[data-stencil]').forEach((stencil) => {
          const part = stencil.dataset.stencil === 'whole' ? '' : `-${stencil.dataset.stencil}`;
          download(new Blob([stencil.innerHTML.trim()], { type: 'image/svg+xml' }), `cistergraphia-grille${part}.svg`);
        });
        return;
      }
      const source = plainSvgSource();
      if (!source) return;
      if (action === 'download-svg') download(new Blob([source], { type: 'image/svg+xml' }), 'cistergraphia.svg');
      if (action === 'download-png') downloadPng(source);
      if (action === 'copy-svg') copy(source, 'SVG code copied');
    });
  }

  // ---------- A broken plate: its fragments rejoined on the board ----------
  // The fragments are the file's own groups, moved by their transform. Each
  // lies in its own frame, whose box starts where the board does: moved by
  // whole cells, it lands on the board's cells. The page knows what each
  // fragment shows (every sign read upright and turned), never where it goes:
  // once the fragments cover the board, it reads them along both paths and
  // counts the pairs that balance.
  // On a wide screen the tray is laid again beside the board, so the whole
  // puzzle is in view at once; the frame's box is fixed by CSS, so nothing on
  // the page moves when it is. A ghost of the picked fragment shows where it
  // would land.
  const WIDE = '(min-width: 64rem)';
  function initFragments() {
    const frame = $('[data-plate]');
    const panel = $('[data-rejoin]');
    const svg = plateSvg();
    if (!frame || !panel || !svg || !frame.dataset.fragments) return;
    const data = JSON.parse(frame.dataset.fragments);
    const [cellWidth, cellHeight] = data.cell;
    const [status, readingEl, turnButton, resetButton] = ['status', 'reading', 'turn', 'reset']
      .map((name) => $(`[data-rejoin-${name}]`, panel));
    const pieces = $$('g.fragment', svg).map((group, i) => {
      const [, x, y, tilt] = group.getAttribute('transform')
        .match(/translate\(([-\d.]+) ([-\d.]+)\)\s*rotate\(([-\d.]+)/).map(Number);
      const { rows, cols, signs } = data.fragments[i];
      const home = { x, y, tilt, row: null, col: null, turned: false };
      return { group, rows, cols, signs, home, ...home, width: cols * cellWidth, height: rows * cellHeight };
    });
    const total = pieces.length;
    let picked = null;
    const boardWidth = data.size * cellWidth;
    const boardHeight = data.size * cellHeight;
    const fileView = svg.getAttribute('viewBox');
    const fileHomes = pieces.map((piece) => ({ ...piece.home }));

    const draw = (piece) => {
      const cx = data.board + (piece.width / 2);
      const cy = data.board + (piece.height / 2);
      const turn = piece.tilt + (piece.turned ? 180 : 0);
      piece.group.setAttribute('transform', `translate(${piece.x} ${piece.y}) rotate(${turn} ${cx} ${cy})`);
    };

    // To the nearest cell, straight, and never off the sheet
    const snap = (piece) => {
      const view = svg.viewBox.baseVal;
      const lastCol = Math.floor((view.width - data.board - piece.width) / cellWidth);
      const lastRow = Math.floor((view.height - data.board - piece.height) / cellHeight);
      piece.col = Math.min(Math.max(Math.round(piece.x / cellWidth), 0), lastCol);
      piece.row = Math.min(Math.max(Math.round(piece.y / cellHeight), 0), lastRow);
      piece.x = piece.col * cellWidth;
      piece.y = piece.row * cellHeight;
      piece.tilt = 0;
      draw(piece);
    };

    const onBoard = (piece) => piece.row !== null
      && piece.row + piece.rows <= data.size && piece.col + piece.cols <= data.size;

    // Each fragment where it lies highest, along a skyline of what is laid
    // already ([from x, to x, first free y] spans), as the server packs the tray
    const skyline = (room, top) => {
      let spans = [[0, room, top]];
      return (width, height) => {
        const [x, y] = spans.filter(([from]) => from + width <= room)
          .map(([from]) => [from, Math.max(...spans.filter(([a, b]) => a < from + width && b > from).map(([, , free]) => free))])
          .reduce((best, next) => (next[1] < best[1] || (next[1] === best[1] && next[0] < best[0]) ? next : best));
        const upto = x + width + data.gap;
        spans = spans.flatMap(([a, b, free]) => [[a, Math.min(b, x), free], [[Math.max(a, upto), b, free]][0]])
          .filter(([a, b]) => a < b);
        spans.push([x, upto, y + height + data.gap]);
        spans.sort((a, b) => a[0] - b[0]);
        return [x, y];
      };
    };

    // The tray beside the board (wide screens) or below it, as the file has it:
    // the fragments still in the tray go to their new places, those on the board stay
    const layTray = (beside) => {
      if (!beside) {
        svg.setAttribute('viewBox', fileView);
        pieces.forEach((piece, i) => { piece.home = { ...fileHomes[i] }; });
      } else {
        const left = data.board + boardWidth + (2 * data.gap);
        // Room for fragments as wide as the board, side by side, gaps included (as the server's tray)
        const room = Math.max(boardWidth + ((pieces.length - 1) * data.gap), ...pieces.map((piece) => piece.width));
        const place = skyline(room, data.board);
        let bottom = data.board;
        pieces.map((piece, i) => [piece, i]).sort(([a], [b]) => b.rows - a.rows).forEach(([piece, i]) => {
          const [x, y] = place(piece.width, piece.height);
          piece.home = { ...fileHomes[i], x: left + x - data.board, y: y - data.board };
          bottom = Math.max(bottom, y + piece.height);
        });
        const height = Math.max(boardHeight + (2 * data.board), bottom + data.board);
        svg.setAttribute('viewBox', `0 0 ${left + room + data.board} ${height}`);
      }
      pieces.forEach((piece) => {
        if (piece.row !== null) return;
        Object.assign(piece, piece.home);
        draw(piece);
      });
    };

    // Where a fragment would land, as a dashed footprint on the board; off
    // the board, or hanging over its edge, it is drawn in grey
    const ghost = document.createElementNS(SVG_NS, 'rect');
    ghost.setAttribute('class', 'ghost');
    ghost.setAttribute('rx', 6);
    ghost.setAttribute('visibility', 'hidden');
    svg.insertBefore(ghost, $('g.fragment', svg));
    const hideGhost = () => ghost.setAttribute('visibility', 'hidden');
    const showGhost = (piece, x, y) => {
      const col = Math.round(x / cellWidth);
      const row = Math.round(y / cellHeight);
      const overBoard = row + piece.rows > 0 && col + piece.cols > 0 && row < data.size && col < data.size;
      if (!overBoard) return hideGhost();
      ghost.setAttribute('x', data.board + (col * cellWidth));
      ghost.setAttribute('y', data.board + (row * cellHeight));
      ghost.setAttribute('width', piece.width);
      ghost.setAttribute('height', piece.height);
      const fits = row >= 0 && col >= 0 && row + piece.rows <= data.size && col + piece.cols <= data.size;
      ghost.classList.toggle('is-off', !fits);
      return ghost.removeAttribute('visibility');
    };

    // Every board cell's sign as it lies there, [upright, turned, worn] (candidate
    // values, null where it does not read), or null if the board is not covered once over
    const laid = () => {
      if (!pieces.every(onBoard)) return null;
      const board = Array.from({ length: data.size }, () => Array(data.size).fill(null));
      for (const piece of pieces) {
        for (let r = 0; r < piece.rows; r += 1) {
          for (let c = 0; c < piece.cols; c += 1) {
            const [upright, half, worn] = piece.signs[(r * piece.cols) + c];
            const [row, col] = piece.turned ? [piece.rows - 1 - r, piece.cols - 1 - c] : [r, c];
            const cell = board[piece.row + row];
            if (cell[piece.col + col]) return null; // two fragments overlap
            cell[piece.col + col] = piece.turned ? [half, upright, worn] : [upright, half, worn];
          }
        }
      }
      return board;
    };

    // The letters a pair can balance as, '' for a null pair (noise): as the
    // decoder weighs them (Weathering.readings), each tablet value looked up
    const sums = Object.keys(data.tablet).map(Number);
    const lettersOf = (firsts, seconds) => {
      if (!firsts || !seconds) return [];
      const others = new Set(seconds);
      const letters = sums.filter((sum) => firsts.some((a) => others.has(sum - a))).map((sum) => data.tablet[sum]);
      return (others.has(data.null) ? ['', ...letters] : letters).sort();
    };

    // A pair as the decoder's edition prints it, in the Leiden conventions:
    // [r] restored, [b/l] for the words to decide; a restored space is plain
    const token = (letters, worn) => {
      if (!worn) return letters[0];
      if (letters.length > 1) return `[${letters.join('/')}]`;
      return letters[0] === ' ' ? ' ' : `[${letters[0]}]`;
    };

    // How many pairs balance along a path, and the edition they make
    const weigh = (board, path) => {
      let balanced = 0;
      let text = '';
      for (let i = 0; i + 1 < path.length; i += 2) {
        const [[firsts, wornA], [seconds, wornB]] = [path[i], path[i + 1]]
          .map(([row, col, turned]) => [board[row][col][turned ? 1 : 0], board[row][col][2]]);
        const letters = lettersOf(firsts, seconds);
        if (!letters.length) continue;
        balanced += 1;
        if (letters.length > 1 || letters[0] !== '') text += token(letters, wornA || wornB);
      }
      return { balanced, pairs: Math.floor(path.length / 2), text };
    };

    const restore = $('[data-rejoin-restore]');
    const update = () => {
      const board = laid();
      readingEl.textContent = '';
      frame.classList.remove('is-whole');
      if (restore) restore.disabled = true;
      if (!board) {
        const on = pieces.filter(onBoard).length;
        status.textContent = on === total ? 'All on the board, but two overlap.' : `On the board: ${on} of ${total} fragments.`;
        return;
      }
      const best = Object.values(data.paths).map((path) => weigh(board, path))
        .reduce((a, b) => (b.balanced > a.balanced ? b : a));
      if (best.balanced === best.pairs && best.text) {
        status.textContent = 'Whole again: every pair balances.';
        readingEl.textContent = best.text.includes('[')
          ? `It reads, restored: ${best.text}`
          : `It reads: ${best.text}`;
        frame.classList.add('is-whole');
        hand('bell');
        // A ruined plate is won on the bench, which opens on it from here
        if (restore) restore.disabled = false;
        else recordWin();
        return;
      }
      status.textContent = `Covered: ${best.balanced} of ${best.pairs} pairs balance.`;
    };

    // A fragment set down on the board: clay on wood, or two sherds meeting
    // when it lands edge to edge against one already there
    const touches = (a, b) => (a.row < b.row + b.rows && b.row < a.row + a.rows && (a.col + a.cols === b.col || b.col + b.cols === a.col))
      || (a.col < b.col + b.cols && b.col < a.col + a.cols && (a.row + a.rows === b.row || b.row + b.rows === a.row));
    const landed = (piece) => {
      if (!onBoard(piece)) return;
      const joined = pieces.some((other) => other !== piece && onBoard(other) && touches(piece, other));
      hand('sherd', { pan: (((piece.col + (piece.cols / 2)) / data.size) - 0.5) * 1.2, joined });
    };

    const pick = (piece) => {
      picked = piece;
      pieces.forEach((other) => {
        other.group.classList.toggle('is-picked', other === piece);
        other.group.setAttribute('aria-pressed', String(other === piece));
      });
      turnButton.disabled = !piece;
      if (!piece) hideGhost();
    };

    const turn = (piece) => {
      piece.turned = !piece.turned;
      hand('turn');
      draw(piece);
      update();
    };

    // Uppermost while it moves; focus survives the move in the document
    const raise = (piece) => {
      if (svg.lastElementChild === piece.group) return;
      const focused = document.activeElement === piece.group;
      svg.appendChild(piece.group);
      if (focused) piece.group.focus();
    };

    const toSvg = (event) => {
      const point = svg.createSVGPoint();
      point.x = event.clientX;
      point.y = event.clientY;
      return point.matrixTransform(svg.getScreenCTM().inverse());
    };

    let drag = null;
    pieces.forEach((piece, i) => {
      const { group } = piece;
      group.setAttribute('tabindex', '0');
      group.setAttribute('role', 'button');
      group.setAttribute('aria-pressed', 'false');
      group.setAttribute('aria-label', `Fragment ${i + 1} of ${total}: ${piece.rows} rows of ${piece.cols} signs`);

      group.addEventListener('pointerdown', (event) => {
        if (event.button !== 0) return;
        event.preventDefault();
        raise(piece);
        group.focus({ preventScroll: true });
        group.setPointerCapture(event.pointerId);
        drag = { piece, from: toSvg(event), x: piece.x, y: piece.y, moved: false };
      });
      group.addEventListener('pointermove', (event) => {
        if (!drag || drag.piece !== piece) return;
        const at = toSvg(event);
        const [dx, dy] = [at.x - drag.from.x, at.y - drag.from.y];
        if (!drag.moved && Math.hypot(dx, dy) < 6) return;
        drag.moved = true;
        piece.x = drag.x + dx;
        piece.y = drag.y + dy;
        piece.tilt = 0;
        draw(piece);
        showGhost(piece, piece.x, piece.y);
      });
      const drop = () => {
        if (!drag || drag.piece !== piece) return;
        const { moved } = drag;
        drag = null;
        hideGhost();
        if (moved) {
          snap(piece);
          pick(piece);
          landed(piece);
          update();
        } else pick(picked === piece ? null : piece);
      };
      group.addEventListener('pointerup', drop);
      group.addEventListener('pointercancel', drop);
      group.addEventListener('dblclick', () => turn(piece));
      group.addEventListener('keydown', (event) => {
        const steps = { ArrowLeft: [0, -1], ArrowRight: [0, 1], ArrowUp: [-1, 0], ArrowDown: [1, 0] };
        if (event.key in steps) {
          event.preventDefault();
          if (piece.row === null) snap(piece);
          const [dr, dc] = steps[event.key];
          piece.x = (piece.col + dc) * cellWidth;
          piece.y = (piece.row + dr) * cellHeight;
          snap(piece);
          pick(piece);
          landed(piece);
          update();
        } else if (event.key === 't' || event.key === 'T') {
          event.preventDefault();
          turn(piece);
        } else if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          pick(picked === piece ? null : piece);
        } else if (event.key === 'Escape') pick(null);
      });
    });

    // A fragment picked, then a cell: its top-left corner goes there (the
    // ghost shows which cell the pointer is over, until it is laid)
    const cellUnder = (event) => {
      const at = toSvg(event);
      return [Math.floor((at.x - data.board) / cellWidth) * cellWidth, Math.floor((at.y - data.board) / cellHeight) * cellHeight];
    };
    svg.addEventListener('pointermove', (event) => {
      if (drag || !picked || event.pointerType === 'touch') return;
      if (event.target.closest('g.fragment') && event.target.closest('g.fragment') !== picked.group) return hideGhost();
      return showGhost(picked, ...cellUnder(event));
    });
    svg.addEventListener('pointerleave', () => { if (!drag) hideGhost(); });
    svg.addEventListener('click', (event) => {
      if (!picked || event.target.closest('g.fragment')) return;
      [picked.x, picked.y] = cellUnder(event);
      raise(picked);
      snap(picked);
      hideGhost();
      landed(picked);
      picked.group.focus({ preventScroll: true }); // the keys go on moving and turning it
      update();
    });

    turnButton.addEventListener('click', () => { if (picked) turn(picked); });
    resetButton.addEventListener('click', () => {
      pieces.forEach((piece) => {
        Object.assign(piece, piece.home);
        draw(piece);
      });
      pick(null);
      update();
    });

    const wide = window.matchMedia(WIDE);
    layTray(wide.matches);
    wide.addEventListener('change', (event) => layTray(event.matches));
    frame.classList.add('is-rejoining');
    panel.classList.remove('awaits-script');
    $('[data-plate-hint]').classList.remove('awaits-script');
  }

  // ---------- Transcription: the message is read off, letter by letter ----------
  function initTranscription() {
    const el = $('[data-transcription]');
    if (!el) return;
    const text = el.textContent;
    el.dataset.text = text;
    if (reducedMotion || !text) return;
    // Each letter keeps the class of the span it came from (a weathered
    // plate's restorations and doubts)
    const chars = Array.from(el.childNodes).flatMap((node) =>
      Array.from(node.textContent).map((char) => [char, node.nodeType === 1 ? node.className : '']));
    const step = Math.min(32, 1500 / chars.length);
    const shown = document.createElement('span');
    shown.setAttribute('aria-hidden', 'true');
    chars.forEach(([char, css], i) => {
      const span = document.createElement('span');
      span.className = css ? `reveal ${css}` : 'reveal';
      span.style.setProperty('--d', `${Math.round(250 + i * step)}ms`);
      span.textContent = char;
      shown.appendChild(span);
    });
    const spoken = document.createElement('span');
    spoken.className = 'visually-hidden';
    spoken.textContent = text;
    el.replaceChildren(shown, spoken);
  }

  // ---------- Drop zone ----------
  function initDropzone() {
    const zone = $('[data-dropzone]');
    if (!zone) return;
    const input = $('input[type="file"]', zone);
    const name = $('[data-file-name]', zone);
    const show = () => {
      name.textContent = input.files[0] ? input.files[0].name : '';
      if (input.files[0]) $$('svg path', zone).forEach((wedge, i) => Ink.press(wedge, i * 70)); // received
    };

    ['dragenter', 'dragover'].forEach((type) => zone.addEventListener(type, (event) => {
      event.preventDefault();
      zone.classList.add('is-over');
    }));
    ['dragleave', 'drop'].forEach((type) => zone.addEventListener(type, () => zone.classList.remove('is-over')));
    zone.addEventListener('drop', (event) => {
      event.preventDefault();
      if (event.dataTransfer.files.length) {
        input.files = event.dataTransfer.files;
        show();
      }
    });
    input.addEventListener('change', show);
  }

  // ---------- The restoration bench: a weathered plate, restored pair by pair ----------
  // Choose a lacuna (on the plate, or step through them), press a digit back
  // in: its strokes are pressed in rubric where the surface is lost, and the
  // pair is weighed (and, with tally signs, the lacuna's row and column). A
  // sign wholly lost is four lacunae, one per place. The page knows only what
  // the file shows: it says whether things balance, never whether a
  // restoration is right.
  // On a pathless plate (docs/design.md, "Find the path") the bench asks
  // which way the plate runs and lays the way chosen over the grid (Ways):
  // the worn cells take their places along it, read upright or turned as it
  // says, and the pairs form along it. The edition says at once what the way
  // gives: letters, [.] where a lacuna waits, [?] where a pair is off the
  // tablet whatever the lacunae held. The notebook keeps what each way gave;
  // the plate is restored when every lacuna is pressed and every pair balances.
  function initBench() {
    const bench = $('[data-bench]');
    const frame = $('[data-plate]');
    const svg = plateSvg();
    if (!bench || !frame || !svg || !Ink.glyphTable()) return;
    const pathless = 'benchPathless' in bench.dataset;
    const given = JSON.parse(bench.dataset.lacunae);
    if (!pathless && !given.length) return;
    const tally = bench.dataset.tally ? JSON.parse(bench.dataset.tally) : null;
    const letters = Object.fromEntries(Object.entries(Ink.glyphTable().tablet).map(([char, value]) => [value, char]));
    const sums = Object.keys(letters).map(Number);
    const NULL_MARK = 9999;
    const geometry = JSON.parse(frame.dataset.plateLayout);
    const [cellWidth, cellHeight] = geometry.cell;
    const digits = $$('[data-digit]', bench);
    const [which, sumEl, verdict, tallyEl, countEl, edition, notebookEl] = ['which', 'sum', 'verdict', 'tally', 'count', 'edition', 'notebook']
      .map((name) => $(`[data-bench-${name}]`, bench));
    const digitOf = (value, place) => Math.floor(value / place) % 10;
    const canonical = (coords) => {
      const [a, b] = [coords.slice(0, 2), coords.slice(2)];
      return (a[0] < b[0] || (a[0] === b[0] && a[1] <= b[1]) ? [...a, ...b] : [...b, ...a]).join(',');
    };
    const key = (lacuna) => `${lacuna.sign}:${lacuna.place}`;
    // What the bench works on: the lacunae along the way, the signs ([row,
    // col, value (null when worn, or reading as nothing this way), turned]),
    // the lacunae by sign and the digits pressed in. On a pathless plate
    // they are laid again for each way chosen; the digits pressed are kept per way
    let lacunae = [];
    let cells = JSON.parse(frame.dataset.plateCells);
    let bySign = new Map();
    let chosen = new Map(); // "sign:place" => the digit pressed in
    let current = 0;
    let way = null; // a pathless plate: the way laid, once chosen
    const tried = new Map(); // way => { chosen, summary }: the notebook
    const grid = pathless ? JSON.parse(frame.dataset.plateGrid) : null;
    const worn = pathless ? JSON.parse(bench.dataset.benchWorn) : null;

    // A layer over the lacunae: the strokes pressed back, and a target to choose each by
    const layer = document.createElementNS(SVG_NS, 'g');
    layer.setAttribute('class', 'bench-layer');
    svg.appendChild(layer);
    function build(list) {
      lacunae = list;
      bySign = new Map();
      list.forEach((lacuna) => bySign.set(lacuna.sign, [...(bySign.get(lacuna.sign) || []), lacuna]));
      layer.replaceChildren();
      list.forEach((lacuna, i) => {
        const g = document.createElementNS(SVG_NS, 'g');
        g.setAttribute('transform', `translate(${lacuna.x} ${lacuna.y})${lacuna.turned ? ' rotate(180 50 75)' : ''}`);
        const points = lacuna.lost.flatMap((stroke) => {
          const n = stroke.split(',').map(Number);
          return [[n[0], n[1]], [n[2], n[3]]];
        });
        const xs = points.map(([x]) => x);
        const ys = points.map(([, y]) => y);
        // The target to choose it by: the sign's whole cell when it has one
        // lacuna (large enough to find, and to tap, on a phone), else the corner
        const target = document.createElementNS(SVG_NS, 'rect');
        target.setAttribute('class', 'bench-target');
        if (bySign.get(lacuna.sign).length === 1) { // the cell, centred on the sign (100 x 150), a hair inside its edges
          target.setAttribute('x', (-(cellWidth - 100) / 2) + 3);
          target.setAttribute('y', (-(cellHeight - 150) / 2) + 3);
          target.setAttribute('width', cellWidth - 6);
          target.setAttribute('height', cellHeight - 6);
        } else {
          target.setAttribute('x', Math.min(...xs) - 10);
          target.setAttribute('y', Math.min(...ys) - 10);
          target.setAttribute('width', Math.max(...xs) - Math.min(...xs) + 20);
          target.setAttribute('height', Math.max(...ys) - Math.min(...ys) + 20);
        }
        target.setAttribute('rx', 6);
        target.addEventListener('click', () => select(i));
        const pressed = document.createElementNS(SVG_NS, 'g');
        g.append(pressed, target);
        layer.appendChild(g);
        lacuna.view = { target, pressed };
      });
    }

    // A sign's value as far as the reader knows it: undefined while a place is
    // open, null when it reads as no sign the way it is laid
    const valueOf = (sign) => {
      const open = bySign.get(sign);
      if (!open) return cells[sign][2];
      if (!open.every((l) => chosen.has(key(l)))) return undefined;
      return open.reduce((sum, l) => sum + chosen.get(key(l)) * l.place, open[0].known);
    };
    // Its digits as shown: '?' in each place still open
    const shown = (sign) => {
      const open = bySign.get(sign);
      const known = open ? open[0].known : cells[sign][2];
      if (known === null) return '····'; // no sign this way
      const text = String(known).padStart(4, '0').split('');
      (open || []).forEach((l) => { text[3 - Math.log10(l.place)] = chosen.has(key(l)) ? String(chosen.get(key(l))) : '?'; });
      return text.join('');
    };
    // A digit of a sign as far as it is known (undefined while open)
    const digitAt = (sign, place) => {
      const lacuna = (bySign.get(sign) || []).find((l) => l.place === place);
      if (lacuna) return chosen.get(key(lacuna));
      const open = bySign.get(sign);
      return digitOf(open ? open[0].known : cells[sign][2], place);
    };
    // Every value a sign may hold: its open places take any digit the strokes
    // allow (whatever is pressed: the file's word, not the reader's); null
    // when it reads as no sign this way
    const candidatesOf = (sign) => {
      const open = bySign.get(sign);
      if (!open) return cells[sign][2] === null ? null : [cells[sign][2]];
      return open.reduce((values, l) => values.flatMap((v) => l.digits.map((d) => v + (d * l.place))), [open[0].known]);
    };
    // Whether a pair can balance at all, whatever is pressed into what is open
    const possible = (first) => {
      const [firsts, seconds] = [candidatesOf(first), candidatesOf(first + 1)];
      if (!firsts || !seconds) return false;
      const others = new Set(seconds);
      return others.has(NULL_MARK) || firsts.some((a) => sums.some((sum) => others.has(sum - a)));
    };
    // The pairs no digit can balance along the way laid: what tells a wrong way
    const off = () => (pathless && way ? Array.from({ length: cells.length / 2 }, (_, k) => 2 * k).filter((first) => !possible(first)).length : 0);
    // What a pair reads as: a letter, null (an empty pair), false (no balance) or undefined (still open)
    const weigh = (first) => {
      const [a, b] = [valueOf(first), valueOf(first + 1)];
      if (b === NULL_MARK) return null;
      if (a === null || b === null) return false;
      if (a === undefined || b === undefined) return pathless && !possible(first) ? false : undefined;
      return letters[a + b] ?? false;
    };
    // A line's tally in a place: '✓', '✗', or '?' while a digit on it is open
    const lineCheck = (kind, index, place) => {
      const on = cells.map((cell, sign) => [cell, sign]).filter(([cell]) => cell[kind === 'row' ? 0 : 1] === index);
      const found = on.map(([, sign]) => digitAt(sign, place));
      if (found.includes(undefined)) return '?';
      const sum = found.reduce((a, b) => a + b, 0) % 10;
      return sum === digitOf(tally[kind === 'row' ? 'rows' : 'cols'][index], place) ? '✓' : '✗';
    };
    // Every lacuna pressed and every pair balancing: the plate restored
    const pairs = () => Array.from({ length: cells.length / 2 }, (_, k) => weigh(2 * k));
    const complete = () => lacunae.length > 0 && lacunae.every((l) => chosen.has(key(l))) && pairs().every((r) => r !== false);

    // The notebook of a pathless plate: what each way gave, in short lines
    // (five ways must fit three lines on a phone): the pairs off the tablet
    // along it, else how far its restoration went
    const notebook = () => {
      if (!notebookEl) return;
      const lines = Array.from(tried, ([name, t]) => {
        const { off: away, restored, total, done } = t.summary;
        const gave = away ? `${away} off ✗` : (done ? 'restored ✓' : `${restored} of ${total}`);
        return `${WAY_NAMES[name]}: ${gave}`;
      });
      notebookEl.textContent = lines.length ? `Tried: ${lines.join(' · ')}` : 'The notebook: what each way gave.';
    };

    function drawEdition() {
      const out = [];
      const readings = pairs();
      readings.forEach((reading, k) => {
        const first = 2 * k;
        // A null pair is left out when its 9999 can be seen (as the server does);
        // one whose 9999 was lost and pressed back keeps the three characters
        // its [.] took ([·], nothing written here), so the line never rewraps
        if (reading === null && !bySign.has(first + 1)) return;
        if (reading === null) { out.push('[·]'); return; }
        const open = bySign.has(first) || bySign.has(first + 1);
        if (reading === undefined) out.push('[.]');
        else if (reading === false) out.push('[?]');
        else out.push(open ? `[${reading === ' ' ? ' ' : reading}]` : reading); // a restored space: brackets, and no new break
      });
      edition.textContent = out.join('');
      const restored = lacunae.filter((l) => {
        if (!chosen.has(key(l))) return false;
        const reading = weigh(l.sign - (l.sign % 2));
        return reading !== undefined && reading !== false;
      }).length;
      countEl.textContent = `${restored} of ${lacunae.length} restored`;
      const done = complete();
      if (way) tried.get(way).summary = { off: off(), restored, total: lacunae.length, done };
      notebook();
      if (done) recordWin();
    }

    // Short lines that never wrap, even on the smallest phone: the sum, its verdict, the tallies
    function drawBalance() {
      const lacuna = lacunae[current];
      const first = lacuna.sign - (lacuna.sign % 2);
      const reading = weigh(first);
      let total = '?';
      if (reading === null && valueOf(lacuna.sign) !== undefined) total = 'null';
      else if (reading !== undefined && reading !== null && reading !== false) total = valueOf(first) + valueOf(first + 1);
      else if (reading === false && valueOf(first) !== undefined && valueOf(first + 1) !== undefined) total = valueOf(first) + valueOf(first + 1);
      sumEl.textContent = `${shown(first)} + ${shown(first + 1)} = ${total}`;
      const away = off(); // a pathless plate: the pairs no digit can balance along this way
      if (complete()) verdict.textContent = 'Every pair balances.';
      else if (reading === null) verdict.textContent = 'A null pair: any digit.';
      else if (reading === false && !possible(first)) verdict.textContent = 'No digit balances it: not the way.';
      else if (away) verdict.textContent = `${away} ${away === 1 ? 'pair' : 'pairs'} off the tablet: not the way.`;
      else if (reading === undefined) verdict.textContent = 'Press a digit to balance it.';
      else if (reading === false) verdict.textContent = 'Not on the tablet.';
      else verdict.textContent = `“${reading === ' ' ? 'space' : reading}”: it balances.`;
      if (tally && tallyEl) {
        const [row, col] = cells[lacuna.sign];
        tallyEl.textContent = `Tallies, ${PLACE_NAMES[lacuna.place]}: row ${lineCheck('row', row, lacuna.place)}, column ${lineCheck('col', col, lacuna.place)}`;
      }
    }

    function press(lacuna) {
      lacuna.view.pressed.replaceChildren();
      if (!chosen.has(key(lacuna))) return;
      const lost = new Set(lacuna.lost);
      Ink.strokesOf(chosen.get(key(lacuna)) * lacuna.place)
        .filter(({ place, coords }) => place === lacuna.place && lost.has(canonical(coords)))
        .forEach((stroke, i) => {
          const wedge = document.createElementNS(SVG_NS, 'path');
          wedge.setAttribute('d', Ink.glyphTable().wedges[stroke.coords.join(',')]);
          wedge.setAttribute('class', 'restored');
          lacuna.view.pressed.appendChild(wedge);
          Ink.press(wedge, i * 70);
        });
    }

    function select(i) {
      if (!lacunae.length) return;
      current = (i + lacunae.length) % lacunae.length;
      const lacuna = lacunae[current];
      lacunae.forEach((l, k) => l.view.target.classList.toggle('is-current', k === current));
      which.textContent = `Lacuna ${current + 1} of ${lacunae.length}: the ${PLACE_NAMES[lacuna.place]}`;
      digits.forEach((button) => {
        const digit = Number(button.dataset.digit);
        button.disabled = !lacuna.digits.includes(digit);
        button.setAttribute('aria-pressed', String(chosen.get(key(lacuna)) === digit));
        Ink.adopt($('svg', button), digit * lacuna.place);
      });
      drawBalance();
    }

    // Lay a way over the grid: the signs along it (read turned where it says
    // so), the worn cells' lacunae at their places along it, the walk following
    const lay = (name) => {
      const byCell = new Map(grid.map(([row, col, upright, turned]) => [`${row},${col}`, { upright, turned }]));
      const wornAt = new Map(worn.map((cell) => [`${cell.row},${cell.col}`, cell]));
      const path = Ways.path(Math.sqrt(grid.length), name);
      cells = path.map(([row, col, turned]) => {
        const cell = byCell.get(`${row},${col}`);
        return [row, col, turned ? cell.turned : cell.upright, turned];
      });
      const list = path.flatMap(([row, col, turned], sign) => {
        const cell = wornAt.get(`${row},${col}`);
        const entries = cell && (turned ? cell.turned : cell.upright); // null: no sign this way up
        if (!entries) return [];
        const [x, y] = [geometry.padding + (col * cellWidth), geometry.padding + (row * cellHeight)];
        return entries.map((entry) => ({ ...entry, sign, turned, x, y }));
      });
      way = name;
      if (!tried.has(name)) tried.set(name, { chosen: new Map(), summary: { off: 0, restored: 0, total: list.length, done: false } });
      chosen = tried.get(name).chosen;
      build(list);
      list.forEach(press);
      $$('[data-bench-way]', bench).forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.benchWay === name)));
      frame.plateWalk?.follow(cells);
      select(0);
      drawEdition();
    };

    digits.forEach((button) => button.addEventListener('click', () => {
      if (!lacunae.length) return;
      const lacuna = lacunae[current];
      const digit = Number(button.dataset.digit);
      if (chosen.get(key(lacuna)) === digit) {
        chosen.delete(key(lacuna));
        hand('lift'); // the digit taken back
      } else chosen.set(key(lacuna), digit);
      press(lacuna);
      select(current);
      drawEdition();
    }));
    $$('[data-bench-step]', bench).forEach((button) => button.addEventListener('click', () => {
      select(current + Number(button.dataset.benchStep));
    }));
    $$('[data-bench-way]', bench).forEach((button) => button.addEventListener('click', () => lay(button.dataset.benchWay)));

    bench.classList.remove('awaits-script');
    if (!pathless) { // the lacunae along the way the file shows
      build(given);
      select(0);
      drawEdition();
      return;
    }
    // A pathless bench waits for a way. The server drew the edition at its
    // longest ([.] for every pair); a way's edition is never longer, so the
    // line keeps that height and nothing below it moves
    edition.style.minHeight = `${edition.getBoundingClientRect().height}px`;
  }

  document.addEventListener('DOMContentLoaded', () => {
    initModes();
    initLayouts();
    initCounter();
    initPuzzle();
    initReveal();
    initActions();
    initDropzone();
    initPreview();
    initAnatomy();
    initPlayground();
    initLectio();
    initRecord();
    inkPlate();
    initPlateWalk();
    initPlateZoom();
    initDesk();
    initGrille();
    initBench();
    initFragments();
    initTranscription();
  });
})();
