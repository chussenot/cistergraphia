# Cryptanalysis experiments

Can someone read a Cistergraphia without the decoder? These experiments answer that for both
modes. Conclusions and sources: [docs/security-study.md](../../docs/security-study.md).

| Experiment | Attacker | Game mode | Secret mode |
|---|---|---|---|
| [`blind-llm/`](blind-llm/) | An LLM agent with a shell, given only 10 SVGs | 10/10 messages in ~2.5 min | not run (nothing to reason about) |
| [`crack.py`](crack.py) | A script: public Cistercian glyphs + word lists | 100% from **one** SVG; 10/10 | stops at step 2; 0% |

## Scripted attack

`crack.py` imports nothing from Cistergraphia. It learns every parameter from the SVGs:

1. **Glyphs:** the longest vertical strokes are stems, the common horizontal stroke length is
   the cell unit, and strokes are matched to the standard Cistercian digits.
2. **Route and marker:** it tries 48 reading routes (row, boustrophedon and spiral, in every
   rotation and reflection, forwards and backwards), times 2 ways of dropping the most frequent
   value. It keeps the hypotheses where neighbouring values sum to a multiple of 10. That
   happens 100% of the time in game mode, against 10% by chance.
3. **Pairs → characters:** it sums each pair; the most frequent sum is the space.
4. **Substitution:** a dictionary-scored search over all substitutions, plus a second search
   restricted to "larger value = later letter" (the shortcut the blind LLM found). It keeps
   whichever scores better.

```
experiments/cryptanalysis/run.sh           # generates fresh corpora for both modes and attacks them
experiments/cryptanalysis/run.sh --check   # fails unless game ≥ 90% and secret ≤ 10% (run in CI)
```

Needs Ruby (`bundle install`), Python 3 and the word lists (`apt install wamerican wfrench`).
Corpora are regenerated on each run from [`messages.txt`](messages.txt); in secret mode the
passphrase is random and discarded. [`results/scripted-attack.log`](results/scripted-attack.log)
is the run quoted in the study.

## Files

- `crack.py`: the attacker
- `make_corpus.rb`: writes SVGs + `answers.json` for a list of messages, in either mode
- `messages.txt`: plaintexts for the scripted runs
- `run.sh`: runs both experiments end to end
- `blind-llm/`: protocol, ciphertexts, the agent's report and scripts, answers
