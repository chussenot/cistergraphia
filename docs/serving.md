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

## Deploying to Cloud Run

The site runs on Google Cloud Run, in `europe-west1`: one container per instance, none when nobody
reads, HTTPS included, and a free tier that covers a game's traffic. The pieces:

| Piece | What it does |
|---|---|
| `Dockerfile` | The app under Puma on port 8080, as a user with no privileges, without the development and test gems |
| `deploy/smoke.sh BASE_URL` | Asks every page of a served Cistergraphia and fails at the first wrong answer. CI runs it against the container; the deploy runs it against the live service |
| `deploy/gcp-setup.sh` | Everything a Google Cloud project needs, once (below) |
| `.github/workflows/ci.yml`, job `container` | Builds the image and runs the smoke test on every change, so a broken image never reaches the deploy |
| `.github/workflows/deploy.yml` | After CI passes on master: builds the image, pushes it to Artifact Registry, deploys it, runs the smoke test on the result |

### Once: the project

```
PROJECT_ID=my-project deploy/gcp-setup.sh
```

Run it as an owner of the project, signed in to `gcloud`. It enables the APIs, makes the Artifact
Registry repository, two service accounts and the Workload Identity Federation that lets the
workflow deploy without any stored key, and prints five repository variables to set on GitHub.
Running it again only adds what is missing.

- **The runtime service account has no role.** The app calls no Google API, so it needs none. The
  default compute account has Editor on the whole project, and a server that reads uploaded files
  should not run as it.
- **The deployer can do three things:** deploy to Cloud Run, push to the one repository, and act as
  the runtime account. It can be used only by GitHub Actions running from this repository
  (`assertion.repository == 'chussenot/cistergraphia'`).
- **No key exists.** The workflow proves who it is with its OpenID token. Nothing to rotate, nothing
  to leak.

### Every deploy

A merge to master runs CI; when CI is green, Deploy ships it. The service is deployed with:

| Setting | Value | Why |
|---|---|---|
| CPU, memory | 1 vCPU, 512 MiB | A request is CPU-bound Ruby for up to 1.3 s. Half a vCPU would double it. A worker uses under 300 MB with the largest plate |
| Concurrency | 3 | Matches `PUMA_THREADS=3`: three requests share the one vCPU inside Puma before a second instance starts |
| Instances | 0 to 3 | None when nobody reads: the first reader of the day starts one (3 to 5 s, with CPU boost). Three at most: the bill is bounded |
| Timeout | 60 s | The slowest request is under 2 s |
| Startup CPU boost | on | A faster cold start, for nothing while idle |
| Access | public, runtime account with no role | |

**Cost.** Request-based billing, with the free tier of 180,000 vCPU-seconds, 360,000 GiB-seconds
and 2 million requests a month. At about one vCPU-second per plate read, that is roughly 150,000
plate reads a month before the first cent. Three instances running flat out all month would cost
about $190, which is what `--max-instances=3` bounds. Region: `europe-west1` is tier 1 pricing and
supports domain mappings; Paris (`europe-west9`) is tier 2 and does not.

**The day's chapter** is drawn by each instance on its first request for it (0.1 to 0.6 s) and
kept in memory. With instances that come and go, that happens a few times a day. It is the same
plate every time: the drawing is seeded by the date.

**Rollback:** `gcloud run services update-traffic cistergraphia --region europe-west1
--to-revisions REVISION=100`. Every deploy is a revision; `gcloud run revisions list` names them.

**A deploy by hand**, from a signed-in machine, without the workflow:
`gcloud run deploy cistergraphia --source . --region europe-west1`. It builds the same Dockerfile
with Cloud Build and uploads only what `.gcloudignore` allows.

### A domain, and the rate limit

Cloud Run gives `https://cistergraphia-….run.app`. For a domain of your own, map it in Cloud Run
(Domain mappings, free, a Google-managed certificate; `europe-west1` supports it), then put
Cloudflare's free plan in front, proxied: it caches the static files, hides the origin, and its one
free rate-limiting rule is where the limits under "What to put in front" go. Cloud Run has no rate
limiting of its own short of a load balancer and Cloud Armor, which cost more than the app.

## What a request costs

Measured in-process (Rack::Test, production templates, one core) on plates of 100 and 500
letters. The 500-letter plate is the form's limit, and its SVG is about 0.8 MB.

| Request | 100 letters | 500 letters |
|---|---|---|
| Any page (Inscribe, Read, About) | under 10 ms | — |
| `POST /generate` (inscribe) | 0.15–0.4 s | 0.25–1.2 s (broken and ruined are the slowest) |
| `POST /decode`, the puzzle (desk, bench, board) | 0.19–0.24 s | 0.6–0.8 s |
| `POST /decode`, deciphered | 0.14–0.23 s | 0.5–0.73 s |
| `POST /decode`, a ruined plate rejoined (the bench after the board) | 0.39 s | 1.3 s |

Each figure is for a plate the server has not seen: the cache is cleared before every request.

Where the time goes, for the largest plate:

| Part | Cost |
|---|---|
| Parsing the file (REXML), once per request | about 0.25 s |
| Rack reading the posted form (0.8 MB) | about 0.1 s |
| Cleaning the file for the page (`PlateFile.clean`) | about 0.1 s |
| Laying the puzzle (the survey, the fragments, the way) | 0.1–0.3 s |

**One parse per request.**
- `SVG::Parsed` keeps the document of the file last parsed on the thread. The cleaner, the
  grille's test, the lines, the fragments and the way all read it.
- The app forgets it after every request, so nothing of a reader's plate stays in memory.
- A ruined plate rejoined parses twice. It draws a new plate from the fragments, and that plate
  has to be cleaned too.
- `test/app_test.rb` holds every kind of plate to that count.
- The history: a worn 500-letter plate took 5.4 s when it was parsed 15 times, and 1.3 s at two
  parses.

**Faster still would mean another parser.** Nokogiri, a C extension, parses the same plate in
12 ms instead of 230 ms. That would take about 0.2 s more off each request (25 to 30%), at the
cost of a compiled dependency, libxml2's security surface, and a rewrite of every place that
reads XML. It is not worth it at these costs. Reconsider if the POST routes become the bottleneck
at real traffic.

**Limits that bound the cost:**
- A message is limited to 500 characters, 250 for each message of a two-reader plate.
- An SVG is limited to 2 MB (`MAX_SVG_BYTES`): 413 above that.
- REXML refuses entity expansion bombs (its own limits).

**What to put in front:** a request can hold a core for up to 1.3 s, and a sustained run of
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
