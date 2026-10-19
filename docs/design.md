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
3. **Motion shows the reading order.** On the result page each sign is pressed in reading
   order, so the path (the snail, or the turning rows) is visible the first time you see a
   plate. It is off under `prefers-reduced-motion`.
4. **A plate is pressed by hand.** Its signs are wedges, as a stylus leaves them in clay: a
   notched head where it bites, a tail that thins as it lifts, pressed left to right and
   top-down like a cuneiform tablet, with a slight unevenness of the hand. The hand is seeded,
   so a plate always looks the same. Signs elsewhere (key, preview, Lectio) stay drawn in line,
   where they are taught.

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
| Choices (`.choice`, `.segment`) | First on the form, above the message: **Mode** (Game, Secret; red and blue initials) and **Layout** (Phaistos, Rongorongo) as segmented controls over native radios. Each has one reserved line of description; the notes swap in place. Side by side when the form is wide enough (container query), stacked on phones. The key's "Order of reading" shows the chosen path; hollow points mark signs written upside down |
| Mode cards (`.mode`, About) | Native radios styled as two index cards; the first letter is a red or blue initial |
| Fields | Labels in small capitals; vellum-filled inputs; a focus ring in the mode colour |
| Buttons | Primary uses the mode colour; secondary is outlined; quiet is link-like; all are at least 48 px tall |
| Plate (`.plate-frame`) | The signs pressed in wedges (`Cistergraphia::Stylus`: head 12, head length 14, tail 6, variation 6, in glyph units), in ink colours (CSS only), inside a double frame, scaled to fit the viewport |
| Drop zone | Large dashed target; works by drag, click or keyboard |
| Transcription | The decoded text with a plain two-line initial (`initial-letter`, with a float fallback) |
| Toast | A polite live region, instead of `alert()` |
| Live preview (`.preview`) | Under the message, a strip of fixed height: each letter as one sign while typing, before the split and the layout. It scrolls sideways and follows the caret. Its three states (empty, signs, sealed) share one cell, so it never changes size |
| Passphrase (`.secret-slot`) | Below the message, unfolded by CSS (`:has`) in secret mode: only the button below it moves, over `--dur-mode` |
| Playground (About) | Any number from 0 to 9,999 drawn as a sign, with its reading ("1 thousand · 0 hundreds · …") and preset years |
| Index of dates (About) | A timeline whose exact years are written as signs; centuries get an em dash |
| Tablet (About) | The 27 letters as index cards: sign, letter in the mode colour, value |

## Interaction: "the silence of the monks"

Motion and interaction follow four rules. Anything that breaks one does not ship.

1. **Motion only when it carries meaning.** Nothing loops, nothing moves for show; every
   animation either teaches how the cipher works or answers something you did.
2. **One vocabulary: ink.** A stroke is *inked* (drawn end to end, wet in the mode's colour,
   then drying to iron-gall ink) or *lifted* (it fades); a plate's wedges are *pressed*
   (they appear wet, then dry). A sign changes by *morphing*:
   shared strokes stay, only the difference is written. Never a pop, a bounce or a shake.
3. **The game is reading.** The page invites you to read the signs yourself, at your own
   pace: no timers, no sound, no confetti. Mistakes are shown, not punished.
4. **Silence by default.** Under `prefers-reduced-motion`, everything is instant and the
   same information is still there.

**Red means one thing at a time.** Wet ink and "look here" share the mode colour, so lighting
a corner first dries any wet ink: the only red left is what you should look at.

### Motion tokens

| Token | Value | What it is |
|---|---|---|
| `--dur-stroke` | 260 ms | one stroke of the pen |
| `--dur-dry` | 1100 ms | wet rubric ink drying to iron-gall |
| `--dur-lift` | 260 ms | a stroke lifted away |
| `--dur-mode` | 700 ms | the page changing ink, red ↔ blue (a registered `@property`) |
| `--dur-turn` | 900 ms | a Rongorongo plate turned half round |
| stroke gap | 70 ms | between two strokes of one sign, like a scribe's hand |
| `--ease-ink` | `cubic-bezier(0.3, 0.6, 0.2, 1)` | quick to start, slow to settle |

![The plate being pressed: dry signs in ink, the wet rubric front coiling inward](web-ui-ink.png)

### Catalogue

