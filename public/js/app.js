// Cistergraphia web UI: progressive enhancement only.
// Every form works without this file. It adds the mode switch, the live
// preview, the dials, the walkable plate, Lectio, exports and drag & drop.
// Motion comes from ink.js, and only where it carries meaning.
(() => {
  'use strict';

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  const SVG_NS = 'http://www.w3.org/2000/svg';
  const { reducedMotion } = window.Ink;
  const PLACE_NAMES = { 1: 'units', 10: 'tens', 100: 'hundreds', 1000: 'thousands' };

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

    const apply = () => {
      const mode = $('input[name="mode"]:checked', form)?.value || 'game';
      document.body.dataset.mode = mode;
      const secret = mode === 'secret';
      if (passphrase) {
        passphrase.disabled = !secret;
        passphrase.required = secret;
      }
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
    const update = () => {
      count.textContent = field.value.length;
      counter.classList.toggle('is-near', field.value.length > max * 0.9);
    };
    field.addEventListener('input', update);
    update();
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
    const cells = JSON.parse(frame.dataset.plateCells);
    const layout = JSON.parse(frame.dataset.plateLayout);
    // The live reading and the resting caption share one cell (CSS): walking
    // swaps them in place, so nothing below the plate moves
    const readingEl = $('[data-plate-reading]');
    const caption = readingEl.closest('.plate-reading');
    const index = new Map(cells.map(([row, col], i) => [`${row},${col}`, i]));
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
    const show = (i) => {
      current = i;
      if (i < 0) {
        focus.classList.remove('is-visible');
        readingEl.textContent = '';
        caption.classList.remove('is-walking');
        return;
      }
      const [row, col, value, turned] = cells[i];
      const x = layout.padding + (col * cellWidth) - (layout.space / 2);
      const y = layout.padding + (row * cellHeight) - (layout.space / 2);
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
      readingEl.textContent = `Sign ${i + 1} of ${cells.length} · ${value}${upsideDown}`;
      caption.classList.add('is-walking');
    };

    if (turnButton) {
      turnButton.classList.remove('awaits-script');
      turnButton.addEventListener('click', () => {
        const turned = !isTurned();
        frame.classList.toggle('is-turned', turned);
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
      const col = Math.floor(((view.x + (fx * view.width)) - layout.padding + (layout.space / 2)) / cellWidth);
      const row = Math.floor(((view.y + (fy * view.height)) - layout.padding + (layout.space / 2)) / cellHeight);
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
  }

  // The exported file must be the plain SVG the decoder reads: drop
  // everything added for display (ink, highlight, classes, styles)
  function cleanSvgSource() {
    const svg = plateSvg();
    if (!svg) return null;
    const clone = svg.cloneNode(true);
    $$('.plate-focus', clone).forEach((el) => el.remove());
    [clone, ...$$('*', clone)].forEach((el) => {
      el.removeAttribute('class');
      el.removeAttribute('style');
    });
    return new XMLSerializer().serializeToString(clone);
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
      const source = cleanSvgSource();
      if (!source) return;
      if (action === 'download-svg') download(new Blob([source], { type: 'image/svg+xml' }), 'cistergraphia.svg');
      if (action === 'download-png') downloadPng(source);
      if (action === 'copy-svg') copy(source, 'SVG code copied');
    });
  }

  // ---------- Transcription: the message is read off, letter by letter ----------
  function initTranscription() {
    const el = $('[data-transcription]');
    if (!el) return;
    const text = el.textContent;
    el.dataset.text = text;
    if (reducedMotion || !text) return;
    const chars = Array.from(text);
    const step = Math.min(32, 1500 / chars.length);
    const shown = document.createElement('span');
    shown.setAttribute('aria-hidden', 'true');
    chars.forEach((char, i) => {
      const span = document.createElement('span');
      span.className = 'reveal';
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

  document.addEventListener('DOMContentLoaded', () => {
    initModes();
    initLayouts();
    initCounter();
    initReveal();
    initActions();
    initDropzone();
    initPreview();
    initAnatomy();
    initPlayground();
    initLectio();
    inkPlate();
    initPlateWalk();
    initTranscription();
  });
})();
