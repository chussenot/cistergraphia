# Weathering experiments

How much of a weathered plate can be restored, and by what. Quoted in the
[design study](https://claude.ai/artifact/3Znn5cBwbHapztpfaeUZ6Q) and behind the
choices in `lib/cistergraphia/weathering.rb`.

| Script | Question | Result |
|---|---|---|
| [`restorability.rb`](restorability.rb) | How often does the pair checksum alone restore a lost quadrant, part of one, or a whole sign? What does the generator lay? | One quadrant: 70% (units always, tens 46%). One to three stroke positions: 88% to 76%. A whole sign: 10%. The generator: one pair in three damaged, 89% restored by the balance alone, the rest left to two or three letters. |
| [`tally.rb`](tally.rb) | Would row and column sums (khipu style) restore whole lost signs? | Scattered losses, yes: 8 signs on 12 × 12 in 98% of trials. A broken corner, no: past 4 clustered signs, never. So the generator loses a whole sign only where its row or column has no other lacuna (`Weathering::Cords`). |
| `restorability.rb`, part 3 | What does the generator lay with tally signs? | One pair in 2.3 damaged, a quarter of the lacunae whole signs; every edition restored with no doubt left (100 plates). |

```
bundle exec ruby experiments/weathering/restorability.rb [TRIALS]   # ~1 min for 4000
ruby experiments/weathering/tally.rb                                 # pure arithmetic, no library
```

[`results/restorability.log`](results/restorability.log) is the run quoted.

## Why the tens fail

Every tablet value ends in 0, so a lost units digit has exactly one value that
balances its pair. But the letters a to i are 10 to 90: lose the tens of a pair
and several letters still balance. The same goes for s to z and the space,
which are thousands. The generator keeps such a lacuna only if it leaves at most
three letters, never a space, and at most one doubt per word: the reader's sense
of the language settles it, as in an epigrapher's edition.
