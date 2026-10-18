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
    animatePlate();
  });
})();
