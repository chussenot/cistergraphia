# Security study: can a Cistergraphia be cracked?

*October 2026 — experiments in [`experiments/cryptanalysis/`](../experiments/cryptanalysis/)*

## Summary

| Mode | Who can read a message | Evidence |
|---|---|---|
| **Game** (no passphrase) | Anyone. An LLM agent recovered 10/10 messages from the SVGs alone in about 2.5 minutes, and a 300-line script recovers a message from **a single** SVG. | [blind LLM](../experiments/cryptanalysis/blind-llm/PROTOCOL.md), [scripted attack](../experiments/cryptanalysis/results/scripted-attack.log) |
| **Game under a Grille** (50-bit key) | Anyone, for short messages. An LLM agent recovered 10/10 from the SVGs alone in about 26 minutes; a script that knows the scheme but not the key reads plates up to 18 × 18 (about 150 characters) from a single SVG, in seconds. Longer plates resisted that script; nothing says they resist a better one. | [blind LLM](../experiments/cryptanalysis/blind-llm-grille/PROTOCOL.md), [scripted attack](../experiments/cryptanalysis/results/grille-attack.log) |
| **Secret** (passphrase) | Only someone with the passphrase, unless it is weak enough to guess. | The scripted attack finds no structure (pair test at chance level). The construction is standard authenticated encryption. |

