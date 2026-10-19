# Blind LLM attack on Grille plates: the attacker's report

Final report of the attacking agent, content unchanged (model output, kept as evidence; see
[PROTOCOL.md](PROTOCOL.md) for the setup and [ANSWERS.md](ANSWERS.md) for the true plaintexts).
Run time ≈ 26 minutes, 81 tool calls. Its scripts are in [`agent-scripts/`](agent-scripts/).

---

## Result: all 10 messages recovered

I used only the files in `blind-grille`. My scripts are in /tmp/claude-0/attack-work-grille. The main ones are parse.py, match.py, uf.py, v4.py, ils.py and deep.py.

### 1. Plaintexts

The start point is my reading. The grille turns the message into a loop, so the cipher alone does not show where it begins.

| File | Plaintext | Confidence |
|---|---|---|
| msg01 | send the new psalter to the priory of clairvaux before easter | very high (every letter decoded) |
| msg02 | the cellarer counted forty barrels of wine and six of oil | high. "six of oil" decodes cleanly. Two leftover cells (369, 77) sit next to it, so a short word may be missing, but they don't form a letter. |
| msg03 | do not open the north door after vespers | very high |
| msg04 | les moines du prieure attendent la lettre du pape | very high (French) |
| msg05 | brother anselm has hidden the charter behind the altar | high. Every letter appears across the best solutions, but no single run was perfectly clean. |
| msg06 | bring two candles and the small key to the library at midnight | very high |
| msg07 | the bishop arrives on thursday with twelve horsemen | high. Assembled from the best runs: "r.iv.es. on. th.u.rs.day. wit.h twel..ve .h.or..s.emen.the bi.sh.op .ar." |
| msg08 | our flock of sheep was lost in the storm near the mill | very high |
| msg09 | le pain manque au refectoire depuis trois jours | very high (French) |
| msg10 | pray for the soul of the old gardener who died this winter | very high |

### 2. How the scheme works and how I broke it

1. **SVG structure (a few minutes).** Each file has visible hand-drawn strokes and a hidden layer (`display="none"`) with the same strokes as clean lines. I checked that the two layers agree everywhere. The hidden lines form a full 12×12 (or 10×10) grid of Cistercian numerals, so each file is a grid of numbers from 0 to 9999. Stroke direction and the drawing noise carry no information.
2. **Dead ends (about 10 attempts).**
   - Direct ASCII or 1–26 letter codes.
   - Running sums and differences.
   - The same cells across messages.
   - Grouping cells into runs.
   - Homophone repeats.
3. **The key observation.** Pairs of cells close together in row-by-row reading order add up to round numbers far more often than chance. Examples: 9000 (28 times against 1.6 expected), 190, 50, 2000, 150 and 1000. Neighbours in the same column show no such effect.
   - So each character is split into two random shares, a + b = v, with no modulus, and both shares are placed near each other.
   - The pairs often cross each other, which means several streams are interleaved.
4. **Alphabet.** I found the significant pair sums, matched cells into pairs with a dynamic-programming search, and used letter frequencies plus the first readable words. The table is fixed and the same in every message:
   - a–i = 10–90
   - j = 100, k = 110, l = 120, m = 130, n = 140, o = 150, p = 160, q = 180, r = 190 (170 never appears)
   - s = 1000, t = 2000, u = 3000, v = 4000, w = 5000, x = 6000, y = 7000 (z = 8000 inferred, never seen)
   - space = 9000
5. **Placement (the longest step, about 6 model tests).** I tried a rotating (Fleissner-type) grille. Under that model each 4-cell rotation orbit puts one cell in each of the 4 passes. That turns every share pair into an equation between two orbit settings, solvable with a union-find check.
   - On the 12×12 grids almost every equation cycle was consistent (0/23, 0/16, 1/23 conflicts), against about 75% expected by chance. That confirmed the model.
   - On the 10×10 grids the check showed more conflicts (8/16 in msg09, 18/22 in msg04), probably because the initial pairing was wrong. Those three messages still decoded cleanly once the search below ran.
   - Each pass is read in row order and the four passes are joined.
   - Random filler cells (any value, including the very common 9999) are inserted on their own.
6. **Solving each grid.** I started from the union-find solution, then ran simulated annealing and an iterated local search over the per-orbit rotations (4^25 or 4^36 options). The score was the number of letter pairs a skip-the-filler decoder finds. The text then became readable.
   - msg05 and msg07 needed several restarts from random starting points.

Effort overall: roughly 60–70 tool runs. The pair-sum discovery came about a third of the way in. Testing and fitting the grille took most of the remaining time; the readable text appeared within minutes of the right model.

### 3. How strong is the scheme

Weak against a ciphertext-only attacker.
- **Splitting leaks the values.** Shares are not taken modulo anything, so they are always no bigger than the value. Pair sums give the hidden letter values directly, and the round-number values stand out statistically.
- **Fixed letter table.** The same letter always has the same value, in every message. Once the values are found, frequency analysis is trivial, and the table is close to alphabetical anyway.
- **The grille keeps order.** Inside each pass the text stays in row order and the two shares sit next to each other. The orbit structure turns the key into a small set of equations that pairs reveal.
- **Filler doesn't help.** Single random cells and 9999s add noise but don't hide any of this.
- **The key is small.** It is about 4^36 ≈ 2^72 options, but the search breaks into local parts, so annealing finds it in minutes.

Fixes that would matter: random shares taken modulo 10000, a secret or per-message letter table, and a full key-based shuffle of the cells instead of a rotating grille.
