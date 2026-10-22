# Playtest protocol

What a script can measure about the puzzles is measured
([experiments/weathering](../experiments/weathering/README.md)). What it cannot is how long a
reader who did not write the message takes, where they get stuck, and whether the ladder's
rungs feel like the design says. This is the protocol for that, so the first playtests are
comparable.

## Setup

- Two people: a scribe and a reader. The reader must not know the message.
- The scribe inscribes a game plate on the Inscribe page, chooses a rung and a layout, downloads
  the SVG and sends it (any channel). The reader brings the file to Read.
- One plate per rung and size in the table below, in that order: the desk teaches the numerals
  the bench and the board then assume.
- The reader plays with the script on, in their usual browser, phone or desktop. Note which.

## What to record

One row per plate. Times are wall-clock, from the puzzle opening to the win line ("Read to the
end", "every pair balances", "Whole again"), or to Decipher if the reader gave up.

| Rung | Size | Layout | Device | Time | Won / Decipher | Doubts settled right | Where stuck | Notes |
|---|---|---|---|---|---|---|---|---|
| Intact | 6 × 6 | Phaistos | | | | n/a | | |
| Intact | 10 × 10 | Rongorongo | | | | n/a | | |
| Intact, pathless | 8 × 8 | Leap, withheld | | | | n/a | | which way first; how many tried before the right one |
| Worn | 6 × 6 | Phaistos | | | | / | | |
| Worn | 10 × 10 | Phaistos | | | | / | | |
| Worn, pathless | 8 × 8 | Furrows, withheld | | | | / | | which way first; whether the edition's [?] marks were read as the sign of a wrong way |
| Broken | 10 × 10 | Phaistos | | | | n/a | | |
| Ruined | 10 × 10 | Phaistos | | | | / | | |

"Doubts settled right": on a worn plate the edition leaves two or three letters to the reader
("[b/l]"); count how many of those the reader settled as the scribe wrote them, over how many
there were. "Where stuck": the step the reader spent longest on, in their words.

## Estimates to check

The design study's time estimates, for a 10 × 10 plate, were guesses to be replaced by these
measurements:

| Rung | Estimate |
|---|---|
| Intact | 3 to 10 min |
| Worn | 5 to 12 min |
| Broken | 1 to 5 min |
| Ruined | 8 to 20 min |

Two balance risks to watch, now partly measured:

- A worn plate of a short message was a lesson rather than a puzzle (77% of 4 × 4 plates with no
  doubt at all, damaged one pair in three). Small plates now lose one pair in two: 51% and 27%
  with no doubt on 4 × 4 and 6 × 6. If a 6 × 6 still feels thin to readers,
  `Weathering::SMALL_PLATE` can rise to 50 pairs (under 10 × 10).
- A broken plate of a long message is won in a minute when two tall strips only fit two ways.
  If readers confirm it, the cut can prefer three or four pieces on large plates
  (`Fragments::Breaking`).

## After a session

Fill the table into `experiments/weathering/results/playtests.md` (one section per session,
dated, with the device and the browser) and compare with the estimates. Change a constant only
on two sessions that agree.
