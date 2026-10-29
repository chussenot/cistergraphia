# Quality: how we know

What the project tests, which promise each layer keeps, how to run it, and what a change must
pass before it merges. The design is in [design.md](design.md), the cipher's limits in
[security-study.md](security-study.md), the puzzles' feel in [playtest.md](playtest.md); this
page is how the rest is kept true.

## The promises

Each layer owns one promise the site makes. A test that checks *how* rather than *what* is a
maintenance cost, not confidence.

| Layer | The promise | Run | In CI |
|---|---|---|---|
| Ruby unit (`test/*_test.rb`) | A plate reads back, and only its way: the cipher, the layouts, the grille, the seal, weathering, fragments, tally, the stylus | `bundle exec rake test` | Ruby 3.3, 3.4, 4.0 |
| HTTP (`test/app_test.rb`) | Every route and refusal; the CSP; no caching of secrets; the reader's page holds only what the file shows; the markup the scripts rely on | `bundle exec rake test` | yes |
| The command line (`test/cli_test.rb`) | Every kind of plate written and read back through `./cistergraphia`, and its refusals | `bundle exec rake test` | yes |
| Coverage (`test/coverage.rb`) | A change does not arrive without its test: lines run in `lib`, `web` and `app.rb`, floor 97 % | `bundle exec rake test:coverage` | yes |
| Node unit (`test/sound_test.js`) | What a sound is, from what made it | `bundle exec rake test:sound` | yes |
| Layout stability (`test/ui/stability.js`) | Nothing on a page moves under the reader: 77 interactions, 24 page states, 4 viewports, JS on and off | `bundle exec rake ui:stability` | Chromium |
| Behaviour (`test/ui/play.js`) | The reader who does the work gets the message: the desk, the bench, the board, Lectio, the record, the preview, the grille, the day's chapter read and counted; a pathless plate, where a wrong way breaks and the right one reads, at the desk and at the bench; a plate with a tablet of its own, built in the notebook, where two right entries hold nothing and three go into ink; the expert plate, where a wrong way breaks on a sum, three pairs that land open the notebook on the way, and the way found is kept; silence by default; zero axe violations; the budgets | `bundle exec rake ui:play` | Chromium, Firefox, WebKit |
| The day's chapter (`test/chapter_test.rb`, `rake chapter:check`) | Every day has a plate that reads back as its text: the texts' rules, the week's rungs, the same plate for every reader, the next two weeks (in the suite); every text under every rung and the next 90 days, and 14 days of new readings left (`chapter:check`, `chapter:runway`, a minute and a half) | `bundle exec rake test`; `bundle exec rake chapter:check chapter:runway` | the suite on every change; the checks on a change to the chapter or `lib/`, and every Monday ([operations.md](operations.md)) |
| End to end (`test/ui/e2e.js`) | Every choice of the form (six layouts, four conditions, the path shown or withheld, the tablet shared or its own, game or sealed; a short, a mid and a 500-character message), written as a person writes it: a plate the server makes is drawn whole on its page (every stroke inked once the inking has run, every lacuna hatched, no page error), a refusal says why beside its choice with the message kept; each file opens on Read as its puzzle, drawn whole too, and Decipher it reads the message back (an edition on a worn plate). Phone and desktop alternate; three cases run with motion on | `bundle exec rake ui:e2e` (`E2E_ONLY=worn` for a part) | Chromium, Firefox, WebKit |
| The container (`Dockerfile`, `deploy/smoke.sh`) | The image the site is served from builds, starts, and answers every page as itself: Inscribe, Read, the chapter, a plate, a sealed plate, a refusal, the erratum, the stylesheet; the plate's page uncached and under the CSP | `docker build -t cistergraphia . && docker run -p 8080:8080 cistergraphia`, then `deploy/smoke.sh http://127.0.0.1:8080` | yes, and again on the live service after each deploy |
| The infrastructure (`infra/`) | The Terraform is formatted and valid against the Google and Cloudflare providers' schemas | `terraform -chdir=infra fmt -check && terraform -chdir=infra validate` | yes |
| Cryptanalysis (`experiments/cryptanalysis/run.sh --check`) | The game stays breakable and the seal does not leak: the security study kept honest | `run.sh --check` | yes |
| Lint (`rubocop`) | Ruby style and the complexity ceilings | `bundle exec rubocop` | yes |
| Experiments (`experiments/weathering`) | The design's numbers (restorability, fragments, tally, the share by size) | by hand, when the ladder changes | no |
| Playtest ([playtest.md](playtest.md)) | How long a reader who did not write the message takes, where they get stuck, whether the ladder feels right | two people, an hour | no |

