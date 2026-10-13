# Blind LLM attack: the attacker's report

Final report of the attacking agent, formatting lightly adjusted, content unchanged (model output, kept as evidence; see
[PROTOCOL.md](PROTOCOL.md) for the setup). Run time ≈ 2.5 minutes, 9 tool calls.

---

All 10 plaintexts recovered completely (no uncertain characters). I only read the `blind` folder, used no network, and kept scripts in /tmp/claude-0/attack-work.

## 1. Recovered plaintexts
- msg01: BURN THIS MESSAGE
- msg02: DO NOT TRUST THE CELLARER
- msg03: MEET ME AT THE OLD ABBEY AFTER VESPERS
- msg04: BROTHER ANSELM SUSPECTS NOTHING
- msg05: THE LIBRARY KEY IS HIDDEN UNDER THE THIRD STONE
- msg06: WE FOUND THE LOST GOSPEL IN THE SCRIPTORIUM WALL
- msg07: QUIET NOW THE PRIOR IS LISTENING
- msg08: LE MANUSCRIT EST DANS LA CRYPTE (French)
- msg09: THE ABBOT WILL TRAVEL NORTH AT DAWN WITH TWO MONKS AND A MULE
- msg10: SEND THE COPY TO CLAIRVAUX BEFORE WINTER

## 2. Method
**a) Symbols.** Each SVG contains only black `<line>` elements on a square grid (6×6, 8×8, 10×10 or 12×12 cells, 120 px horizontal / 170 px vertical spacing). Every cell has a 150 px vertical stem plus 50 px strokes in four corner zones. That is the medieval Cistercian numeral system: top-right = units, top-left = tens, bottom-right = hundreds, bottom-left = thousands, with the standard digit shapes (1 top bar, 2 inner bar, 3/4 diagonals, 6 outer vertical, 5=1+4, 7=1+6, 8=2+6, 9=1+2+6). I wrote a parser that normalises each stroke to its zone and decodes every cell to a number 0–9999. Every stroke matched a valid digit shape: no stray or noise strokes at the geometry level.

**b) Reading order.** Clockwise spiral from the top-left, inward. Clue: adjacent values summed to round numbers (e.g. 831+2169=3000, 4127+873=5000). The pairing kept working when reading continued down the right column and back along the bottom row. One pair summing to 9000 straddles a spiral corner (3692 at the end of the right column + 5308 at the start of the bottom row), which confirmed the spiral. With spiral order, every consecutive pair (cells 1–2, 3–4, …) in every message gives a round sum, except pairs whose second cell is 9999.

**c) Two-cell split.** Each plaintext character is a single value V, written as two random shares a+b=V (a zero share is allowed, e.g. 0+160).

**d) Nulls and padding.** Pairs (random, 9999) are nulls. They are inserted at random places and also fill the square (e.g. msg01: 17 characters + 1 null = 36 cells). Deleting them gives clean text.

**e) Character mapping.**
- A–I = 10–90
- K–P = 110–160, Q = 180, R = 190
- S–Z = 1000–8000
- space = 9000

Found via: 9000 was the most frequent sum (60 times), so it is the space. The repeated sequence 2000 80 50 9000 gave "THE ", which suggested the alphanumeric scheme (A=1…I=9, then tens, then hundreds, ×10). My first guess put J at 110 and was off by one in the K–R range. Words like "KIBRARY" and "MNT" exposed this, and I fixed it to K=110…P=160, Q=180, R=190.

## 3. Effort
- Glyph parsing: 1 attempt (a few minutes); the system is recognisable on sight.
- Reading order: 1 attempt. Guessed the spiral from the grid shape and confirmed it with the corner-straddling sums.
- Finding the additive two-share split: about 2 looks at the numbers. This was the key insight and the hardest step, though still minor.
- Nulls: obvious immediately from the constant 9999.
- Mapping: 2 iterations, the first with the K–R offset error.
- About 6 script runs in total.

Unresolved because unused: J never appears (100 never occurs, so J = 100 is a guess). The sum 170 never appears either; the A–I and S–Z ranges fit the pattern exactly, so 170 looks like an unused slot.

## 4. Strength
Very weak: it is security by obscurity, with no key. Once the glyphs are read as Cistercian numerals, it reduces to a fixed one-letter-to-one-value substitution with repeating pair sums per letter.
- **The random split adds no secrecy.** Summing two adjacent cells recovers the value, and the sums are round multiples of 10 or 1000, which marks the pair boundaries.
- **The nulls are labelled.** They always end in the constant 9999, so they are trivially removable.
- **The spiral is a guessable route with no key.** It follows from the square grid and is confirmed by the sums.
- **The value table is the alphabet in order.** It follows the A=1, J=10, S=100 numeric-letter pattern, so it falls to frequency analysis and repeated words ("THE ", the space) in minutes.
- **No key or per-message variation.** The same mapping is used in all 10 messages, so they can be attacked together.

It would be stronger with a keyed, shuffled value table, nulls that look like real shares (pairs whose sums look like real letters), a keyed route through the grid, and sums taken modulo 10000 so that shares don't show their boundaries.
