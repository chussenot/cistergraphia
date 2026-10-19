# Blind LLM attack on Grille plates: protocol

**Date:** 2026-10-19
**Question:** can a model read game plates written under a turning grille, given nothing but the SVGs?
**Result:** all 10 messages recovered, in about 26 minutes and 81 tool calls (against about
2.5 minutes for the same kind of attack on plates without a grille). See [REPORT.md](REPORT.md) and
[ANSWERS.md](ANSWERS.md).

## Setup

- **Attacker:** a Claude agent (Claude Code general-purpose subagent, same model family as the
  session that ran the experiment), with shell and Python 3 available. Same as the
  [first blind run](../blind-llm/PROTOCOL.md).
- **Ciphertexts:** 10 game-mode plates in [`corpus/`](corpus/), each written under its own random
  grille (the Grille layout, merged in #18; encoder at commit `40fd5b5`). 12 x 12 and 10 x 10 plates.
  The SVGs carry the pressed wedges and the hidden `<line>` strokes, and no name, comment or
  metadata hinting at the scheme.
- **Plaintexts and keys:** never written to disk during the experiment (the messages were passed
  to the encoder on stdin, the keys drawn and thrown away), so the attacker could not stumble on them.
- **Not given:** the code, the tablet, the word "grille" or any hint about the layout. A blind
  attacker, like the first run: the [scripted attack](../crack_grille.py) covers the attacker who
  has the code but not the key.

## Rules given to the attacker

The same prompt as the first blind run, with the folder renamed: read only the folder holding the
10 SVGs; do not read, list or search `/home/user`, any git repository, any other part of the
scratchpad or anything else on the filesystem; no web access; scripts allowed (Python 3 standard
library) in a separate work directory; any general knowledge allowed. Report the plaintexts, the
method, the effort per step and an assessment.

## Evidence and limits

- [`agent-scripts/`](agent-scripts/) holds the 37 scripts the agent wrote, unmodified. They only
  read the SVG folder and their own intermediate files (`grids.json`, key files), which supports
  its claim of isolation. Isolation was **instructed, not enforced** by a sandbox.
- Two messages (msg05, msg07) were assembled from several annealing runs rather than read off one
  clean solution; the agent said so. Its final readings all match the plaintexts exactly.
- One model, one run, 10 short messages (10 x 10 and 12 x 12). Longer plates were not tried blind.
- Contamination: the Grille layout and its key derivation were published in this repository on
  the day of the experiment, so they cannot be in any model's training data. The agent inferred
  the turning grille from the numbers ("I tried a rotating (Fleissner-type) grille").
