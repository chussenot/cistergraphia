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
4. **Every sign is pressed by hand.** Signs are wedges, as a stylus leaves them in clay: a
   notched head where it bites, a tail that thins as it lifts, pressed left to right and
   top-down like a cuneiform tablet, with a slight unevenness of the hand. One look
   everywhere: plates, the key, the preview, the tables, Lectio, the mark and the favicon.
   The hand is seeded, so nothing changes between visits: on a plate by each sign's place,
   on the page by each stroke, so a stroke looks the same in every sign that has it and a
   morphing sign keeps the strokes it shares. Small signs get optical weight (`--weight`, a
   stroke the colour of the fill) so they stay legible; so do large plates (`--plate-weight`,
   by grid size), whose strokes would otherwise be hairlines at screen size.
5. **Three materials, three roles.** The plate is clay: a tablet of pale fired clay, the
   signs pressed into it and inked, one rectangle with a rim, chipped where it is worn,
   its fragments the same clay with worn edges. The grille is parchment: a pierced sheet
   laid over the plate, lighter than it, showing the plate through its holes. Everything
   else is paper, the library's own: the leaves, the inputs, the tiles of the desk and the
   bench, the board a broken plate is laid out on. A new surface is one of the three or it
   does not belong. The file stays black on white for the decoder; the page gives the
   plate its material with CSS alone.

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
| `--rule` | `#d9cdb6` | `#3b352d` | ruling lines (decorative only), the grille's edge | |
| `--clay` | `#e4d8c1` | `#3a3229` | the plate and its fragments | ink on clay 9 : 1 |
| `--clay-edge` | `#c4b08c` | `#5a4b3b` | the plate's rim, the hatch of a break | |
| `--sheet` | `#f7f2e8` | `#26221e` | the grille laid on a plate | |
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
| Choices (`.choice`, `.segment`) | What is made comes first, above the message: **Mode** (Game, Secret; red and blue initials) and **Layout** (six ways: Phaistos, Rongorongo, Leap, Furrows, Unwinding, Grille, each a small figure of its reading order over its name, `.segments--ways`: two rows of three at every width) as segmented controls over native radios, one above the other. Each has one reserved line of description; the notes swap in place. The key's "Order of reading" shows the chosen path; hollow points mark signs written upside down, and the grille's figure letters each cell with the turn that reads it. Below the message, **The reader's puzzle** (`.puzzle`), one disclosure whose summary is two fixed lines, what it is and what it holds ("Intact, shared tablet, path shown"; in secret mode "None: a sealed plate is not a puzzle"): shut on the plain plate, so a first plate is a message and a button; open when any of it is chosen or refused. Within it, **Condition** first, then **Tablet** (Shared, Its own), two segments with one reserved note: a plate with its own tablet has the values dealt out again, its reader builds the tablet in the notebook and the scribe confirms three entries at a time; Its own is greyed, with its reason in the note, on a sealed plate, under a grille and on a damaged one, and on a message under six words the note says the plate is close to guessing. Its own with Path withheld is the expert plate, and the note says so: two things to find, in order, the way, then the tablet. Then **Path** (Shown, Withheld), two segments with one reserved note: a pathless plate says nothing of where it begins, and its reader finds the way among the five; Withheld is greyed, with its reason in the note, on a sealed plate, under a grille and on a broken one (the board rejoins along the snail); a worn plate can be pathless, and its bench finds the way. **Condition** is the difficulty ladder (`.segments--ladder`): one segmented control, four rungs, Intact, Worn, Broken, Ruined, each a complete design, with one reserved note describing the rung chosen. A rung the layout does not allow (Broken and Ruined follow the snail) is greyed, and choosing it puts the reason in the note instead of an error after sending; in secret mode the rungs past Intact are greyed and the note says why (a sealed plate that loses a stroke never opens again). Tally signs are the library's and the CLI's, not the form's |
| Mode cards (`.mode`, About) | Native radios styled as two index cards; the first letter is a red or blue initial |
| Fields | Labels in small capitals; vellum-filled inputs; a focus ring in the mode colour |
| Buttons | Primary uses the mode colour; secondary is outlined; quiet is link-like; all are at least 48 px tall |
| Plate (`.plate-frame`) | A tablet of clay (`--clay`, a `--clay-edge` rim: the file's white ground, recoloured by CSS) on a paper mount (the double frame), scaled to fit the viewport. The signs pressed in wedges (`Cistergraphia::Stylus`: head 12, head length 14, tail 6, variation 6, in glyph units) in ink; from 7 signs a side they get optical weight (`.plate--medium`, 1.5 units; `.plate--large` from 10, 3 units) so that a large plate's strokes stay strokes. A lacuna is a chip: the pale body (`--paper`) under a hatch in the rim's colour. A broken plate's file is the tray, not a plate: its ground stays transparent and the fragments (`.sherd`) carry the clay |
| Drop zone | Large dashed target; works by drag, click or keyboard |
| Transcription | The decoded text with a plain two-line initial (`initial-letter`, with a float fallback). Read with the abbot's key, the novice's message follows under its own heading, in a quieter ink (`.transcription--second`). A weathered plate's text is an edition in the Leiden conventions: restorations `[r]` in rubric (`.leiden-restored`), doubts `[b/l]` dotted under (`.leiden-doubt`); the reveal keeps each letter's class |
| Toast | A polite live region, instead of `alert()` |
| Live preview (`.preview`) | Under the message, a strip of fixed height: each letter as one sign while typing, before the split and the layout. It scrolls sideways and follows the caret. Its three states (empty, signs, sealed) share one cell, so it never changes size |
| Passphrase, grille key (`.slot`) | Below the message, unfolded by CSS (`:has`): the grille key and the novice's message when Grille is chosen (both optional: a grille already shared, empty draws a new one; a second message for a second reader), the passphrase in secret mode. Only the button below them moves, over `--dur-mode` |
| Grille (`.grille-sheet`) | The plate's stencil (`Cistergraphia::SVG.stencil`, the same file as Download the stencil) laid exactly over the plate, as a parchment lighter than the clay (`--sheet`, edged in `--rule`), the plate showing through its holes; its N turns with it, and on screen the N and the key grow with the plate's size class (the printed stencil keeps the file's sizes). Grille plates have square cells (170 × 170, the sign centred) so that a quarter turn lands on the grid again. A plate with two readers carries two stencils, the abbot's and the novice's, which share no hole; a segmented control (`.grille-choice`) picks the one laid |
| Playground (About) | Any number from 0 to 9,999 drawn as a sign, with its reading ("1 thousand · 0 hundreds · …") and preset years |
| Index of dates (About) | A timeline whose exact years are written as signs; centuries get an em dash |
| Tablet (About) | The 27 letters as index cards: sign, letter in the mode colour, value |

## Voice and lexicon

The frame that holds the three worlds the site draws on (the Cistercian abbey, the archaeology of
undeciphered writing, the cipher register): **Cistergraphia is an abbey library that keeps the
world's lost scripts. The leaf is the catalogue, the plate is the object, the scriptorium is where
readers work.** Every surface belongs to one of the three rooms; a feature that fits none is a
fourth voice, and is declined.

| Room | What is in it |
|---|---|
| The catalogue | The leaves: Inscribe, Read, About, the Erratum. Index headings, folio marks, the lede in italic. It describes; it does not perform |
| The collection | The plates: clay pressed by a stylus, sometimes worn, broken or ruined; the grille cut from parchment; the tablet of values. Objects have conditions, layouts and keys |
| The scriptorium | Where the reader works: the desk, the bench, the board; Lectio; the ranks from novice to abbot; the record of plates read; on a pathless plate, the way to find and the notebook of ways tried; on a plate with a tablet of its own, the notebook of sums and the scribe who confirms it; on the expert plate (pathless, with a tablet of its own), the way first, on sums alone, then the notebook. Its verbs are manual: read, press, lay, turn, restore |

**Voice.** A careful epigrapher writing a catalogue entry: declarative, exact, unhurried, with a
dry wit that never winks ("Without it, the plate is an anagram of itself").

- Sentences state; they do not sell. No exclamation marks, no "you can", no "simply".
- The colon is the house punctuation: a claim, a colon, its consequence. Semicolons on About
  only; em-dashes never.
- Mistakes are shown in rubric and left to the reader ("Neither sign reads that. Look again."),
  never corrected, never named "wrong".
- Progress is a count a scribe would keep ("7 of 32 restored", "2 plates read"): never a score,
  a timer or a streak outside Lectio's own "in a row".
- Technical words stay at the doors: SVG, PNG and AES-256-GCM appear where a file enters or
  leaves (the download row, the Read form, the seal's note), never in a lede, a heading or a
  puzzle line.
- Latin and the monks' words earn their place by having no plain equivalent (Lectio,
  scriptorium, folio, erratum, lacuna) and are never explained twice.
- Red means one thing at a time: wet ink, a restoration, or "look here".

**Lexicon.** One word for each thing, in pages, scripts, docs and refusals alike.

| We say | For | Never |
|---|---|---|
| plate | the object a message becomes | image, "a Cistergraphia" (the site's name is not a noun), file except at the doors |
| sign; stroke, corner, stem | one numeral and its parts | glyph, symbol (code only); quadrant in copy |
| pair, balance, the tablet | two signs summing to a letter; the table of values | checksum, lookup |
| intact, worn, broken, ruined | the ladder's four conditions | weathered, damaged (except as the family word on About) |
| lacuna, restore, edition | a lost stroke position, putting it back, the Leiden-bracketed result | gap, repair, fix |
| fragment, sherd, rejoin, whole again | the pieces of a broken plate and the act | piece in copy, reassemble, solve |
| inscribe | what the scribe does | generate, encode, create |
| read | what a person does to a plate | decode (a person never decodes) |
| decipher, the decoder | what the machine does, and its name | decode this plate, decoded message, solver |
| seal, sealed, passphrase | secret mode and its key | encrypt, password, lock |
| key, grille, stencil | the grille's secret, the parchment, the printed cut-out | code, mask |
| the snail, the turning tablet, the leap, the furrows, the unwinding, the turning parchment | the six layouts, by their movement | spiral mode, boustrophedon outside About, knight's move, Zodiac mode |
| scribe, reader | the two people in every exchange | user, player, sender |
| the desk, the bench, the board | the scriptorium's furniture | mode, puzzle view, game screen |
| a pathless plate | a plate whose reader must find the way (Path withheld on the form) | Zodiac mode, hidden layout, blind mode |
| the expert plate | a pathless plate with a tablet of its own: the way, then the tablet (said on the form, and in the record as "pathless with its own tablet") | hard mode, expert mode, level |
| the tablet; a plate with a tablet of its own; Its own | the mapping of values to characters, and a plate whose reader must build it (Tablet on the form) | key (the grille's word), alphabet, cipher table, substitution, unknown tablet in copy |
| Which way does it run?; the notebook | the desk's or the bench's question on a pathless plate, and its line of the ways tried: what each gave, where it broke; on a plate with a tablet of its own, the notebook is the table of sums | select transposition, history, log, glossary, legend |
| in pencil, in ink; Ask the scribe; Nothing holds yet | an entry written and one the scribe confirmed; the confirmation, three at a time; its answer when fewer than three hold | guess, validated, locked, correct; Check, Submit; Wrong, Incorrect, 2 of 3 |
| Lectio; novice, monk, prior, abbot | the reading exercise and the ranks it and the desk award | level, XP, badge |
| your scriptorium | the record of plates read, kept in the browser | history, stats, profile |
| transcription | what the decoder hands back | output, result, decoded message |
| Hear the hand, Silence | the one control for sound, and its pressed state | sound on, mute, audio, volume, SFX |
| the bite, the lift, the sherd, the join, the turn, the parchment, the bell | the seven sounds, named by the material that makes them | click, whoosh, snap, chime, ding, success sound |

**The codex.** The folios follow the order the story is read: Inscribe `1r`, the plate `1v`,
Read `2r`, the scriptorium `2v`, the transcription `3r`, About `4r`. The Erratum has no folio: a
slip of paper in the book.

## Interaction: "the silence of the monks"

Motion and interaction follow four rules. Anything that breaks one does not ship.

1. **Motion only when it carries meaning.** Nothing loops, nothing moves for show; every
   animation either teaches how the cipher works or answers something you did.
2. **One vocabulary: ink.** A wedge is *pressed* (the stylus bites at its head and runs to
   its tip, wet in the mode's colour, then the ink dries to iron-gall) or *lifted* (it fades). A sign changes by *morphing*:
   shared strokes stay, only the difference is pressed. Never a pop, a bounce or a shake.
3. **The game is reading.** The page invites you to read the signs yourself, at your own
   pace: no timers, no confetti, and no sound unless the reader asks to hear the hand (see
   Sound, below). Mistakes are shown, not punished.
4. **Silence by default.** Under `prefers-reduced-motion`, everything is instant and the
   same information is still there; nothing sounds until "Hear the hand" is pressed.

**Red means one thing at a time.** Wet ink and "look here" share the mode colour, so lighting
a corner first dries any wet ink: the only red left is what you should look at.

### Motion tokens

| Token | Value | What it is |
|---|---|---|
| `--dur-stroke` | 260 ms | one stroke of the pen |
| `--dur-dry` | 1100 ms | wet rubric ink drying to iron-gall |
| `--dur-lift` | 260 ms | a stroke lifted away |
| `--dur-mode` | 700 ms | the page changing ink, red ↔ blue (a registered `@property`) |
| `--dur-turn` | 900 ms | a Rongorongo plate turned half round, or the grille a quarter |
| stroke gap | 70 ms | between two strokes of one sign, like a scribe's hand |
| `--ease-ink` | `cubic-bezier(0.3, 0.6, 0.2, 1)` | quick to start, slow to settle |

![The plate being pressed: dry signs in ink, the wet rubric front coiling inward](web-ui-ink.png)

### Catalogue

| Where | Interaction | What it teaches |
|---|---|---|
| Whole page | Choosing a mode crossfades the page's ink red ↔ blue | The mode you are in |
| Inscribe preview | Each new letter's sign is pressed as you type, stroke by stroke; existing signs stay; the strip glides sideways to keep the caret's sign in view | One letter, one sign |
| How to read a sign | The four corners are dials (click, or arrow keys up/down); only the changed strokes are rewritten; hovering a corner lights its strokes; some years name themselves (1098, 1115, 1153, this year) | How the places combine |
| Inscribe | Choosing Secret unfolds the passphrase below the message | What sealing needs |
| Inscribe key | Choosing a layout re-inks the "Order of reading" path, in place | Where the plate starts and how it runs |
| Plate | Pressed stroke by stroke in reading order, each wedge running from its head to its tip, the wet rubric front visibly coiling inward (or climbing the rows). Past 1,200 wedges (about 85 letters in a game) the signs are too small to see a stroke run: the plate is there at once and only its ink dries along the path, which keeps 60 fps | The reading order |
| Plate | Walk it: point at a sign, or focus the plate and use the arrow keys / Home / End; a soft field glides along the path; "Sign 12 of 36 · 4127", with "upside down: turn the plate to read it" on turned signs | Reading the numerals, the first step of solving a game plate |
| Plate (zoom, from 7 × 7) | **− ×2 + Fit** on the frame's corner: the frame keeps its size and becomes a window, the plate grows behind it (×1.5, ×2, ×3, ×4: its width and height, never a transform, so the walk, the bench and the grille read its box as ever) and scrolls, or is dragged with the mouse. The point under the pointer, or the window's centre, stays put; the sign the walk is on is kept in view, from the desk and the bench too. Ctrl or ⌘ with the wheel (a trackpad's pinch) zooms; + − 0 on the focused plate. A new page width fits it again; a small plate has no zoom, its signs are large enough | A plate of 500 letters is 23 × 23 signs: on a phone each is 13 pixels wide |
| Plate (Rongorongo) | **Turn the plate**: the plate rotates half round, as the readers of Rapa Nui turned their tablets; the turned rows now read upright, and walking follows | Why every other row is upside down |
| Plate (Grille) | **Lay the grille**, then **Turn it to E, S, W**: the parchment turns a quarter at a time and the signs under its holes are lit, "The grille at E: signs 26 to 50 of 100, row by row"; walking says which turn reads a sign. **Download the stencil** to print and cut, **Copy the key**. With two readers: **Abbot / Novice** picks the grille, each lights only its own signs; both stencils download, each key copies | How a turning grille reads every cell once, and that without it the plate is an anagram; with two readers, that one plate holds two messages for two keys |
| Transcription | The decoded message appears letter by letter after its initial | The payoff of decoding |
| Plate (weathered) | The lacunae are chips in the clay, hatched, under the wedges; walking a worn sign says "worn: part of this sign is lost", never its value. **Ask the decoder** prints the edition | That a lost stroke is recovered by balancing its pair, and where the words must decide |
| The reading room (`.room`, the reader's page) | On a wide screen (70rem and up) the plate and the work side by side: the plate on the left, held in view (sticky, when the screen is tall enough to hold it), the desk, the bench or the notebook on the right. What is read is never a scroll away from where it is read: the walk lights the pair on the plate while its values are typed. Narrower, the plate above the work, as before. The board keeps its own figure (the board and the tray) | The scriptorium's carrel: the exemplar propped up beside the copy |
| Restoration bench (`.bench`) | Under a weathered plate: choose a lacuna on the plate (its whole cell when the sign has one lacuna, its corner when it has several) or step with ‹ ›; a line counts how many are restored ("7 of 32 restored"); ten digits drawn in the lacuna's place, those the surviving strokes rule out disabled; press one and its strokes are pressed in rubric where the surface is lost. The pair is weighed in two short lines ("0045 + 000? = ?", "Press a digit to balance it.") and the edition so far updates in Leiden style. A sign wholly lost is four lacunae, one per place. With tally signs, a third line checks the lacuna's row and column in its place ("Tallies, tens: row ✓, column ?"). The page only knows what the file shows: it says whether things balance, never whether a restoration is right. On a pathless plate the bench asks first **Which way does it run?** with the five figures; a way laid puts the worn cells at their places along it, read upright or turned as it says, and the edition says at once what the way gives: letters, `[.]` where a lacuna waits, `[?]` where a pair is off the tablet whatever the lacunae held (measured: along a wrong way, 99.75 % of worn plates show one at once; for the rest the verdict says "No digit balances it"). The notebook under the bench keeps what each way gave, in short lines so that five fit three lines on a phone ("the snail: 7 off ✗ · the furrows: 3 of 16"); the digits pressed are kept per way | Restoration as the puzzle: the checksum narrows a lacuna, the words (or the tallies) settle it; on a pathless plate, the first letters legible along a way are the way |
| Plate (broken, `.plate--broken`) | The board, ruled in the leaf's colour, and the tray: two to four fragments of clay (`.sherd`), worn on every edge, lying slightly askew, some turned half round. The file has the tray below the board (a phone shows it so); on a wide screen the script lays it beside the board in a frame of fixed height, so the whole puzzle is in view at once and nothing on the page moves when it does. With the script a fragment is dragged, or picked (tap or Enter) and laid by choosing the cell for its top-left corner; a dashed ghost (`.ghost`) shows the cells it would land on, grey when it would hang over the edge; arrow keys move it a cell at a time, **T**, a double click or **Turn half round** turns it; everything snaps to the cells. The plate is not walked: it is in pieces | That shapes do not rejoin a plate, the sums do |
| Rejoining (`.rejoin`) | Under a broken plate: the tools, then one two-line status ("On the board: 2 of 3 fragments.", "Covered: 38 of 50 pairs balance.", "Whole again: every pair balances.") and, once whole, what it reads. A weathered broken plate shows its lacunae on the fragments; a worn sign is weighed by every digit its strokes allow, and whole again the plate reads as the decoder's edition ("It reads, restored: la[b/l]ora") and **Restore it** comes alive: it posts the file back (`rejoined=1`) and the bench opens on the plate drawn whole from its own fragments, each moved to its place, the ruined plate's last step and where it is won. No bench on a plate still in pieces. The page holds what each fragment shows, read upright and turned, never where it goes: it weighs the pairs along both reading paths only once the board is covered | The khipu rejoined by arithmetic, as a game |
| Tally signs (`.tally`) | One sign past each row and under each column, and the corner, in rubric past two ruled cords (`.cord`), like the higher cords of a khipu | That every row and column is summed, place by place |
| About · Lectio | Read the sign, type its number. Novice (units) → Monk (tens) → Prior (hundreds) → Abbot (thousands) every three in a row; a misread corner is lit (an empty corner is named as a zero) and you continue when ready; best run kept in the browser | Fluency in the signs |
| Read | A received file's sign is pressed | Your file arrived |
| The notebook (`.notebook`, under the desk of a plate with a tablet of its own) | At its head the text line, held at the top of the screen while the entries scroll, and Ask the scribe held at the bottom: a letter pencilled anywhere in the table is read in the text at once and asked from where it is. In a narrow notebook (a phone, or the reading room's column: a container query) one spelling per sum, one line per row. One entry per sum the plate's pairs make, the most seen first: the sum, how often it is seen, how it was spelled (three spellings on a wide screen, one on a phone, … for more), and a letter to write against it (the space is ␣). A letter written is in pencil: grey, slanted, in the desk's text line at once; a letter is one sum's, so writing it elsewhere moves it. **Ask the scribe** sends the pencilled entries and the file; the scribe (`POST /ask`, from the seed the file carries) answers only when three or more hold at once, and those go into ink, upright, for good; otherwise "Nothing holds yet", never how many. With fewer than three sums left out of ink, the last ones are confirmed together. A line counts "3 of 16 in ink · asked 2 times". Guided, every sum is in the notebook from the start; unaided, a sum enters it once its pair is read right at the desk, and the ranks are earned as at any desk. The page holds the sums, never the tablet; the notebook is kept in the browser by the plate's seed. "Every sum is in ink: the tablet is yours." is the win. On the expert plate the notebook is shut ("Shut until the way is found"), since its sums would tell the way: the desk reads along the way chosen on sums alone, a sum that is a value of no tablet breaks it, and three pairs that land open the notebook on every sum along it, built by the page from the row template; the other ways are then shut, and the way found is kept with the notebook. Its text line marks a pair that lands +, one that breaks ×, a null pair ø, one Latin mark per pair, so the line keeps its width | The Copiale's method as play: count, group by sum, find the space, recognise English; the rule of three settles what no dictionary can |
| Scriptorium record (`.record`) | One reserved line under Read's lede: "Your scriptorium: Prior · 7 plates read, 4 worn, 2 broken and 1 ruined." Counts by rung, kept in the browser (`localStorage`), nothing else: no times, no streaks, no scores on the plate. A plate won on the reader's page (read to the end, every pair balanced, whole again) adds one and says so in the same reserved line under its puzzle | A record of a scribe's and a reader's exchange, not a leaderboard |
| Reading desk (`.desk`, under an intact plate on Read) | The current pair shown large (two signs on vellum), two numbers to type, the sum and its letter on the tablet ("4127 + 873 = 5000: “e”"), in one row on a wide desk and, on a narrow one (a phone, or the reading room's column: a container query), set as a sum on paper, each sign beside its value, + and = in the margin, the letter beneath; the text so far growing in a line of dots. **Guided**: a tap on a sign, on the plate or on the desk, shows its value in its box; **Unaided**: a wrong value is marked in rubric and never corrected, the plate walk keeps the values to itself, and three right pairs in a row earn the Lectio's ranks, the same best kept in the browser. A null pair (an intact 9999) reads as nothing. The field on the plate follows the pair | Reading the numerals in context: the lowest rung, and the one most readers meet first |
| Read (a game plate, `play.erb`) | A game plate brought to Read opens as its puzzle, not its reading: the desk under an intact plate, the bench under a worn plate, the board under a broken one (then the bench, rejoined, under a ruined one), the same as the plate page's but built from the file alone (its surviving strokes, its fragments' edges), so the page cannot hold the answer. The file is redrawn from its plate elements only before it is shown. **Decipher it** below posts the same file back with `decipher=1` for the decoder's edition or rejoining; the plate page's **Read it back** carries the same field, since the scribe knows the answer. An intact plate is read at once; a sealed one is never a game | The reader's game: the plate arrives damaged, the one who receives it restores it |

Implementation: `public/js/ink.js` holds the vocabulary (`press`, `wet`, `dry`, `lift`, `morph`,
`glyph`). A wedge's drawing is read from its own outline (where the head bites, which way the
tail runs) and is a stretch along the stroke from there; drawing and drying are two animations
in turn, never at once, because animating shape and colour together on thousands of SVG paths
drops the frame rate several times over. `public/js/app.js` holds the interactions.
The plate's cells and geometry come from
`ViewHelpers#plate_cells_json` / `#plate_layout_json` (built from `Cistergraphia::Layout.path`, with
each sign's turned flag, and the cell's size), so walking the plate follows the real path.
Under a grille, a wedge's cell is read from where it bites, to light the signs under the holes. Turning is a class on
the frame, never on the SVG, and exports strip every class, style and the walking field: the
downloaded SVG is unchanged.

## Sound: the sounds of silence

The site is silent by default, and stays so until a reader presses **Hear the hand** in the
colophon (pressed: **Silence**; kept in the browser as `cistergraphia.sound`, off by default;
the press is also the gesture browsers require before a page may sound, so nothing is ever
autoplayed). What is then heard is only the hand at work, the motions the page already makes.
Nothing is heard that is not seen; no sound stands for a state; mistakes are silent (the
absence is the mark); nothing loops. One pitched sound, the bell, rings once when a plate is
complete, and the reader rings it. Everything is synthesised in `public/js/sound.js` with the
Web Audio API: no file, no request, nothing the CSP need allow. A bite is seeded by its
stroke, as its wedge is by `Cistergraphia::Stylus`, so the same stroke always sounds the same.

| Sound | What makes it | When | Length |
|---|---|---|---|
| The bite | The stylus biting clay at a stroke's head | A stroke pressed: the plate inked, the preview as you type, a digit on the bench, a pair read right at the desk | 4 to 8 ms |
| The lift | The stylus leaving the clay | A stroke lifted: a sign morphing, a digit taken back | 15 ms |
| The sherd | Clay set down on wood | A fragment laid on the board | 130 ms |
| The join | Two sherds meeting edge to edge | A fragment landing against one already placed | two bites, 12 ms apart |
| The turn | Clay slid half round on wood | A Rongorongo plate turned, a fragment turned | 400 ms, in the middle of `--dur-turn` |
| The parchment | A pierced sheet laid, dragged a quarter turn, lifted | The grille laid, turned to E, S, W, lifted | 150 ms, 400 ms turned |
| The bell | Bronze, struck once | A plate read to the end, every pair balanced, whole again, restored | 5 s, never cut, one at a time |

Silent on purpose: ink drying, the page changing ink, a misread or a pair that does not
balance, navigation, forms, downloads, the toast, Lectio's ranks, pointing and walking the plate.

**Where the hand is.** Pan follows the sign's column within ±0.6, brightness its row (a
low-pass from 6 kHz at the top row to 2.5 kHz at the bottom), so the snail is audible as it
coils inward. Bites are thinned to at most 25 a second: a long plate is a patter that follows
the drying front, never a hail. Peaks sit around −20 dBFS for the bite, −14 for the sherd and
the turn, −10 for the bell, through one soft limiter; no reverb but the bell's own decay; in
Vigils everything is 6 dB quieter. The context sleeps after 30 s without a sound.

**One clock.** Sound is bound to the hand's timing (`ink:press` carries the wedge and its
delay), not to the data. Under `prefers-reduced-motion` the hand is instant, so a sign set
down whole makes one bite (the thinning), and the turn and the parchment still sound in full.
The two preferences are independent.

**Hooks.** `ink.js` tells `ink:press` (also for the wet strokes of a long plate, the pressing
the drawing skipped) and `ink:lift`; `app.js` tells `hand:turn`, `hand:parchment` (lay, turn,
lift), `hand:sherd` (with `joined`), `hand:bite`, `hand:lift` and `hand:bell` from the places
that toggle `is-turned`, `is-laid`, `is-whole` and call `recordWin`. The pure part (what a
sound is, from what made it) is tested in Node: `bundle exec rake test:sound`.

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
- **Exports stay decodable.** A plate file holds its pressed wedges (one path per stroke) and
  every stroke as a hidden `<line>`: the decoder reads the lines, the wedges are only the look,
  and plates drawn before the wedges still read. Display styling is CSS-only, and the
  animation's inline styles are stripped before Download SVG, PNG or Copy.
- **Accessible by default.** Real labels, a native radio group (arrow keys work), visible
  focus, a skip link, `aria-live` feedback, reduced motion respected, and no horizontal scroll at
  390 px. axe-core reports no WCAG 2.1 AA violations on any page, in either theme.
- **No caching of secrets.** `POST` responses are sent with `Cache-Control: no-store`.
- **One copy of the cipher, and of the hand.** The live preview and the playground draw from
  a JSON glyph table the server embeds (`ViewHelpers#glyph_table_json`, built from
  `Cistergraphia::Glyphs`), with every stroke's wedge already pressed (`Cistergraphia::Stylus.press`).
  A test checks that it equals the library's, so the browser can never drift from the encoder.

## Social preview

![Social preview](../public/og.png)

`bundle exec rake og:image` renders `web/og/card.html.erb` with the app's fonts and a real
plate ("ora et labora", fixed seed, so the image is reproducible and decodable), through
headless Chromium:

- `public/og.png` (1200×630): `og:image` and `twitter:card` on every page
- `docs/social-preview.png` (1280×640): to upload in the repository's GitHub settings
  (Settings → General → Social preview)

## Screens

| Inscribe (secret selected) | Plate (game) | Plate (Rongorongo) | Plate (grille, at E) | Plate (dark) | About |
|---|---|---|---|---|
| ![](web-ui-inscribe.png) | ![](web-ui-plate.png) | ![](web-ui-rongorongo.png) | ![](web-ui-grille.png) | ![](web-ui-dark.png) | ![](web-ui-about.png) |