`bundle exec rake quality` runs everything that runs locally in under three minutes (the Ruby
suite with coverage, the Node tests, rubocop) and names the two browser suites to run for a
change to the pages.

## The floors

Floors, not targets: each fails loudly when a change arrives without its proof, and nobody
chases the number.

| Floor | Value | Where |
|---|---|---|
| Ruby line coverage | 97 % (99.1 % today) | `test/coverage.rb` |
| axe-core violations | 0 on 13 page states in both themes | `test/ui/play.js` |
| Page errors | 0, in both browser suites | `stability.js`, `play.js` |
| Elements that move under the reader | 0 (1 px tolerance) | `stability.js` |
| Scripts and styles | under 60 KB as transferred (37 KB today; 157 KB unpacked: the app compresses them with `Rack::Deflater`) | `play.js` |
| Longest task inking a 14 × 14 plate | under 300 ms (126 to 196 ms measured) | `play.js` |
| Game plates the attack reads | at least 90 % (80 % under a grille) | `run.sh --check` |
| Sealed plates the attack reads | at most 10 % | `run.sh --check` |

## The rules

- **The file is the contract.** The plate's SVG is the interface between the scribe, the reader,
  the decoder and the command line. Every round trip crosses it; the fuzz crosses it; the
  browser suites bring real files to Read. Nothing is tested through an API a reader could
  not reach.
- **Prove outcomes, not just stillness.** The two browser suites share one boot
  (`test/ui/harness.rb`): the harness measures what moves, the behaviour suite reads what the
  page says.
- **One browser is not the web.** Behaviour runs on three engines in CI, Chromium, Firefox and
  WebKit (`BROWSER=firefox|webkit` locally); a check an engine cannot make is skipped and says so,
  never passed empty. Layout runs on one, since its measure is layout, not engines. A feature
  that needs a CSS or Web API feature names its oldest supported Safari.
- **No retries.** A flake is a bug in the test or the page. CI never retries a job; a red job
  gets a one-line diagnosis in the PR before any push.
- **Measurements stay measurements.** The experiments test the design, not the code; they run
  when the ladder changes. The cryptanalysis runs always because the security study quotes it.
- **Humans measure feel.** The playtest protocol is the only instrument for difficulty and
  delight; it runs before a change to the ladder ships, and its rows are committed.

## What a change must pass

Cistergraphia ships from master on every merge, so a release is a merge. The gates depend on
what the change touches; a PR says which row it is in and lists what it passed.

| A change to | Must pass | And by hand, before the PR leaves draft |
|---|---|---|
| The library (`lib/`) | The Ruby suite on three Rubies, rubocop, the coverage floor, the cryptanalysis check; the behaviour suite if a plate's file changes shape | A round trip at the command line of the plate kind touched |
| The pages (`app.rb`, `views/`, `web/`) | All of the above, the HTTP tests, the stability harness | The tour at 390 and 1024 px in both themes, with the script off once |
| The scripts and styles (`public/`) | The harness, the behaviour suite, the Node tests | The tour, and the hand heard once on a plate |
| The plate's look | As the scripts, plus the docs' screens and `rake og:image` re-run and committed | The screens and the card looked at |
| The ladder's difficulty | The Ruby suite and the weathering experiments re-run, their README updated | One playtest session recorded in [playtest.md](playtest.md) |
| Docs only | The Ruby suite (it reads some of the docs' claims) and rubocop | Nothing |

A red check is never "waiting on review". A draft that drifts from master is merged forward,
never rebased over someone else's branch.

## Reading CI

Each job ends with the one line it proved, in the log and in the job summary: "206 runs, 0
failures", "Coverage 99.1 % (floor 97 %)", "372 checks, 0 moved, 0 page errors", "48 checks, 0
failed on chromium", the cryptanalysis' accuracies. A reviewer reads confidence from the
summaries without opening a log.
