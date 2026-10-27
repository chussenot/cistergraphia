# Serving: running Cistergraphia for others

What a server running Cistergraphia needs, what a request costs, what is logged, and what to do
when it slows down. On your own machine, `bundle exec rackup` is enough. This page is for a server
that other people use.

## What it needs

- **Ruby 3.2 or later.** 4.0 is pinned in `mise.toml`, and CI runs 3.3, 3.4 and 4.0.
  `BUNDLE_WITHOUT=development:test bundle install`.
- **HTTPS, always.** A sealed message and its passphrase travel in the request. The app never
  stores them, but without TLS anyone on the path can read them. Put the app behind a proxy or a
  platform that terminates TLS.
- **Nothing else.** No database, no cache server, no third-party script: every asset is
  first-party, and the Content-Security-Policy says so.

## Starting it

```
RACK_ENV=production bundle exec puma           # reads config/puma.rb
```

| Variable | Default | What it sets |
|---|---|---|
| `PORT` | 9292 | The port, as platforms set it (`-b` or `rackup -p` take precedence) |
| `WEB_CONCURRENCY` | 0 (one process) | Worker processes: about one per core |
| `PUMA_THREADS` | 3 | Threads per process |
| `RACK_ENV` | development | `production`: templates compiled once, no reloading |

Reading and inscribing plates is CPU work in Ruby. The threads of one process share a core (the
GVL), so **cores are used by workers, not threads**. On a 4-core machine, start with
`WEB_CONCURRENCY=4 PUMA_THREADS=3`. Three threads per worker let pages keep flowing while one
large plate is being read, and a burst of heavy reads waits in the queue instead of slowing
every page down.

**Health check:** `GET /up` answers `up` (200, never cached). It does not read a plate: a check
that did would fail on a busy server and restart it for being busy.

## What a request costs

Measured in-process (Rack::Test, production templates, one core) on plates of 100 and 500
letters. The 500-letter plate is the form's limit, and its SVG is about 0.8 MB.

| Request | 100 letters | 500 letters |
|---|---|---|
| Any page (Inscribe, Read, About) | under 10 ms | — |
| `POST /generate` (inscribe) | 0.15–0.4 s | 0.25–1.2 s (broken and ruined are the slowest) |
| `POST /decode`, the puzzle (desk, bench, board) | 0.3–0.5 s | 1.1–1.8 s (ruined and expert are the slowest) |
| `POST /decode`, deciphered | 0.15–0.3 s | 0.45–0.95 s |

The floor is parsing: REXML reads a 0.8 MB plate in about half a second.
- A request parses its file twice: once to clean it for the page (`PlateFile.clean`), and once
  to read its lines (`SVG.layers`, kept per thread). Every later step reuses that second parse.
- `test/app_test.rb` holds the request to those two parses.
- Before this was in place, a worn 500-letter plate took 5.4 s, because it was parsed 15 times.

**Limits that bound the cost:**
- A message is limited to 500 characters, 250 for each message of a two-reader plate.
- An SVG is limited to 2 MB (`MAX_SVG_BYTES`): 413 above that.
- REXML refuses entity expansion bombs (its own limits).

**What to put in front:** a request can hold a core for up to 1.8 s, and a sustained run of
them is a cheap way to tie a server up. Rate-limit the three POST routes at the proxy, per
address:

| Route | Suggested limit |
|---|---|
| `POST /generate` | 20 a minute |
| `POST /decode` | 20 a minute |
| `POST /ask` (the notebook's scribe: small, but posts the file) | 60 a minute |

The GET pages cost nothing worth limiting. A reader works on a page for minutes, so these limits
never meet a person.

## What is logged

One line per request (Rack's CommonLogger): address, time, method, path and query string,
status, size and duration.
- **No request body is logged.** Messages, passphrases, grille keys and plates travel in POST
  bodies and never reach the log.
- Nothing is stored either: a plate exists in the response and nowhere else.
- Backtraces of real bugs go to the log. The reader sees only the Erratum page ("Something
  unexpected happened").

Keep the proxy's logs to the same rule. A proxy that logs request bodies would log secrets.

## Caching

| What | Cache-Control |
|---|---|
| Scripts, styles, fonts, images | `public, max-age=3600` |
| Anything posted | `no-store` |
| `/up` | `no-store` |
| Pages | none (the browser revalidates) |

A CDN in front may keep the static files. It must never keep a POST response.

## When something goes wrong

| Symptom | Likely cause | What to do |
|---|---|---|
| Pages slow for everyone, CPU at 100 % | A run of large plates posted (`POST /decode` or `/generate` taking 1 s or more in the log) | Rate-limit the POST routes at the proxy (above). Add workers if the cores allow. |
| Memory grows per worker | Large plates parsed: a 0.8 MB plate's tree is about 10 MB while it is read. Each thread keeps only the lines of its last file (small) | A worker settles at a few hundred MB at most under load. If it keeps growing past that, restart workers and report it as a bug. |
| 413 "SVG is limited to 2048 KB" | A file larger than any plate the app makes | Nothing to do: no plate is that large. |
| 400 Erratum on a real plate | The file was changed after it was made (an editor re-saved it) | Ask for the file as it was downloaded. |
| `/up` fails | The process is down or stuck at boot | Read the log from the start. A failed `bundle install` is the usual cause. |
