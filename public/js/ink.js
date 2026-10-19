// Cistergraphia ink: the one motion vocabulary of the UI.
//
// Every sign is pressed, as a stylus leaves it in clay: each stroke is a
// wedge. A stroke is never popped in: it is *pressed* (it appears wet in the
// mode's colour, then dries to ink) or *lifted* (it fades). Changing a sign
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

  // Classes are removed when dry, so static styles (highlights) apply again
  // and nothing lingers in exported files
  const drying = new WeakSet();
  function dried(event) {
    if (event.animationName === 'ink-dry') dry(event.currentTarget);
  }

  // Finish drying now (the mark stays where it is, in ink)
  function dry(mark) {
    if (!mark.classList.contains('ink-press')) return;
    mark.classList.remove('ink-press');
    mark.style.removeProperty('--delay');
  }

  function listen(mark) {
    if (drying.has(mark)) return;
    drying.add(mark);
    mark.addEventListener('animationend', dried);
  }

  // Press a wedge (a stroke, or a plate's whole sign): wet in the mode's colour, then drying
  function press(mark, delay = 0) {
    if (reducedMotion) return;
    mark.style.setProperty('--delay', `${Math.round(delay)}ms`);
    mark.classList.remove('ink-press');
    mark.getBoundingClientRect(); // restart the animation
    mark.classList.add('ink-press');
    listen(mark);
  }

  function lift(mark) {
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

  window.Ink = { glyphTable, digitsOf, strokesOf, glyph, adopt, morph, press, dry, lift, normalize, reducedMotion, PLACES };
})();
