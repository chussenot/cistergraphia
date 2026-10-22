# Weathering experiments

How much of a weathered plate can be restored, and by what; whether a broken
one can be rejoined. Quoted in the
[design study](https://claude.ai/artifact/3Znn5cBwbHapztpfaeUZ6Q) and behind the
choices in `lib/cistergraphia/weathering.rb` and `lib/cistergraphia/fragments.rb`.

| Script | Question | Result |
|---|---|---|
| [`restorability.rb`](restorability.rb) | How often does the pair checksum alone restore a lost quadrant, part of one, or a whole sign? What does the generator lay? | One quadrant: 70% (units always, tens 46%). One to three stroke positions: 88% to 76%. A whole sign: 10%. The generator: one pair in three damaged, 89% restored by the balance alone, the rest left to two or three letters. |
| [`tally.rb`](tally.rb) | Would row and column sums (khipu style) restore whole lost signs? | Scattered losses, yes: 8 signs on 12 × 12 in 98% of trials. A broken corner, no: past 4 clustered signs, never. So the generator loses a whole sign only where its row or column has no other lacuna (`Weathering::Cords`). |
| `restorability.rb`, part 3 | What does the generator lay with tally signs? | One pair in 2.3 damaged, a quarter of the lacunae whole signs; every edition restored with no doubt left (100 plates). |
| [`by_size.rb`](by_size.rb) | How thin is a small worn plate, and does one pair in two help? | One pair in three throughout (as first laid): a 4 × 4 plate got 2 lacunae and 77% of the plates left no doubt at all (a lesson, not a puzzle); 6 × 6, 6 lacunae, 35% no doubt; 10 × 10 and up, 4% or less. One pair in two on 4 × 4 and 6 × 6: 4 and 9 lacunae, 51% and 27% with no doubt, the balance still restoring 87%. So the generator damages one pair in two under 8 × 8 (`Weathering::SMALL_SHARE`, `SMALL_PLATE`), one in three above. |
| [`fragments.rb`](fragments.rb) | Do the sums alone rejoin a broken plate, weathered or not, and how fast? | The shapes allow 32 arrangements (median; up to 384). On the snail, one balances in 99.5% to 100% of first breaks (the generator draws again otherwise). Along the rows, never: a Rongorongo plate turned half round balances too, so only Phaistos plates break (`Fragments::NOT_ALONG_THE_ROWS`). The search takes 40 ms at most, on a 32 × 32 plate. Weathered first (2 to 170 lacunae), the sums still rejoin 99.5% to 100% of first breaks one way only, in 45 ms at most. |

```
bundle exec ruby experiments/weathering/restorability.rb [TRIALS]   # ~1 min for 4000
ruby experiments/weathering/tally.rb                                 # pure arithmetic, no library
bundle exec ruby experiments/weathering/fragments.rb [PLATES]        # ~10 min for 200
bundle exec ruby experiments/weathering/by_size.rb [PLATES]          # ~20 s for 200
```

[`results/restorability.log`](results/restorability.log),
[`results/fragments.log`](results/fragments.log) and
[`results/by_size.log`](results/by_size.log) are the runs quoted.

## Why the tens fail

Every tablet value ends in 0, so a lost units digit has exactly one value that
balances its pair. But the letters a to i are 10 to 90: lose the tens of a pair
and several letters still balance. The same goes for s to z and the space,
which are thousands. The generator keeps such a lacuna only if it leaves at most
three letters, never a space, and at most one doubt per word: the reader's sense
of the language settles it, as in an epigrapher's edition.

## Why only the snail breaks

A pair is two signs in a row along the reading path. Along the rows of a
Rongorongo plate with an even side, no pair ever straddles two rows: a break
across the rows splits no pair, so the sums cannot say which strip goes above
which. Worse, the plate turned half round reads its rows in reverse order, each
row the right way: every pair still balances. The snail crosses every straight
break (its rings run round the whole plate), so pairs straddle every join, and
a turned plate reads along another path entirely.
