# Design: "The Abbey Index"

The web UI is styled as a leaf from a Cistercian library index: the catalogue the monks
kept of their books, where the numerals behind this cipher were used.

![Inscribe](web-ui-inscribe.png)

## Concept

**Cistercian restraint is already modern.** St Bernard's reforms banned gold, colour and
ornament from the order's buildings and books. What remained (undyed vellum, iron-gall ink,
ruled lines, and plain initials in one colour) is close to today's minimalism. The UI keeps
that restraint and adds modern structure: a grid, clear controls, real states and motion.

Three ideas carry the design:

1. **Two colours, two modes.** Cistercian scribes allowed themselves monochrome initials in
   red *or* blue. Here **minium red is the game** and **woad blue is the sealed secret**. The
   whole page (headings, buttons, focus rings, the brand mark) changes colour with the mode,
   so the user always knows which one they are in.
2. **The page teaches the cipher.** The key beside the form (one sign's anatomy, the units
   tabula, the snail) is drawn from the real cipher geometry (`Cistergraphia::Glyphs`), so it
   can never drift from what the encoder produces.
3. **Motion shows the snail.** On the result page each stroke is inked in reading order, so
   the spiral path is visible the first time you see a plate. It is off under
   `prefers-reduced-motion`.

## Tokens

All values are CSS custom properties in [`public/css/app.css`](../public/css/app.css).

| Token | Light (vellum) | Dark ("Vigils") | Use | Contrast |
|---|---|---|---|---|
| `--vellum` | `#f3ede1` | `#191714` | page, inputs | |
| `--paper` | `#fbf8f2` | `#211e1a` | leaves | |
| `--ink` | `#2b241c` | `#ece4d4` | text, glyphs | 13–14 : 1 |
| `--ink-soft` | `#62574a` | `#b3a894` | secondary text, control borders | 6–7.6 : 1 |
| `--rubric` | `#a3301c` | `#e8826b` | game accent | 6–6.7 : 1 |
| `--woad` | `#2b4a74` | `#93b3e3` | secret accent | 7.7–8.5 : 1 |
| `--rule` | `#d9cdb6` | `#3b352d` | ruling lines (decorative only) | |
| `--accent` | rubric, or woad when `body[data-mode="secret"]` | | everything mode-coloured | |

Every text colour passes WCAG AA, most of them AAA. Control borders use `--ink-soft` to meet
the 3:1 non-text contrast rule.

**Type.** EB Garamond (OFL, self-hosted, ~75 KB for three cuts) for reading text,
headings and messages, with old-style figures. The system sans is used, letter-spaced in
capitals, for labels and buttons: the "index" voice. The system mono is used for SVG code
and the passphrase.

**Space.** A 4 px based scale (`--space-1` to `--space-8`), a reading measure of 62ch, and a
3 px radius (manuscripts are not rounded; controls are, slightly).

## Components

| Component | Notes |
|---|---|
| Leaf (`.leaf`) | Paper card with the double vertical bounding lines of a ruled writing area; folio mark (`fol. 1r`…) top right, hidden on phones |
| Rubric (`.rubric`) | Page title in the mode colour |
| Index heading (`.index-heading`) | Small capitals followed by a hairline rule |
| Mode cards (`.mode`) | Native radios styled as two index cards; the first letter is a red or blue initial; the checked card gets an inset bar |
| Fields | Labels in small capitals; vellum-filled inputs; a focus ring in the mode colour |
| Buttons | Primary uses the mode colour; secondary is outlined; quiet is link-like; all are at least 48 px tall |
| Plate (`.plate-frame`) | The SVG in ink colours (CSS only) inside a double frame, scaled to fit the viewport |
| Drop zone | Large dashed target; works by drag, click or keyboard |
| Transcription | The decoded text with a plain two-line initial (`initial-letter`, with a float fallback) |
| Toast | A polite live region, instead of `alert()` |

## Engineering rules the design depends on

- **No inline script or style.** CSS, JS, fonts and the favicon are first-party files, so
  `Content-Security-Policy: default-src 'self'` applies. The page talks to no third party, which
  matters for an app that handles passphrases.
- **Progressive enhancement.** Without JS, every form works: both modes, decoding, and the
  read-it-back form. JS adds the mode switch, counter, reveal, exports, drag and drop, and
  the animation.
- **Exports stay decodable.** Display styling is CSS-only, and the animation's inline styles
  are stripped before Download SVG, PNG or Copy. The file is the same black-on-white SVG the
  decoder reads.
- **Accessible by default.** Real labels, a native radio group (arrow keys work), visible
  focus, a skip link, `aria-live` feedback, reduced motion respected, and no horizontal scroll at
  390 px. axe-core reports no WCAG 2.1 AA violations on any page, in either theme.
- **No caching of secrets.** `POST` responses are sent with `Cache-Control: no-store`.

## Screens

| Inscribe (secret selected) | Plate (game) | Plate (dark) |
|---|---|---|
| ![](web-ui-inscribe.png) | ![](web-ui-plate.png) | ![](web-ui-dark.png) |
