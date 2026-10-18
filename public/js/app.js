// Cistergraphia web UI: progressive enhancement only.
// Every form works without this file; it adds the mode switch, the ink
// animation, exports, drag & drop and small conveniences.
(() => {
  'use strict';

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

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

  // ---------- Glyphs, drawn from the table the server embeds ----------
  // The geometry comes from Cistergraphia::Glyphs (data-glyph-table), so the
  // browser never holds its own copy of the cipher.
  const SVG_NS = 'http://www.w3.org/2000/svg';
  let glyphTable;
  function table() {
    if (glyphTable === undefined) {
      const el = $('[data-glyph-table]');
      glyphTable = el ? JSON.parse(el.dataset.glyphTable) : null;
    }
    return glyphTable;
  }

  // 1098 -> [1000, 90, 8]: each digit times its place value
  function placeValues(num) {
    return String(num).split('').reverse().map((d, i) => Number(d) * 10 ** i).filter((v) => v > 0);
  }

  function glyphSvg(num, label) {
    const t = table();
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('class', 'glyph');
    svg.setAttribute('viewBox', t.viewBox);
    if (label) {
      svg.setAttribute('role', 'img');
      svg.setAttribute('aria-label', label);
    } else {
      svg.setAttribute('aria-hidden', 'true');
    }
    const g = document.createElementNS(SVG_NS, 'g');
    [t.stem, ...placeValues(num).flatMap((v) => t.lines[v] || [])].forEach(([x1, y1, x2, y2]) => {
      const line = document.createElementNS(SVG_NS, 'line');
      line.setAttribute('x1', x1); line.setAttribute('y1', y1);
      line.setAttribute('x2', x2); line.setAttribute('y2', y2);
      g.appendChild(line);
    });
    svg.appendChild(g);
    return svg;
  }

  // Same rule as Cistergraphia.normalize: only a-z and single spaces survive
  function normalize(text) {
    return text.toLowerCase().replace(/[^a-z ]/g, ' ').replace(/ +/g, ' ').trim();
  }

  // ---------- Live preview: each letter's sign while typing ----------
  const PREVIEW_LIMIT = 60;
  function initPreview() {
    const preview = $('[data-preview]');
    const field = $('[data-counted]');
    if (!preview || !field || !table()) return;
    const list = $('[data-preview-signs]', preview);
    const empty = $('[data-preview-empty]', preview);
    let frame;

    const render = () => {
      const chars = Array.from(normalize(field.value));
      const shown = chars.slice(0, PREVIEW_LIMIT);
      const items = shown.map((char) => {
        const li = document.createElement('li');
        li.appendChild(glyphSvg(table().tablet[char]));
        const caption = document.createElement('span');
        caption.textContent = char === ' ' ? '·' : char;
        if (char === ' ') li.classList.add('is-space');
        li.appendChild(caption);
        return li;
      });
      if (chars.length > shown.length) {
        const more = document.createElement('li');
        more.className = 'preview-more';
        more.textContent = `+${chars.length - shown.length}`;
        items.push(more);
      }
      list.replaceChildren(...items);
      empty.hidden = chars.length > 0;
    };
    field.addEventListener('input', () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(render);
    });
    preview.hidden = false;
    render();
  }

  // ---------- Playground: any number, its sign (About page) ----------
  const PLACE_NAMES = [[1000, 'thousand', 'thousands'], [100, 'hundred', 'hundreds'], [10, 'ten', 'tens'], [1, 'unit', 'units']];
  function reading(num) {
    return PLACE_NAMES.map(([place, one, many]) => {
      const digit = Math.floor(num / place) % 10;
      return `${digit} ${digit === 1 ? one : many}`;
    }).join(' · ');
  }

  function initPlayground() {
    const input = $('[data-playground]');
    if (!input || !table()) return;
    const holder = $('[data-playground-glyph]');
    const text = $('[data-playground-reading]');
    const update = () => {
      const value = Math.trunc(Number(input.value));
      if (!Number.isFinite(value) || value < 0 || value > 9999) {
        input.setAttribute('aria-invalid', 'true');
        return;
      }
      input.removeAttribute('aria-invalid');
      holder.replaceChildren(glyphSvg(value, `The Cistercian sign for ${value}`));
      text.textContent = reading(value);
    };
    input.addEventListener('input', update);
    $$('[data-playground-set]').forEach((button) => button.addEventListener('click', () => {
      input.value = button.dataset.playgroundSet;
      update();
    }));
  }

  // ---------- Mode switch (game = red, secret = blue) ----------
  function initModes() {
    const form = $('[data-entry]');
    if (!form) return;
    const secretOnly = $$('[data-secret-only]', form);
    const notes = $$('[data-mode-note]', form);
    const submit = $('[data-submit]', form);
    const passphrase = $('#passphrase', form);

    const apply = () => {
      const mode = $('input[name="mode"]:checked', form)?.value || 'game';
      document.body.dataset.mode = mode;
      const secret = mode === 'secret';
      secretOnly.forEach((el) => { el.hidden = !secret; });
      notes.forEach((el) => { el.hidden = el.dataset.modeNote !== mode; });
      if (passphrase) {
        passphrase.disabled = !secret;
        passphrase.required = secret;
      }
      if (submit) submit.textContent = secret ? 'Seal & inscribe' : 'Inscribe';
    };
    $$('input[name="mode"]', form).forEach((radio) => radio.addEventListener('change', apply));
    apply();
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

  // ---------- The plate: ink drawn along the snail ----------
  function plateSvg() {
    return $('[data-plate] svg');
  }

  function animatePlate() {
    const svg = plateSvg();
    if (!svg || reducedMotion) return;
    const lines = $$('line', svg);
    // Lines come in reading order, each symbol starting with its 150-unit stem
    const stems = lines.filter((l) => l.getAttribute('x1') === l.getAttribute('x2') &&
      Math.abs(l.getAttribute('y2') - l.getAttribute('y1')) === 150).length || 1;
    const step = Math.min(45, 2600 / stems);
    let symbol = -1;
    lines.forEach((line) => {
      const [x1, y1, x2, y2] = ['x1', 'y1', 'x2', 'y2'].map((a) => Number(line.getAttribute(a)));
      const length = Math.hypot(x2 - x1, y2 - y1);
      if (x1 === x2 && Math.abs(y2 - y1) === 150) symbol += 1;
      line.style.setProperty('--len', length.toFixed(1));
      line.style.setProperty('--delay', `${Math.round(Math.max(symbol, 0) * step)}ms`);
    });
    svg.classList.add('is-drawing');
  }

  // The exported file must be the plain SVG the decoder reads: drop the
  // animation styles and classes added for display
  function cleanSvgSource() {
    const svg = plateSvg();
    if (!svg) return null;
    const clone = svg.cloneNode(true);
    clone.removeAttribute('class');
    $$('[style]', clone).forEach((el) => el.removeAttribute('style'));
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
        copy($('[data-transcription]')?.textContent || '', 'Message copied');
        return;
      }
      const source = cleanSvgSource();
      if (!source) return;
      if (action === 'download-svg') download(new Blob([source], { type: 'image/svg+xml' }), 'cistergraphia.svg');
      if (action === 'download-png') downloadPng(source);
      if (action === 'copy-svg') copy(source, 'SVG code copied');
    });
  }

  // ---------- Drop zone ----------
  function initDropzone() {
    const zone = $('[data-dropzone]');
    if (!zone) return;
    const input = $('input[type="file"]', zone);
    const name = $('[data-file-name]', zone);
    const show = () => { name.textContent = input.files[0] ? input.files[0].name : ''; };

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
    initCounter();
    initReveal();
    initActions();
    initDropzone();
    initPreview();
    initPlayground();
    animatePlate();
  });
})();
