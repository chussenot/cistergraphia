# Cryptanalysis experiments

Can someone read a Cistergraphia without the decoder? These experiments answer that for both
modes. Conclusions and sources: [docs/security-study.md](../../docs/security-study.md).

| Experiment | Attacker | Game mode | Secret mode |
|---|---|---|---|
| [`blind-llm/`](blind-llm/) | An LLM agent with a shell, given only 10 SVGs | 10/10 messages in ~2.5 min | not run (nothing to reason about) |
| [`crack.py`](crack.py) | A script: public Cistercian glyphs + word lists | 100% from **one** SVG; 10/10 | stops at step 2; 0% |
| [`crack.py`](crack.py) on pathless plates along the leap | The same script; the file withholds the way | 100% from one SVG; 10/10, as along the snail | not run (the same seal) |
| [`blind-llm-grille/`](blind-llm-grille/) | The same agent, 10 SVGs under the Grille layout | 10/10 messages in ~26 min | not run |
| [`crack_grille.py`](crack_grille.py) | A script that knows the scheme (Kerckhoffs) but not the grille's key | 10/10 from single SVGs; plates up to 16 × 16, sometimes 18 × 18; shared keys fall | 0%: every branch dies at once |

## Scripted attack

`crack.py` imports nothing from Cistergraphia. It learns every parameter from the SVGs:

1. **Glyphs:** the longest vertical strokes are stems, the common horizontal stroke length is
   the cell unit, and strokes are matched to the standard Cistercian digits.
2. **Route and marker:** it tries 64 reading routes (row, boustrophedon, spiral and the
   Zodiac's leap, one down and two across wrapping, in every rotation and reflection, forwards
   and backwards: the five ways a plate can run are among them), times 2 ways of dropping the
   most frequent value. It keeps the hypotheses where neighbouring values sum to a multiple
   of 10. That happens 100% of the time in game mode, against 10% by chance. A pathless plate,
   whose file lays its signs in grid order and withholds the way, is read the same: the script
   never looked at the file's order, only at where each sign sits.
3. **Pairs → characters:** it sums each pair; the most frequent sum is the space.
4. **Substitution:** a dictionary-scored search over all substitutions, plus a second search
   restricted to "larger value = later letter" (the shortcut the blind LLM found). It keeps
   whichever scores better.

## Scripted attack on the Grille

`crack_grille.py` assumes everything public but the key: the tablet, the 9999 marker and the
turning grille's rules (orbits of four cells, one hole each, read N, E, S, W, row by row). It
reads the glyphs with `crack.read_grid`, then searches the holes depth first, row by row: at an
orbit's first cell it tries the 4 holes, and drops a branch as soon as a completed pair is not a
letter. On short plates a grille can pass that test and still be false (letters, not text), so a
grille is accepted only if at least 80% of the letters it reads fall in dictionary words; the
search goes on past the others. A grille it finds can be the true one turned by quarters; the
start that reads as the most words is kept. `--words` also prunes with the word lists as the
letters come; `--shared-key` takes the plates to share one grille and searches them together. It
never enumerates keys.

Short plates fall in seconds; from 18 × 18 (about 150 characters) the search may run out of steps,
from 20 × 20 it does, unless several plates share one key.
That bounds this search, not the grille: see [the study](../../docs/security-study.md#experiment-3-the-grille).
[`results/grille-attack.log`](results/grille-attack.log) holds the runs it quotes:

```
ruby make_corpus.rb long-messages.txt DIR game grille            # 16 x 16 to 30 x 30, a key each
python3 -I crack_grille.py DIR --answers DIR/answers.json --node-limit 400000000
ruby make_corpus.rb shared-messages.txt DIR game shared-grille   # 3 plates of 20 x 20, one key
python3 -I crack_grille.py DIR --answers DIR/answers.json --shared-key --node-limit 400000000
```

## Running

```
experiments/cryptanalysis/run.sh           # generates fresh corpora for both modes and attacks them
experiments/cryptanalysis/run.sh --check   # fails unless game ≥ 90% (80% under a grille) and secret ≤ 10% (run in CI)
```

Needs Ruby (`bundle install`), Python 3 and the word lists (`apt install wamerican wfrench`).
Corpora are regenerated on each run from [`messages.txt`](messages.txt); in secret mode the
passphrase is random and discarded. [`results/scripted-attack.log`](results/scripted-attack.log)
is the run quoted in the study.

## Files

- `crack.py`: the attacker
- `crack_grille.py`: the known-scheme attacker for Grille plates
- `make_corpus.rb`: writes SVGs + `answers.json` for a list of messages, in either mode, optionally
  each under its own random grille
- `messages.txt`: plaintexts for the scripted runs; `long-messages.txt`, `shared-messages.txt`: for
  the long and shared-key Grille runs
- `run.sh`: runs both experiments end to end
- `blind-llm/`, `blind-llm-grille/`: protocol, ciphertexts, the agent's report and scripts, answers
