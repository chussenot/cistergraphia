// Cistergraphia sound: the sounds of silence (docs/design.md, "Sound").
//
// Silence is the default. Nothing sounds until the reader presses "Hear the
// hand" in the colophon, and the choice is kept in the browser. What is then
// heard is only the hand at work, the motions the page already makes: a
// stroke pressed (the bite), a stroke lifted, a sherd set down, two sherds
// joined, a plate turned, the grille's parchment laid and turned, and one
// bell when a plate is complete. Mistakes are silent. Nothing loops.
//
// Everything is synthesised here with the Web Audio API: no file, no
// request, nothing the Content-Security-Policy need allow. The bite is seeded
// by its stroke, as the wedge is by Cistergraphia::Stylus, so the same stroke
// always sounds the same. The hand is heard where it is: pan follows the
// sign's column on the plate, brightness its row.
//
// ink.js and app.js dispatch the events (ink:press, ink:lift, hand:*); this
// file listens. Without it, the events fall on no one.
(() => {
  'use strict';

  const KEY = 'cistergraphia.sound';
  const MIN_GAP = 0.04; // s between two bites: the hand heard as a patter, never a hail
  const IDLE = 30000; // ms without a sound before the context sleeps
  const BELL_HZ = 392; // the one bell: G4 as its prime

  // ---------- Pure: what a sound is, from what made it ----------

  // A small deterministic hash of a stroke key ("x1,y1,x2,y2"), in [0, 1)
  function seedOf(key) {
    let h = 2166136261;
    for (const ch of String(key)) h = Math.imul(h ^ ch.charCodeAt(0), 16777619);
    return ((h >>> 0) % 10007) / 10007;
  }

  // The bite's band centre (Hz), length (s), knock (Hz) and grain (where in the
  // noise it starts, s) for a stroke: a short stroke bites bright and brief,
  // the stem duller and longer; each a little uneven by its seed, as the wedge
  // is by the hand, and always the same for the same stroke
  function biteParams(coords, seed = 0) {
    const [x1, y1, x2, y2] = coords;
    const length = Math.min(1, Math.hypot(x2 - x1, y2 - y1) / 150); // a sign is 100 x 150
    const wobble = seed - 0.5;
    return {
      centre: Math.round(3200 - (1400 * length) + (300 * wobble)),
      duration: 0.004 + (0.004 * length) + (0.001 * wobble),
      knock: Math.round(150 + (30 * wobble) - (20 * length)),
      grain: 0.9 * seed
    };
  }

  // Where on the plate a wedge bites, from its head and the plate's geometry:
  // pan in [-0.6, 0.6] by column, depth in [0, 1] by row (0 at the top, nearest)
  function placeOf(head, layout) {
    const cols = layout.size;
    const [cellWidth, cellHeight] = layout.cell;
    const col = Math.floor((head.x - layout.padding - layout.offset) / cellWidth);
    const row = Math.floor((head.y - layout.padding - layout.offset) / cellHeight);
    const pan = cols > 1 ? (((Math.min(Math.max(col, 0), cols - 1) + 0.5) / cols) - 0.5) * 1.2 : 0;
    const depth = cols > 1 ? Math.min(Math.max(row, 0), cols - 1) / (cols - 1) : 0;
    return { pan: Math.max(-0.6, Math.min(0.6, pan)), depth };
  }

  // The head of a wedge from its outline, as ink.js reads it
  function headOf(d) {
    const n = (d || '').match(/-?\d+(?:\.\d+)?/g) || [];
    if (n.length !== 14) return null;
    return { x: (Number(n[0]) + Number(n[4])) / 2, y: (Number(n[1]) + Number(n[5])) / 2 };
  }

  // The bell's partials: ratio to the prime, level, decay (s). Hum, prime,
  // tierce, quint, nominal: a bronze bell's inharmonic voice
  const BELL = [[0.5, 0.5, 5], [1, 1, 4], [1.2, 0.6, 3], [1.5, 0.4, 2.5], [2, 0.3, 2]];

  // How loud each part of each sound is: its gain at the peak. A laptop's or
  // a phone's speaker gives nothing below about 300 Hz, so what must be heard
  // sits above it: the bite is its tick (the knock is body, for headphones),
  // the sherd its thud and rings. test/ui/play.js renders every sound and
  // holds each above a floor ("sound levels"); docs/design.md has the targets
  const LEVELS = {
    tick: 4.5, knock: 0.12, lift: 0.4, thud: 1.1, ring: 0.4,
    turn: 1.8, parchment: 0.45, bell: 0.22, strike: 0.12
  };

  // The guard on the sum, instead of a compressor: what any sound or sum of
  // sounds is below -6 dBFS passes untouched, above it is rounded off, and
  // nothing ever reaches full scale. Stateless, so it has no attack, release
  // or warm-up: a compressor made with the context squashes the first 50 ms
  // it hears by 15 dB, and the first sound heard is the reader's first press
  function softClip(x) {
    const size = Math.abs(x);
    if (size <= 0.5) return x;
    return Math.sign(x) * (0.5 + (0.5 * Math.tanh((size - 0.5) / 0.5)));
  }

  // A second of white noise in [-1, 1), the same on every page (a small
  // linear congruential generator): a stroke's bite is cut from it at its
  // grain, so it sounds the same on every visit, and as loud
  function noiseOf(length) {
    const samples = new Float32Array(length);
    let state = 0x2545f491;
    for (let i = 0; i < length; i += 1) {
      state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
      samples[i] = (state / 2147483648) - 1;
    }
    return samples;
  }

  const pure = { seedOf, noiseOf, biteParams, placeOf, headOf, BELL, MIN_GAP, LEVELS, softClip };
  if (typeof module !== 'undefined' && module.exports) module.exports = pure;
  if (typeof document === 'undefined') return;

  // ---------- The scriptorium's instrument ----------
  const night = window.matchMedia('(prefers-color-scheme: dark)');
  let ctx = null;
  let master = null;
  let noiseBuffer = null;
  let lastBite = -Infinity;
  let bellUntil = -Infinity;
  let sleep = null;
  let heard = false; // the context has run once: the browser lets this page sound
  const voices = new Set(); // the teardown timers of the voices still sounding

  // A promise the page need not wait for: resume() and suspend() reject once
  // the reader has left the page (Firefox: "Navigated away from page")
  const quietly = (promise) => { if (promise && promise.catch) promise.catch(() => {}); };

  function level() {
    return night.matches ? 0.4 : 0.8; // Vigils, the night office, 6 dB quieter
  }

  function instrument() {
    if (ctx) return ctx;
    const Context = window.AudioContext || window.webkitAudioContext;
    if (!Context) return null;
    ctx = new Context();
    master = ctx.createGain();
    master.gain.value = level();
    const guard = ctx.createWaveShaper();
    const curve = new Float32Array(1025);
    for (let i = 0; i < curve.length; i += 1) curve[i] = softClip(((2 * i) / (curve.length - 1)) - 1);
    guard.curve = curve;
    master.connect(guard).connect(ctx.destination);
    const running = () => { if (ctx.state === 'running') heard = true; };
    ctx.addEventListener('statechange', running);
    running();
    noiseBuffer = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
    noiseBuffer.getChannelData(0).set(noiseOf(ctx.sampleRate));
    night.addEventListener('change', () => { if (master) master.gain.setTargetAtTime(level(), ctx.currentTime, 0.05); });
    return ctx;
  }

  // The context wakes for a sound and sleeps after a while without one
  // ('interrupted': Safari's, by a call or another app)
  function awake() {
    if (!instrument()) return null;
    if (ctx.state !== 'running') quietly(ctx.resume());
    clearTimeout(sleep);
    sleep = setTimeout(() => { if (ctx && ctx.state === 'running') quietly(ctx.suspend()); }, IDLE);
    return ctx;
  }

  // A voice: its gain into a panner into the master, torn down when done
  function voice(pan, until) {
    const gain = ctx.createGain();
    const panner = ctx.createStereoPanner();
    panner.pan.value = pan;
    gain.connect(panner).connect(master);
    const timer = setTimeout(() => {
      voices.delete(timer);
      gain.disconnect();
      panner.disconnect();
    }, ((until - ctx.currentTime) * 1000) + 100);
    voices.add(timer);
    return gain;
  }

  // Leaving the page: nothing left to tear down once the page is gone, and a
  // voice's nodes may no longer be touched (Firefox throws on them)
  window.addEventListener('pagehide', () => {
    voices.forEach(clearTimeout);
    voices.clear();
    clearTimeout(sleep);
  });

  // Noise from `grain` s into the buffer: the bite's own grain, anywhere for the rest
  function noise(when, until, grain = Math.random() * 0.9) {
    const source = ctx.createBufferSource();
    source.buffer = noiseBuffer;
    source.loop = true;
    source.start(when, grain);
    source.stop(until);
    return source;
  }

  function filter(type, frequency, q = 1) {
    const node = ctx.createBiquadFilter();
    node.type = type;
    node.frequency.value = frequency;
    node.Q.value = q;
    return node;
  }

  function envelope(gain, when, peak, attack, until) {
    gain.gain.setValueAtTime(0.0001, when);
    gain.gain.linearRampToValueAtTime(peak, when + attack);
    gain.gain.exponentialRampToValueAtTime(0.0001, until);
  }

  // The stylus biting clay: a dry tick in its band, with a faint low knock
  function bite(when, { centre, duration, knock, grain }, { pan = 0, depth = 0 } = {}) {
    if (when < lastBite + MIN_GAP) return; // thinned to a patter
    lastBite = when;
    const until = when + duration + 0.05;
    const out = voice(pan, until);
    const far = filter('lowpass', 6000 - (3500 * depth));
    far.connect(out);
    const tick = ctx.createGain();
    envelope(tick, when, LEVELS.tick, 0.0005, when + duration);
    noise(when, when + duration + 0.005, grain).connect(filter('bandpass', centre, 5)).connect(tick).connect(far);
    const osc = ctx.createOscillator();
    osc.frequency.value = knock;
    const thud = ctx.createGain();
    envelope(thud, when, LEVELS.knock, 0.001, when + 0.04);
    osc.connect(thud).connect(far);
    osc.start(when);
    osc.stop(when + 0.05);
  }

  // The stylus leaving the clay: a breath of noise, no knock
  function lift(when, pan = 0) {
    const until = when + 0.015;
    const out = voice(pan, until);
    envelope(out, when, LEVELS.lift, 0.002, until);
    noise(when, until).connect(filter('highpass', 3000)).connect(out);
  }

  // Clay set down on wood: a low thud with two faint ringing modes
  function sherd(when, pan = 0) {
    const until = when + 0.13;
    const out = voice(pan, until);
    const thud = ctx.createGain();
    envelope(thud, when, LEVELS.thud, 0.003, when + 0.1);
    noise(when, when + 0.1).connect(filter('lowpass', 600)).connect(thud).connect(out);
    [320, 530].forEach((hz, i) => {
      const osc = ctx.createOscillator();
      osc.frequency.value = hz;
      const ring = ctx.createGain();
      envelope(ring, when, LEVELS.ring / (i + 1), 0.002, when + 0.12);
      osc.connect(ring).connect(out);
      osc.start(when);
      osc.stop(until);
    });
  }

  // Two sherds meeting edge to edge: two dry bites, 12 ms apart
  function join(when, pan = 0) {
    const params = biteParams([0, 0, 40, 0], 0.5);
    [0, 0.012].forEach((gap) => {
      lastBite = -Infinity;
      bite(when + gap, params, { pan });
    });
  }

  // Clay slid half round on wood: a low scrape that swells and settles, in the
  // middle of the visual turn
  function turn(when) {
    const start = when + 0.15;
    const until = start + 0.4;
    const out = voice(0, until);
    out.gain.setValueAtTime(0.0001, start);
    out.gain.linearRampToValueAtTime(LEVELS.turn, start + 0.12);
    out.gain.exponentialRampToValueAtTime(0.0001, until);
    const band = filter('bandpass', 420, 2);
    band.frequency.linearRampToValueAtTime(240, until);
    noise(start, until).connect(band).connect(out);
  }

  // A pierced sheet laid on the plate, dragged a quarter turn, or lifted:
  // paper's sound, high and dry, with no body
  function parchment(when, kind) {
    const length = kind === 'turn' ? 0.4 : 0.15;
    const until = when + length;
    const out = voice(0, until);
    if (kind === 'lift') {
      out.gain.setValueAtTime(0.0001, when);
      out.gain.linearRampToValueAtTime(LEVELS.parchment, until - 0.02);
      out.gain.linearRampToValueAtTime(0, until);
    } else envelope(out, when, LEVELS.parchment, 0.02, until);
    const band = filter('bandpass', kind === 'turn' ? 4500 : 4000, 1);
    if (kind === 'turn') band.frequency.linearRampToValueAtTime(3000, until);
    noise(when, until).connect(filter('highpass', 1500)).connect(band).connect(out);
  }

  // Bronze struck once: inharmonic partials with their own decays, never cut,
  // one at a time
  function bell(when) {
    if (when < bellUntil) return;
    bellUntil = when + 5;
    const until = when + 5.2;
    const out = voice(0, until);
    out.gain.value = 1;
    BELL.forEach(([ratio, amount, decay]) => {
      const osc = ctx.createOscillator();
      osc.frequency.value = BELL_HZ * ratio;
      const partial = ctx.createGain();
      partial.gain.setValueAtTime(LEVELS.bell * amount, when);
      partial.gain.exponentialRampToValueAtTime(0.0001, when + decay);
      osc.connect(partial).connect(out);
      osc.start(when);
      osc.stop(when + decay + 0.1);
    });
    const strike = ctx.createGain();
    envelope(strike, when, LEVELS.strike, 0.001, when + 0.01);
    noise(when, when + 0.015).connect(filter('bandpass', 2000, 2)).connect(strike).connect(out);
  }

  // ---------- Listening to the hand ----------
  let enabled = false;
  try { enabled = localStorage.getItem(KEY) === 'on'; } catch (error) { /* private mode: silent */ }

  const layouts = new WeakMap();
  function whereIs(mark) {
    const frame = mark.closest('[data-plate]');
    if (!frame || !frame.dataset.plateLayout) return { pan: 0, depth: 0 };
    if (!layouts.has(frame)) layouts.set(frame, JSON.parse(frame.dataset.plateLayout));
    const head = headOf(mark.getAttribute('d'));
    return head ? placeOf(head, layouts.get(frame)) : { pan: 0, depth: 0 };
  }

  // When a sound asked for now (or after a delay, in ms) is to start, or null
  // when it cannot sound. A context the browser has not yet let run (a page
  // opened with the sound on, no press on it yet) stays at time 0, and what is
  // asked of it is dropped: queued, it would all sound at once when the reader
  // first presses something. Asleep, it keeps its place and wakes for it
  function at(delay = 0) {
    if (!awake()) return null;
    if (ctx.state !== 'running' && !heard) return null;
    return ctx.currentTime + (delay / 1000);
  }

  document.addEventListener('ink:press', (event) => {
    if (!enabled) return;
    const { mark, delay } = event.detail;
    const when = at(delay);
    if (when === null) return;
    const coords = (mark.dataset.stroke || '0,0,0,150').split(',').map(Number);
    bite(when, biteParams(coords, seedOf(mark.dataset.stroke || mark.getAttribute('d'))), whereIs(mark));
  });
  document.addEventListener('ink:lift', (event) => {
    if (!enabled) return;
    const when = at();
    if (when !== null) lift(when, whereIs(event.detail.mark).pan);
  });
  const hands = {
    bite: (when) => bite(when, biteParams([0, 0, 60, 0], 0.5)),
    lift: (when) => lift(when),
    sherd: (when, { pan = 0, joined = false }) => (joined ? join(when, pan) : sherd(when, pan)),
    turn,
    parchment: (when, { kind }) => parchment(when, kind),
    bell
  };
  Object.entries(hands).forEach(([kind, play]) => {
    document.addEventListener(`hand:${kind}`, (event) => {
      if (!enabled) return;
      const when = at();
      if (when !== null) play(when, event.detail || {});
    });
  });

  // A page opened with the sound on may not sound before the reader's first
  // press on it (Safari, Firefox; Chrome after a while away): the first press
  // or key wakes the context, inside the gesture the browser asks for
  ['pointerdown', 'keydown', 'touchend'].forEach((type) => {
    document.addEventListener(type, () => {
      if (enabled && !(ctx && ctx.state === 'running')) awake();
    }, { capture: true, passive: true });
  });

  // ---------- The one control: Hear the hand / Silence ----------
  const control = document.querySelector('[data-hear]');
  if (control) {
    const show = () => {
      control.setAttribute('aria-pressed', String(enabled));
      control.textContent = enabled ? 'Silence' : 'Hear the hand';
    };
    control.classList.remove('awaits-script');
    show();
    control.addEventListener('click', () => {
      enabled = !enabled;
      try { localStorage.setItem(KEY, enabled ? 'on' : 'off'); } catch (error) { /* private mode: for this page */ }
      if (enabled) {
        // The press is the gesture the browser asks for, and is itself heard:
        // one bite, once the context runs, so the reader knows at once
        if (awake()) {
          quietly(ctx.resume().then(() => {
            if (enabled) hands.bite(ctx.currentTime);
          }));
        }
      } else if (ctx) quietly(ctx.suspend());
      show();
    });
  }
})();
