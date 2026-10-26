# Operations: the abbey's day

The live part of Cistergraphia is the day's chapter: one plate the abbey sets each day, the same
for every reader. Everything else is a tool a scribe uses when they choose to. This page says how
the chapter runs, how its content is kept, and what to do when something goes wrong.

## Why a chapter

A Cistergraphia plate needs two people: one who writes it and one who reads it. A visitor who
comes alone can inscribe a message, but they cannot play, because they already know the answer.
The chapter gives them a plate they did not write and a reason to come back the next day.

The name comes from the abbey. Each morning the community met in the chapter house to hear one
chapter of the Rule read aloud, and the room is named after that reading. Cistergraphia's
chapter belongs to the scriptorium, where readers work (see [design.md](design.md#voice-and-lexicon)).
It keeps the house rules: progress is a count of chapters read and never a streak. Nothing nags,
and missing a day costs nothing.

## The cadence

| Day | Rung | Way |
|---|---|---|
| Monday | intact | the snail |
| Tuesday | worn | one of the five, drawn for the day |
| Wednesday | pathless | withheld (one of the five) |
| Thursday | broken | the snail (broken plates follow it) |
| Friday | a tablet of its own | one of the five |
| Saturday | ruined | the snail |
| Sunday | the expert plate | withheld |

The week climbs the ladder, so a reader learns the cadence once. The order follows
[playtest.md](playtest.md): the desk teaches the signs, and the bench and the board assume them.
To change the order, edit `Chapter::WEEK` (`web/chapter.rb`). A change redraws every chapter,
past ones included (see "Deploys" below).

- **The day turns at midnight UTC**, for every reader at the same moment, so a chapter is the
  same plate wherever it is shared. For readers in Europe it turns at 1 or 2 a.m.; in the
  Americas it turns the previous evening.
- **Addresses.** Today's chapter is at `/chapter`. A dated chapter is at `/chapter/2026-10-26`.
  The archive runs back to chapter 1 (Monday 26 October 2026) and never forward: a date ahead of
  today is "not yet written".
- **The same plate for everyone, with nothing stored.** A day's plate is drawn from a random
  number generator seeded with its date. Every server, every restart and every reader therefore
  draws the same plate.

## The content

`web/chapters.yml` holds two lists.

- **`readings`** is the reading order, a lectionary. Chapter *n* reads the *n*th line. Past the
  last line the order starts again from the top, so the chapter repeats rather than stops.
- **`feasts`** are fixed dates, every year. A feast sets its own line and its own name. The rung
  stays the weekday's, and the reading it displaces waits until the next cycle.

| Feast | Date | Confidence |
|---|---|---|
| The Founders of Cîteaux (Robert, Alberic, Stephen Harding) | 26 January | high: the Cistercian calendar |
| Cîteaux founded, 1098 | 21 March | high: Palm Sunday 1098, the feast of St Benedict |
| The Phaistos Disc found, 1908 | 3 July | high: Luigi Pernier's excavation |
| Saint Benedict | 11 July | high: the general Roman calendar since 1969 |
| Saint Bernard of Clairvaux | 20 August | high |
| The Zodiac's 340 read, 2020 | 11 December | medium: the solution was made public that day, and the FBI confirmed it |

### Editorial rules

`test/chapter_test.rb` checks the first four rules.

- **Letters and single spaces only.** The plate carries exactly what is shown, and punctuation
  would read as spaces.
- **Six words or more.** A plate with a tablet of its own is close to guessing under six words
  (`Tablet::SHORT`).
- **Fifty letters and spaces at most**, so the plate is no larger than 10 × 10.
- **Each reading appears once in the order.**
- **Public domain sources only.** Translations from Latin are the house's own. Name the source
  as a catalogue would ("The Rule of Saint Benedict, chapter 48"). Use "After …" for a
  paraphrase and "Attributed to …" for a doubtful attribution.

### Adding readings

1. **Append lines at the end of `readings`.** A line inserted or removed above today's moves
   every later chapter onto a new text, today's included. Reorder only lines that have not been
   read yet: those after today's index, which `rake chapter:runway` reports.
2. Run `bundle exec rake test` and `bundle exec rake chapter:check`. The second draws every text
   under every rung, then the next 90 days, and reads each plate back. It takes about a minute
   and a half.
3. Open a PR. The Chapter workflow runs both checks on any change to `web/chapter*` or `lib/`.

### The runway

The runway is the number of days of new readings left before the order starts again. The 55
readings at launch last until 19 December 2026.

- `bundle exec rake chapter:runway` prints it and fails when fewer than 14 days are left
  (`RUNWAY=n` sets another floor).
- **Every Monday**, the Chapter workflow (`.github/workflows/chapter.yml`) runs both checks. A
  failure is the editor's notice: GitHub emails a failed scheduled run to whoever last changed
  its cron line.
- **When the runway runs out, nothing breaks**: the readings repeat. That is the planned way
  for the chapter to degrade, not an outage.

Working rhythm: write about eight weeks of readings at a time, when the Monday run turns red.

## Rehearsing a day

`CHAPTER_DATE=2026-12-24 bundle exec rackup` serves the site as if that date were today: the
archive up to it, `/chapter` on it. Use it to look at a feast, a new reading or a change to the
week before it goes live. The behaviour suite uses it as well, to serve the first full week.
Never set it in production: it freezes the chapter on one day.

## Serving it

- **Cost.** The chapter page is the same for every reader, so each server keeps the rendered
  page in memory (`Chapter.kept`, the 16 pages asked for most recently).
  - The cache key is the page's address, `rejoined=1` and today's date (the link to "the day
    after" depends on it).
  - The first request for a page costs 0.1 to 0.6 s: drawing the plate, then laying the bench or
    the board. Every later request costs about 2 ms.
  - A page that is still being drawn does not block one already kept. At midnight each server
    thread may draw the new plate once, then all of them find it kept.
- **What a kept page depends on.** Nothing in the request lays the page except `rejoined`: a
  grille key or a passphrase in the query string is dropped. The host the page was requested from
  (in its social links) is written in on each request, so one reader's `Host` header never shows
  up on another reader's page.
- **HTTP caching.** `/chapter` is sent with `Cache-Control: public, max-age` set to the seconds
  left until midnight UTC, so a CDN may keep it until the day turns. Dated chapters are kept for
  an hour. Nothing on the page depends on the reader: their record lives in their browser.
- **Nothing personal reaches the server.** The record of chapters read is a list of dates in
  `localStorage` (`cistergraphia.chapters`). The server never learns who read what.

## Deploys

A day's plate stays the same only as long as the code that draws it does not change. A change
to the drawing (`lib/`, `Chapter::WEEK`, the readings above today) redraws today's plate as well.
A reader in the middle of it then sees a different plate after a reload: their notebook, kept by
the tablet's seed, starts again empty.

- Ship such changes just after midnight UTC.
- A Ruby upgrade can change what a seeded random number generator deals. The tablet's shuffle
  is written out by hand to avoid that, but `Array#shuffle` and `sample` are not. Check a Ruby
  upgrade with `rake chapter:check`, and ship it at the turn of the day.
- A redrawn past chapter only changes the archive. The record counts dates, not plates, so it
  is unaffected.

## When something goes wrong

| Symptom | Likely cause | What to do |
|---|---|---|
| `/chapter` answers 500 | A text cannot make its day's plate (the drawing gave up after 100 tries) | Run `rake chapter:check`. Swap that day's reading for one that is not yet read (rule 1 above), or rehearse the day with `CHAPTER_DATE` to see the error. Then deploy. |
| The Monday run is red on the runway | Fewer than 14 days of new readings are left | Append readings. |
| The Monday run is red on a check | A change to `lib/` broke a rung for some text | The run names the text and the rung. Fix the drawing, not the text. |
| Readers report that today's plate changed | A deploy changed the drawing during the day | Expected; see "Deploys" above. |
| The chapter shows yesterday's plate | A CDN is keeping `/chapter` beyond its max-age | Purge `/chapter` at the CDN. The app sends the seconds left until midnight. |