The game mode is a puzzle, not encryption. It has no key, so by
[Kerckhoffs's principle](https://en.wikipedia.org/wiki/Kerckhoffs%27s_principle) it offers no
secrecy against anyone who has the code, and the experiments show it barely slows down anyone
who doesn't. Secret mode was added as a result.

## Threat model

| Attacker | Game mode | Secret mode |
|---|---|---|
| Has the code (the repository may be public) | Runs `./cistergraphia -d`. Instant. | Needs the passphrase. |
| Has only the images, no code | Breaks it: see the experiments below. | Learns the message size only. |
| Has images **and** some known plaintexts | Trivial. | No help: each image uses a fresh salt and nonce. |
| Can modify an image | Changes the message undetected. | Any change to the message is rejected. |
| Guesses passphrases offline | n/a | ~0.3 s and 16 MiB per guess (scrypt). Weak passphrases fall. |

## Experiment 1: a model given only the SVGs

A Claude agent with a shell received 10 game-mode SVGs. It got no source, no plaintexts, no web
access and no hint about the scheme ([protocol](../experiments/cryptanalysis/blind-llm/PROTOCOL.md)).

**Result:** all 10 messages recovered exactly, including the French one, in about 2.5 minutes and
9 tool calls ([report](../experiments/cryptanalysis/blind-llm/REPORT.md),
[answers](../experiments/cryptanalysis/blind-llm/ANSWERS.md)). Its path:

1. Recognised the glyphs as Cistercian numerals on sight, and decoded every symbol to 0–9999.
2. Noticed that neighbouring values add up to round numbers (831 + 2169 = 3000).
3. Inferred the spiral from the square grid and confirmed it with a pair that sits across a
   corner of the spiral.
4. Spotted 9999 as filler immediately.
5. Took 9000, the most frequent sum, as the space, and used repeated "THE " to anchor the letters.
6. Saw that the values follow the alphabet (a = 10, b = 20, …, s = 1000, …), fixed one
   off-by-one error in the k–r range from misspelled words, and even guessed the never-used J
   correctly.

This is not at odds with research reporting that LLMs are poor at unknown substitution ciphers
([Rashid, 2026](https://arxiv.org/abs/2603.22497); see also
[2508.10235](https://arxiv.org/abs/2508.10235), [2505.08389](https://arxiv.org/abs/2505.08389)).
Those studies test reasoning in context alone. An agent that can run code and calculate is a
different attacker. Here, too, the alphabet-ordered table gave the substitution away.

## Experiment 2: a script with no LLM

[`crack.py`](../experiments/cryptanalysis/crack.py) imports nothing from Cistergraphia. Its only
prior knowledge is the public Cistercian glyph shapes (as on [dCode](https://www.dcode.fr/cistercian-numbers))
and English/French word lists. Same 10 plaintexts in both modes, fresh corpus per run:

| Step | Game mode | Secret mode |
|---|---|---|
| Read the glyphs | 1,596 / 1,596 symbols | 776 / 776 symbols |
| Find the filler marker | 9999, the most frequent value | none (most frequent: 0, the length header) |
| Find the reading route (96 hypotheses) | 100% of pairs sum to a multiple of 10 (chance: 10%) | best 13%: no structure, **attack stops** |
| Recover the text, 1 SVG (81 characters) | **100%** | 0% |
| Recover the text, 10 SVGs | **10/10 messages** | 0/10 |

The CI job `cryptanalysis` reruns this on every push and fails if game mode stops being
breakable (< 90%) or secret mode starts leaking (> 10%).

## Experiment 3: the Grille

The Grille layout writes the plate row by row under a turning grille: one hole per orbit of
four cells, read at N, E, S and W. Its key, 10 characters of base 32 (50 bits), places the holes.
Both attacks were run again on grille plates, game mode, each plate under its own random key.

**A model given only the SVGs.** Same agent, same rules, 10 new messages on 10 × 10 and
12 × 12 plates ([protocol](../experiments/cryptanalysis/blind-llm-grille/PROTOCOL.md)). It was
not told about the grille. **All 10 recovered exactly**, in about 26 minutes and 81 tool calls,
ten times the effort of the plain layouts ([report](../experiments/cryptanalysis/blind-llm-grille/REPORT.md),
[answers](../experiments/cryptanalysis/blind-llm-grille/ANSWERS.md)). Its path:

1. Read the glyphs, then tried about ten dead ends (letter codes, running sums, runs of cells).
2. Noticed that cells close together **in row-by-row order** add up to round numbers far more
   often than chance (9000: 28 times against 1.6 expected), and that column neighbours do not.
   The grille keeps the two halves of a letter next to each other within a quarter.
3. Recovered the whole tablet from those sums, word frequencies and the first readable words.
4. Guessed a turning (Fleissner) grille. Each candidate pair then becomes an equation between
   two orbits' settings; a union-find check found almost no contradictions on the 12 × 12
   plates (0 of 23 cycles, against about 75% by chance), which confirmed the model.
5. Solved each plate by simulated annealing and local search over the orbits' settings, scored
   by how many pairs read as letters. Two plates took several restarts.

**A script that knows the scheme.** By Kerckhoffs's principle the code is public, so the attacker
of interest knows the tablet, the 9999 filler and the grille's rules, and lacks only the key.
[`crack_grille.py`](../experiments/cryptanalysis/crack_grille.py) scans the plate row by row; at
each orbit it meets for the first time it tries the 4 holes, and it drops a branch as soon as a
completed pair is not a letter. Short plates have false grilles too, under which every pair is a
letter but the letters are not text, so it accepts a grille only if most of what it reads is
dictionary words, and searches on past the others. It works on **one SVG at a time** and never
touches the key space ([log](../experiments/cryptanalysis/results/grille-attack.log)):

| Plate | Message | Result |
|---|---|---|
| 12 × 12 and 14 × 14 (the 10 messages of Experiment 2, 7 fresh corpora) | 53 to 81 characters | **70/70**; most in under a second, the slowest in 1.5 min |
| 16 × 16 | 119 characters | recovered, 0.6 s |
| 18 × 18 | 157 characters | recovered, 22 s |
| 20 × 20 to 30 × 30 | 195 to 416 characters | no grille within 400 million steps (6 to 9 min each) |
| 3 plates of 20 × 20 under **one** key | 171 to 177 characters each | no grille within 300 million steps (12 min) |

The wall at 20 × 20 is **this search's, not the grille's.** In row order, each row opens up to
n new orbits (4 choices each) but completes only about n/2 pairs to check them, so the cost grows
exponentially with the side. A search that orders the orbits by the constraints they share, the
blind agent's annealing, or more compute would likely go further; none was tried at that size.
Do not count on a long message for secrecy. Two more reasons:

- **The key is 50 bits.** With the code, trying every key is about 10¹⁵ grilles, each checked by
  its first few pairs. Out of reach for a laptop, within reach of dedicated hardware.
- **The tablet is still fixed.** The grille moves the signs; it does not change what they are.
  The frequencies of the pair sums, and so the space and the common letters, show through.

**Secret mode under a grille** gives the attack nothing: no pair reads as a letter, every branch
dies at once, 0/10. The grille adds nothing to secret mode either: AES-GCM does the sealing, and
the grille only makes the reader need a key as well as the passphrase.

## Why game mode falls, worst first

1. **No key.** Whoever has the algorithm has every message.
2. **The tablet is in alphabetical order** (a = 1 … r = 19, s = 100 … z = 800, space = 900). Once
   a few letters are known the rest follow, and it is a single fixed substitution, so frequent
   words ("the", the space) anchor it.
3. **The random split hides nothing.** Two neighbouring values always add back to the letter's
   value, and that sum always ends in 0, which also reveals where each pair starts.
4. **The filler is labelled** by the constant 9999.
5. **The spiral is one of a handful of obvious routes,** and the pair test confirms which one.
   The Rongorongo layout (reverse boustrophedon, every other row upside down) adds one more route
   to try, not a key: the decoder itself tells the two apart with the same pair test, so an
   attacker does too. Turned glyphs read as their mirror (units ⇄ thousands, tens ⇄ hundreds),
   which is a fixed, public transformation. Choose a layout for its look, not for security.
   (On very short messages the pair test can pass along both routes, about 1 two-letter plate
   in 100; the encoder redraws those, so the test always names one.)
   The **Grille** layout is the one route with a key: a turning grille, set by a code of 50
   bits. It hides what the attacks above start from, which cells are neighbours in reading
   order, and it slows a blind attacker tenfold. But it keeps the order inside each quarter,
   so the pair test still gives an attacker a score to climb, one hole at a time: see
   [Experiment 3](#experiment-3-the-grille). It is a puzzle with a key, not a seal.
6. **Images instead of SVG would not help.** The glyphs are regular and documented: dCode
   converts them, and a vision model or a small classifier reads them. Pressing the signs in
   wedges does not change this either: the file still carries every stroke as a line (the
   decoder needs them), and the wedges keep each stroke's position and direction.

**Why not harden the game instead?** The attacking agent suggested a keyed tablet, a keyed route
and sums modulo 10,000. These remain classical constructions: a keyed homophonic substitution
behind a keyed transposition. Language statistics break those given enough text, and every
added layer is custom cryptography nobody has reviewed. The standard answer is authenticated
encryption with a vetted primitive, which is what secret mode does.

## Secret mode

```
passphrase ──scrypt(N=2^14, r=8, p=5, random 16-byte salt)──▶ 256-bit key
message (UTF-8) ──AES-256-GCM(key, random 12-byte nonce, AAD = header)──▶ ciphertext + 16-byte tag
payload = version | salt | nonce | ciphertext | tag
payload bytes ──base 10,000──▶ glyph values ──▶ [length, length, values…, random padding] ──layout──▶ SVG
```

- **Primitives:** AES-256-GCM ([NIST SP 800-38D](https://csrc.nist.gov/pubs/sp/800/38/d/final))
  and scrypt ([RFC 7914](https://www.rfc-editor.org/rfc/rfc7914)), both from OpenSSL through
  Ruby's standard `openssl` library. No new dependency, and no custom cryptography.
- **KDF cost:** N = 2¹⁴, r = 8, p = 5 (16 MiB, about 0.3 s). It is one of the settings the
  [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
  lists as equivalent to its N = 2¹⁷, r = 8, p = 1 baseline, and it needs 8× less memory per
  request on the web server. OWASP prefers Argon2id, but that would add a native gem.
- **Fresh randomness per image:** a new salt and nonce every time, so the same message gives a
  different picture and nonces never repeat under a key.
- **Integrity:** GCM authenticates the payload and the header (version, salt, nonce). One
  altered glyph and decryption fails. Only the random padding glyphs are not covered, and they
  carry nothing.
- **Agility:** the version byte selects the KDF and cipher parameters, so they can be raised
  later and old images still decode.
- **Exact text:** no normalisation, so capitals, digits, accents and emoji survive.
- **Layout:** the decoder tries both keyless layouts (a grille's plate, square, asks for its
  key instead). The wrong one fails the length frame before any
  scrypt work (in 200 of 200 random plates), or else the GCM tag, so it never yields a false
  message. It is not
  secret and adds no security.

### What secret mode does not protect

- **Weak passphrases.** Anyone with an image can test guesses offline, at about 0.3 s each on one
  CPU core. Specialised hardware goes faster, although scrypt's memory cost limits that. Use four
  or more random words. The minimum of 8 characters is a floor, not a recommendation.
- **Message length.** The length glyphs reveal the message size in UTF-8 bytes, to within about
  2 bytes. Padding messages to fixed sizes before encryption would hide it; it is not done today.
- **The web server.** The web UI sends the message and passphrase to the server, which does the
  encryption. Use it over HTTPS and trust its operator, or use the CLI, which works locally.
- **Who wrote it.** It is symmetric: anyone with the passphrase can also create valid images. There
  is no sender authentication beyond knowing the passphrase.
- **Lost passphrases.** There is no recovery.
- **Review.** The construction uses standard primitives in a standard way, but no cryptographer
  has reviewed it.

## Limits of this study

- One LLM, one run, 10 short messages. The scripted attack is reproducible, but the LLM result
  is an anecdote, not a benchmark.
- The agent's isolation (no repository, no web) was instructed, not sandboxed. Its scripts,
  committed with the experiment, only touch the corpus.
- No one attempted a passphrase-guessing attack on secret mode. Its strength there is scrypt's
  cost times the passphrase's entropy.
- The Grille was measured on short plates by both attackers, and on long ones by the script
  only. That the script stalls at 20 × 20 bounds this search, not the grille.

## Reproduce

```
apt install wamerican wfrench          # word lists for the scripted attacker
experiments/cryptanalysis/run.sh       # both modes, with and without a grille, fresh corpora, ~1 min
```

## Sources

- [dCode: Cistercian numbers](https://www.dcode.fr/cistercian-numbers): public converter for the glyphs
- [Cistercian numerals (Wikipedia)](https://en.wikipedia.org/wiki/Cistercian_numerals)
- [Kerckhoffs's principle (Wikipedia)](https://en.wikipedia.org/wiki/Kerckhoffs%27s_principle)
- [Rashid: A Cipher-Based Framework for Exploring In-Context Language Learning (arXiv 2603.22497)](https://arxiv.org/abs/2603.22497)
- [Can Transformers Break Encryption Schemes via In-Context Learning? (arXiv 2508.10235)](https://arxiv.org/abs/2508.10235)
- [Towards Contamination Resistant Benchmarks (arXiv 2505.08389)](https://arxiv.org/abs/2505.08389)
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [NIST SP 800-38D: Galois/Counter Mode (GCM)](https://csrc.nist.gov/pubs/sp/800/38/d/final)
- [RFC 7914: The scrypt Password-Based Key Derivation Function](https://www.rfc-editor.org/rfc/rfc7914)
