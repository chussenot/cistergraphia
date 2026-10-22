// Cistergraphia ink: the one motion vocabulary of the UI.
//
// Every sign is pressed, as a stylus leaves it in clay: each stroke is a
// wedge. A stroke is never popped in: it is *pressed* (the stylus bites at its
// head and runs to its tip, wet in the mode's colour, then the ink dries) or
// *lifted* (it fades). Changing a sign
// *morphs* it: shared strokes stay, the others lift or are pressed. Under
// prefers-reduced-motion everything is instant.
//
// The geometry and the wedges come from the JSON table the server builds from
// Cistergraphia::Glyphs and ::Stylus (data-glyph-table): no second copy of the
// cipher, or of the hand, here.
(() => {
  'use strict';

  const SVG_NS = 'http://www.w3.org/2000/svg';
  const PLACES = [1, 10, 100, 1000];
  const STROKE_GAP = 70; // ms between two strokes of one sign, like a scribe's hand
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  let table;
  function glyphTable() {
    if (table === undefined) {
      const el = document.querySelector('[data-glyph-table]');
      table = el ? JSON.parse(el.dataset.glyphTable) : null;
    }
    return table;
  }

  // 4127 -> [7, 2, 1, 4]: units, tens, hundreds, thousands
  function digitsOf(num) {
    return PLACES.map((place) => Math.floor(num / place) % 10);
  }

  // Strokes of a sign, each tagged with its place (0 for the stem)
  function strokesOf(num) {
    const t = glyphTable();
    const digits = digitsOf(num);
    const strokes = [{ coords: t.stem, place: 0 }];
    PLACES.forEach((place, i) => {
      if (digits[i]) (t.lines[digits[i] * place] || []).forEach((coords) => strokes.push({ coords, place }));
    });
    return strokes;
  }

  // One stroke as its wedge, keyed by the stroke ("x1,y1,x2,y2") for morphing
  function wedgeFor({ coords, place }) {
    const wedge = document.createElementNS(SVG_NS, 'path');
    const key = coords.join(',');
    wedge.setAttribute('d', glyphTable().wedges[key]);
    wedge.dataset.stroke = key;
    wedge.dataset.place = place;
    return wedge;
  }

  // Where a wedge bites and which way it runs, read from its outline:
  // Cistergraphia::Stylus writes the head's back corners first and third (the
  // stroke's start lies between them) and the tail's tip second in the tail
  function bite(mark) {
    const n = (mark.getAttribute('d') || '').match(/-?\d+(?:\.\d+)?/g) || [];
    if (n.length !== 14) return null; // not a wedge
    const [x, y] = [(Number(n[0]) + Number(n[4])) / 2, (Number(n[1]) + Number(n[5])) / 2];
    return { x, y, angle: (Math.atan2(Number(n[11]) - y, Number(n[10]) - x) * 180) / Math.PI };
  }

  // When the wedge is drawn and its ink dry, its classes and styles go, so
  // static styles (highlights) apply again and nothing lingers in exported files
  function settle(mark) {
    mark.classList.remove('ink-press', 'is-wet', 'ink-dry');
    ['--delay', '--dry-delay', '--ox', '--oy', '--a', '--from'].forEach((name) => mark.style.removeProperty(name));
    ['class', 'style'].forEach((name) => { if (!mark.getAttribute(name)) mark.removeAttribute(name); });
  }

  // At the tip the stylus lifts: a wet wedge hands over to drying
  function ended(event) {
    const mark = event.currentTarget;
    if (event.animationName === 'ink-press' && mark.classList.contains('is-wet')) {
      mark.classList.remove('ink-press', 'is-wet');
      mark.classList.add('ink-dry');
    } else if (event.animationName === 'ink-press' || event.animationName === 'ink-dry') {
      settle(mark);
    }
  }

  // Dry the ink now: the wedge is in ink at once, and still runs to its tip
  // if the stylus is on its way
  function dry(mark) {
    mark.classList.remove('is-wet');
    if (mark.classList.contains('ink-dry')) settle(mark);
  }

  // The hand's motions, told to whoever listens (sound.js): the stroke and when it starts
  function tell(name, detail) {
    document.dispatchEvent(new CustomEvent(name, { detail }));
  }

  const listening = new WeakSet();
  function listen(mark) {
    if (listening.has(mark)) return;
    listening.add(mark);
    mark.addEventListener('animationend', ended);
  }

  // Press a wedge: the stylus bites at its head and runs to its tip, wet in
  // the mode's colour, then the ink dries
  function press(mark, delay = 0) {
    tell('ink:press', { mark, delay });
    if (reducedMotion) return;
    const at = bite(mark);
    if (at) {
      mark.style.setProperty('--ox', at.x.toFixed(1));
      mark.style.setProperty('--oy', at.y.toFixed(1));
      mark.style.setProperty('--a', `${at.angle.toFixed(1)}deg`);
      mark.style.setProperty('--from', '0.02');
    }
    mark.style.setProperty('--delay', `${Math.round(delay)}ms`);
    restart(mark);
    mark.classList.add('ink-press', 'is-wet');
    listen(mark);
  }

  // A wedge already there, wet, that dries in its turn: for plates too long to
  // draw stroke by stroke, where the drying front alone shows the reading order
  function wet(mark, delay = 0) {
    tell('ink:press', { mark, delay, wet: true }); // the pressing the drawing skipped
    if (reducedMotion) return;
    mark.style.setProperty('--dry-delay', `${Math.round(delay)}ms`);
    restart(mark);
    mark.classList.add('ink-dry');
    listen(mark);
  }

  // Pressed again: restart (a reflow, only then)
  function restart(mark) {
    if (!mark.classList.contains('ink-press') && !mark.classList.contains('ink-dry')) return;
    mark.classList.remove('ink-press', 'is-wet', 'ink-dry');
    mark.getBoundingClientRect();
  }

  function lift(mark) {
    tell('ink:lift', { mark });
    if (reducedMotion) {
      mark.remove();
      return;
    }
    mark.classList.add('ink-lift');
    mark.addEventListener('animationend', () => mark.remove(), { once: true });
  }

  // A new sign as an inline SVG, optionally pressed stroke by stroke
  function glyph(num, { label, inked = false, delay = 0 } = {}) {
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('class', 'glyph');
    svg.setAttribute('viewBox', glyphTable().viewBox);
    if (label) {
      svg.setAttribute('role', 'img');
      svg.setAttribute('aria-label', label);
    } else {
      svg.setAttribute('aria-hidden', 'true');
    }
    const g = document.createElementNS(SVG_NS, 'g');
    strokesOf(num).forEach((stroke, i) => {
      const wedge = wedgeFor(stroke);
      g.appendChild(wedge);
      if (inked) press(wedge, delay + i * STROKE_GAP);
    });
    svg.appendChild(g);
    return svg;
  }

  // Take over a server-drawn sign: same wedges, now tagged with their strokes and places
  function adopt(svg, num) {
    svg.querySelector('g').replaceChildren(...strokesOf(num).map(wedgeFor));
  }

  // Turn a sign into another: shared strokes stay, the rest lift or are pressed
  function morph(svg, num, { label } = {}) {
    const g = svg.querySelector('g');
    const wanted = new Map(strokesOf(num).map((stroke) => [stroke.coords.join(','), stroke]));
    g.querySelectorAll('path:not(.ink-lift)').forEach((wedge) => {
      const key = wedge.dataset.stroke;
      if (wanted.has(key)) {
        wedge.dataset.place = wanted.get(key).place;
        wanted.delete(key);
      } else {
        lift(wedge);
      }
    });
    let delay = 0;
    wanted.forEach((stroke) => {
      const wedge = wedgeFor(stroke);
      g.appendChild(wedge);
      press(wedge, delay);
      delay += STROKE_GAP;
    });
    if (label) svg.setAttribute('aria-label', label);
  }

  // Same rule as Cistergraphia.normalize: only a-z and single spaces survive
  function normalize(text) {
    return text.toLowerCase().replace(/[^a-z ]/g, ' ').replace(/ +/g, ' ').trim();
  }

  window.Ink = { glyphTable, digitsOf, strokesOf, glyph, adopt, morph, press, wet, dry, lift, normalize, reducedMotion, PLACES };
})();
