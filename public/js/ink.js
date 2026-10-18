// Cistergraphia ink: the one motion vocabulary of the UI.
//
// A stroke is never popped in: it is *inked* (drawn from one end to the
// other, wet in the mode's colour, then drying to ink) or *lifted* (it fades).
// Changing a sign *morphs* it: shared strokes stay, the others lift or are
// inked. Under prefers-reduced-motion everything is instant.
//
// The geometry comes from the JSON table the server builds from
// Cistergraphia::Glyphs (data-glyph-table): no second copy of the cipher here.
(() => {
  'use strict';

  const SVG_NS = 'http://www.w3.org/2000/svg';
  const PLACES = [1, 10, 100, 1000];
  const ATTRS = ['x1', 'y1', 'x2', 'y2'];
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

  const coordsOf = (line) => ATTRS.map((a) => Number(line.getAttribute(a)));
  const keyOf = (coords) => coords.join(',');

  function lineFor({ coords, place }) {
    const line = document.createElementNS(SVG_NS, 'line');
    ATTRS.forEach((a, i) => line.setAttribute(a, coords[i]));
    line.dataset.place = place;
    return line;
  }

  // Ink one line: drawn, then drying. Classes are removed when dry, so static
  // styles (highlights) apply again and nothing lingers in exported files.
  const drying = new WeakSet();
  function dried(event) {
    if (event.animationName === 'ink-dry') dry(event.currentTarget);
  }

  // Finish drying now (the stroke stays where it is, in ink)
  function dry(line) {
    if (!line.classList.contains('ink-in')) return;
    line.classList.remove('ink-in');
    line.style.removeProperty('--len');
    line.style.removeProperty('--delay');
  }

  function inkIn(line, delay = 0) {
    if (reducedMotion) return;
    const [x1, y1, x2, y2] = coordsOf(line);
    line.style.setProperty('--len', Math.hypot(x2 - x1, y2 - y1).toFixed(1));
    line.style.setProperty('--delay', `${Math.round(delay)}ms`);
    line.classList.remove('ink-in');
    line.getBoundingClientRect(); // restart the animation
    line.classList.add('ink-in');
    if (!drying.has(line)) {
      drying.add(line);
      line.addEventListener('animationend', dried);
    }
  }

  function lift(line) {
    if (reducedMotion) {
      line.remove();
      return;
    }
    line.classList.add('ink-lift');
    line.addEventListener('animationend', () => line.remove(), { once: true });
  }

  // A new sign as an inline SVG, optionally inked stroke by stroke
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
      const line = lineFor(stroke);
      g.appendChild(line);
      if (inked) inkIn(line, delay + i * STROKE_GAP);
    });
    svg.appendChild(g);
    return svg;
  }

  // Take over a server-drawn sign: same strokes, now tagged with their places
  function adopt(svg, num) {
    svg.querySelector('g').replaceChildren(...strokesOf(num).map(lineFor));
  }

  // Turn a sign into another: shared strokes stay, the rest lift or are inked
  function morph(svg, num, { label } = {}) {
    const g = svg.querySelector('g');
    const wanted = new Map(strokesOf(num).map((stroke) => [keyOf(stroke.coords), stroke]));
    g.querySelectorAll('line:not(.ink-lift)').forEach((line) => {
      const key = keyOf(coordsOf(line));
      if (wanted.has(key)) {
        line.dataset.place = wanted.get(key).place;
        wanted.delete(key);
      } else {
        lift(line);
      }
    });
    let delay = 0;
    wanted.forEach((stroke) => {
      const line = lineFor(stroke);
      g.appendChild(line);
      inkIn(line, delay);
      delay += STROKE_GAP;
    });
    if (label) svg.setAttribute('aria-label', label);
  }

  // Same rule as Cistergraphia.normalize: only a-z and single spaces survive
  function normalize(text) {
    return text.toLowerCase().replace(/[^a-z ]/g, ' ').replace(/ +/g, ' ').trim();
  }

  window.Ink = { glyphTable, digitsOf, strokesOf, glyph, adopt, morph, inkIn, dry, lift, normalize, reducedMotion, PLACES };
})();