| Where | Interaction | What it teaches |
|---|---|---|
| Whole page | Choosing a mode crossfades the page's ink red ↔ blue | The mode you are in |
| Inscribe preview | Each new letter's sign is inked as you type; existing signs stay; the strip glides sideways to keep the caret's sign in view | One letter, one sign |
| How to read a sign | The four corners are dials (click, or arrow keys up/down); only the changed strokes are rewritten; hovering a corner lights its strokes; some years name themselves (1098, 1115, 1153, this year) | How the places combine |
| Inscribe | Choosing Secret unfolds the passphrase below the message | What sealing needs |
| Inscribe key | Choosing a layout re-inks the "Order of reading" path, in place | Where the plate starts and how it runs |
| Plate | Pressed sign by sign in reading order, the wet rubric front visibly coiling inward (or climbing the rows) | The reading order |
| Plate | Walk it: point at a sign, or focus the plate and use the arrow keys / Home / End; a soft field glides along the path; "Sign 12 of 36 · 4127", with "upside down: turn the plate to read it" on turned signs | Reading the numerals, the first step of solving a game plate |
| Plate (Rongorongo) | **Turn the plate**: the plate rotates half round, as the readers of Rapa Nui turned their tablets; the turned rows now read upright, and walking follows | Why every other row is upside down |
| Transcription | The decoded message appears letter by letter after its initial | The payoff of decoding |
| About · Lectio | Read the sign, type its number. Novice (units) → Monk (tens) → Prior (hundreds) → Abbot (thousands) every three in a row; a misread corner is lit (an empty corner is named as a zero) and you continue when ready; best run kept in the browser | Fluency in the signs |
| Read | A received file's sign is inked | Your file arrived |

Implementation: `public/js/ink.js` holds the vocabulary (`inkIn`, `dry`, `lift`, `morph`,
`glyph`), `public/js/app.js` the interactions. The plate's cells and geometry come from
`ViewHelpers#plate_cells_json` / `#plate_layout_json` (built from `Cistergraphia::SVG.path`, with
each sign's turned flag), so walking the plate follows the real path. Turning is a class on
the frame, never on the SVG, and exports strip every class, style and the walking field: the
downloaded SVG is unchanged.

## Engineering rules the design depends on

- **Nothing moves under you.** Typing, choosing, walking or turning a plate never changes
  where anything above it sits, and the script arriving moves nothing: what JS changes has
  its space from the first paint (stacked cells for swapped text, `visibility` for controls
  JS enables, server-drawn first states, reserved lines for the longest text). The one
  deliberate movement is the passphrase unfolding in secret mode, which moves only the
  button below it, animated. `bundle exec rake ui:stability` checks it, and CI runs it on
  every push: each reader action on every page, at 320, 390, 1024 and 1280 px, and each
  page with JS on vs off. A new interaction gets a step in `test/ui/stability.js`; a new
  deliberate movement names its anchor there, above which nothing may move.

- **No inline script or style.** CSS, JS, fonts and the favicon are first-party files, so
  `Content-Security-Policy: default-src 'self'` applies. The page talks to no third party, which
  matters for an app that handles passphrases.
- **Progressive enhancement.** Without JS, every form works: both modes, decoding, and the
  read-it-back form. JS adds the mode switch, counter, reveal, exports, drag and drop, and
  the animation.
- **Exports stay decodable.** A plate file holds its pressed wedges (one path per sign) and
  every stroke as a hidden `<line>`: the decoder reads the lines, the wedges are only the look,
  and plates drawn before the wedges still read. Display styling is CSS-only, and the
  animation's inline styles are stripped before Download SVG, PNG or Copy.
- **Accessible by default.** Real labels, a native radio group (arrow keys work), visible
  focus, a skip link, `aria-live` feedback, reduced motion respected, and no horizontal scroll at
  390 px. axe-core reports no WCAG 2.1 AA violations on any page, in either theme.
- **No caching of secrets.** `POST` responses are sent with `Cache-Control: no-store`.
- **One copy of the cipher.** The live preview and the playground draw from a JSON glyph
  table the server embeds (`ViewHelpers#glyph_table_json`, built from `Cistergraphia::Glyphs`).
  A test checks that it equals the library's table, so the browser can never drift from the
  encoder.

## Social preview

![Social preview](../public/og.png)

`bundle exec rake og:image` renders `web/og/card.html.erb` with the app's fonts and a real
plate ("ora et labora", fixed seed, so the image is reproducible and decodable), through
headless Chromium:

- `public/og.png` (1200×630): `og:image` and `twitter:card` on every page
- `docs/social-preview.png` (1280×640): to upload in the repository's GitHub settings
  (Settings → General → Social preview)

## Screens

| Inscribe (secret selected) | Plate (game) | Plate (Rongorongo) | Plate (dark) | About |
|---|---|---|---|---|
| ![](web-ui-inscribe.png) | ![](web-ui-plate.png) | ![](web-ui-rongorongo.png) | ![](web-ui-dark.png) | ![](web-ui-about.png) |
