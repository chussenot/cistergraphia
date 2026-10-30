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
reads, HTTPS included, and a free tier that covers a game's traffic. With a domain, Cloudflare
stands in front of it. The pieces:

| Piece | What it does |
|---|---|
| `Dockerfile` | The app under Puma on port 8080, as a user with no privileges, without the development and test gems |
| `infra/` | Terraform: the Google Cloud project (APIs, the image repository, two service accounts, the federation that lets GitHub deploy without a key, the service itself, a budget and alerts) and, with a domain, the Cloudflare front door and the key the service demands behind it |
| `deploy/smoke.sh BASE_URL` | Asks every page of a served Cistergraphia and fails at the first wrong answer. CI runs it against the container; the deploy runs it against the live service |
| `.github/workflows/ci.yml` | Job `container` builds the image, runs the smoke test on it and scans it for known vulnerabilities; job `infra` checks the Terraform's format and validity against the providers' schemas and scans it for misconfigurations |
| `.github/workflows/deploy.yml` | After CI passes on master: builds the image, pushes it to Artifact Registry, deploys it as a new revision, runs the smoke test on the result |

**Who owns what.** Terraform owns the shape of the service: CPU, memory, concurrency, scaling,
the account it runs as, its environment. The Deploy workflow changes one thing, the image: it
deploys a new revision with the image alone, and every other setting carries over. So the image
is the one attribute Terraform ignores (`lifecycle.ignore_changes`), and the workflow refuses to
run against a service Terraform did not make.

### Once: the project

1. **A bucket for the state**, once, by hand (the one thing Terraform cannot make for itself):
   ```
   gcloud storage buckets create gs://STATE_BUCKET --project PROJECT_ID --location europe-west1 \
     --uniform-bucket-level-access --public-access-prevention \
     && gcloud storage buckets update gs://STATE_BUCKET --versioning
   ```
2. **Apply**, as a project owner signed in to `gcloud` (`gcloud auth application-default login`):
   ```
   cd infra
   cp terraform.tfvars.example terraform.tfvars   # and fill it in
   terraform init -backend-config="bucket=STATE_BUCKET"
   terraform apply
   ```
3. **Make a `production` environment** on the repository (Settings, Environments) with a
   deployment branch rule allowing `master` only, and **set the five variables** that
   `terraform output github_variables` prints on it. The Deploy workflow runs once they exist.
4. **Deploy once by hand** (Actions, Deploy, Run workflow), or merge to master. Until then the
   service runs Google's hello image.

Every setting made by hand, on the three accounts, with the checks to run afterwards:
[going-live.md](going-live.md).

What Terraform makes, and why:

- **The runtime service account has no role.** The app calls no Google API, so it needs none. The
  default compute account has Editor on the whole project, and a server that reads uploaded files
  must not run as it.
- **The deployer can do three things:** push to the one image repository, deploy a revision of the
  one service (`roles/run.developer` on the service, not the project), and let the service run as
  the runtime account. GitHub Actions becomes it only from this repository, with its OpenID
  token. No key exists.
- **GitHub becomes the deployer only from the Deploy workflow on `master`**: the OpenID token names
  the workflow file and the branch, and the federation's condition reads both. A workflow on any
  other branch, or any other workflow, gets nothing. The repository is matched by its numeric id
  and its owner's, not only by its name: a name can be given up and claimed by someone else,
  whose token would then carry it; an id is never reused.
- **The image repository keeps the ten most recent images**, drops any older than thirty days (an
  image is about 150 MB, and storage is billed), and never lets a tag be rewritten: what CI tested
  is what runs.
- **A budget and two alerts**, when `alert_email` (and, for the budget, `billing_account_id`) is
  set: warnings at half, nine tenths and the line of `monthly_budget` (10 EUR), by spend and by
  forecast; an alert when the service answers with errors; an alert when every instance has been
  busy for five minutes, which is success or abuse. The budget warns and stops nothing: the caps
  are below.
- **The service:**

  | Setting | Value | Why |
  |---|---|---|
  | CPU, memory | 1 vCPU, 512 MiB | A request is CPU-bound Ruby for up to 1.3 s. Half a vCPU would double it. A worker uses under 300 MB with the largest plate |
  | Concurrency | 3 | Matches `PUMA_THREADS=3`: three requests share the one vCPU inside Puma before a second instance starts |
  | Instances | 0 to 3 | None when nobody reads: the first reader of the day starts one (3 to 5 s, with CPU boost). Three at most: the bill is bounded |
  | CPU | only while a request runs, boosted at startup | An idle instance costs nothing; a cold start is shorter |
  | Timeout | 60 s | The slowest request is under 2 s |
  | Probes | `/up`, at start and every 30 s | A revision takes traffic only once it answers; an instance that stops answering is replaced |
  | Access | public | |
  | Deletion protection | off | Nothing is stored in the service: a destroy loses no plate |

**Cost.** Request-based billing, with the free tier of 180,000 vCPU-seconds, 360,000 GiB-seconds
and 2 million requests a month. At about one vCPU-second per plate read, that is roughly 150,000
plate reads a month before the first cent. Three instances running flat out all month would cost
about $190, which is what `max_instance_count = 3` bounds. Region: `europe-west1` is tier 1
pricing; Paris (`europe-west9`) is tier 2.

**The day's chapter** is drawn by each instance on its first request for it (0.1 to 0.6 s) and
kept in memory. With instances that come and go, that happens a few times a day. It is the same
plate every time: the drawing is seeded by the date.

**Rollback:** `gcloud run services update-traffic cistergraphia --region europe-west1
--to-revisions REVISION=100`. Every deploy is a revision; `gcloud run revisions list` names them.

**A deploy by hand**, from a signed-in machine, without the workflow:
`gcloud run deploy cistergraphia --image IMAGE --region europe-west1`, or with `--source .` to
build the same Dockerfile with Cloud Build (`.gcloudignore` keeps the upload to what it needs).

### The front door: a domain on Cloudflare

Set `domain`, `cloudflare_account_id` and `cloudflare_zone_id` in `terraform.tfvars`, put a
Cloudflare API token in `CLOUDFLARE_API_TOKEN`, and apply again. The token needs, on the zone:
Workers Scripts (edit), Workers Routes (edit), Zone WAF (edit), Zone Settings (edit), Zone (read).

- **Why a Worker.** Cloud Run routes by the Host header, and a request for the domain carries the
  domain: sent straight to the service it would be a 404, and rewriting the Host at Cloudflare is
  an Enterprise feature. So the domain is a Worker's (`infra/worker.js`): it re-addresses each
  request to the service's own `run.app` host, as it came (method, headers, body), and names the
  domain the reader used in `X-Forwarded-Host`, which the app's links (`og:url`) read. The free
  plan's 100,000 Worker requests a day are far more than the game sees.
- **The rate limit** the section below asks for: posts to `/generate`, `/decode` and `/ask`, ten in
  ten seconds from one address, then blocked for ten (`rate_limit_posts_per_10s`). A reader makes
  a few a minute; ten in ten seconds is a script. It is the one rule the free plan includes.
- **HTTPS is forced** on the zone, and TLS 1.2 at least: a passphrase travels in the request.
- **Cloudflare's Free Managed Ruleset** runs on every request (`managed_waf`): the rules against
  what is widely exploited, a filter the app does not rely on, at no cost in front of it.
- **The domain sends no mail, and says so** (a null MX, SPF `-all`, DMARC `p=reject`, unless
  `domain_sends_mail`): a message forged in the site's name, asking a reader for a passphrase,
  is refused by every receiver that checks.
- **The door drops the query string of a GET** (except on the chapter's pages, whose board reads
  `rejoined=1`): no other page reads one, so `?x=1`, `?x=2`, ... would only be as many cache
  misses, each a request the service has to answer.
- **The back door is shut.** Behind a front door, the service answers only requests that show the
  door's key (`web/front_door.rb`): the Worker adds it to every request, the service reads it from
  Secret Manager, and its own `run.app` address answers 403 to everyone else. So the rate limit,
  the body limit and the edge cache cannot be walked around. `/up` stays open for the probes. The
  Deploy workflow smoke-tests through the door (`SITE_URL`). To rotate the key:
  `terraform taint 'random_password.front_door_key[0]' && terraform apply`, then deploy once (a new
  revision reads the new version).
- **The door refuses** what the app has no use for before Cloud Run is asked: methods other than
  GET, HEAD and POST, and bodies over 3 MB.
- **The pages are served from the edge.** The leaves (Inscribe, Read, About) say they may be kept
  five minutes, the day's chapter until midnight, the static files an hour; the Worker lets
  Cloudflare keep them. A page served from the edge costs the service nothing, in CPU or in egress.
  The pages that carry a plate are `no-store` and never kept.
- **A daily allowance.** The free plan serves 100,000 Worker requests a day, then answers errors
  until midnight UTC. For a game that is far more than a day sees, and it is also the one cap the
  edge puts on what reaches the service in a day.

Without a domain, none of this is made, and the site is its `run.app` address.

### Changing the infrastructure

Edit `infra/`, `terraform plan`, read the plan, `terraform apply`. CI checks the format and the
validity of every change against the providers' schemas and scans it for misconfigurations; it
never plans or applies, so the credentials stay on your machine. The lock file
(`infra/.terraform.lock.hcl`) pins the providers; update it with `terraform init -upgrade` on
purpose, or let Dependabot propose it.

### Security: what is protected, and from what

The code is public; the site must be safe with every line of its deployment read. What an
attacker can see is also what they cannot use:

| They can | They cannot | Because |
|---|---|---|
| Read the workflows and the Terraform | Deploy, or run anything as the project | No key exists. The deployer is a Google account that only a run of `deploy.yml` on `master` of this repository can become, and the pool's condition says so |
| Open a pull request from a fork | Have it deployed | The deploy runs on CI runs that were master's own push, never a pull request's; a fork's workflow has no identity token anyway |
| Push a commit to `master` (with write access) | Deploy an untested image | The deploy waits for CI to pass; an image tag, once pushed, is never rewritten |
| Find the `run.app` address (it is in the public logs) | Reach the service around the front door | It answers nothing without the door's key |
| Post plates in a loop | Run up the bill | Ten posts in ten seconds per address at the edge; `max_instances` on the service; the Worker's daily allowance; the budget's warnings |
| Post a 32 MB body | Make the service read it | Refused by its length at the door (3 MB) and at the service (2 MB and a little) before a byte is parsed |
| Take over a dependency | Ship it unnoticed | Dependabot proposes updates, CI tests them, and Trivy refuses an image with a fixable high or critical vulnerability |
| Move a tag of an action, a base image, a scanner image | Run their code in the workflows | Every action is pinned to a commit, the base image and Trivy's image to a digest, every gem to the checksum in `Gemfile.lock`; Dependabot moves the pins, CI proves them |
| Delete and re-register the repository's name, or the owner's | Become the deployer with the new repository's token | The federation matches the repository's and the owner's numeric ids, which are never reused |
| Send mail in the site's name | Have it delivered | The zone publishes that the domain sends no mail (null MX, SPF `-all`, DMARC `p=reject`) |
| Ask for a page with a changing query string | Miss the edge cache every time | The door drops the query string of every GET but the chapter's |
| Read the Terraform state | Learn more than the door's key | Keep the bucket private: the key is the one secret in it. The Cloudflare token and the Google credentials never enter it |

What the app itself does, wherever it runs: a strict Content-Security-Policy (first-party only),
no referrer, `nosniff`, no camera or microphone, HSTS once over HTTPS, `no-store` on every page
that carried a message or a passphrase, a 500-character limit on messages and 2 MB on plates, and
no record of any message anywhere ([security-study.md](security-study.md) covers the cipher).

**The kill switch.** If the budget's warning comes and the service is being abused:
`gcloud run services update cistergraphia --region europe-west1 --ingress internal` closes it to
the internet in seconds and costs nothing; `--ingress all` reopens it. Or set `max_instances = 1`
and apply.

**Read as an attacker would**, with the deployment's code in hand, the ways in were these, and
what each meets:

- *A shell on a CI runner* is had for the asking: a pull request from a fork runs the Dockerfile
  and the suites. It meets a runner with no secret, a token that can only read, no identity token
  (`id-token: write` is the deploy's alone), and a cache scope of its own. The deploy runs only
  on master's own pushes. What would make a runner worth having is a tag of an action moved to
  other code, which is why every action is a commit now; or a gem or an npm package replaced,
  which the lockfile's checksums refuse (`npm install --ignore-scripts` runs nothing of
  Playwright's at install).
- *Code in the Ruby app* has no door: no `eval`, `system`, `Marshal` or `YAML.load` of anything
  a request brings; the one `public_send` dispatches on a layout name checked against a list;
  REXML reads the plate without external entities and under its expansion limits; JSON is parsed,
  never evaluated; the templates are the app's own files. What a request can do is cost CPU for
  up to 1.3 s, which the rate limit, `max_instances` and the budget bound. The gems in
  `Gemfile.lock` have no open advisory (`bundler-audit`, checked at review; Dependabot and Trivy
  keep checking).
- *The Cloudflare account* is reached through its login or an API token. The token Terraform uses
  exists for the apply, scoped to the one zone, limited to your address, expiring the same day
  (going-live.md). The state holds the Worker's secret binding (the door's key), not the token.
  The domain itself is the larger prize: with the name, a copy of Inscribe collects passphrases;
  hence DNSSEC, the registrar's lock, and two-factor on the three accounts.
- *The Google project* is reached through the federation (a run of `deploy.yml` on `master`, of
  this repository by id), or through a reader of the state bucket, who learns the door's key and
  nothing more. The deployer can deploy a revision of the one service and push to the one
  repository; the service runs as an account that can read one secret.

**What only you can set**, on GitHub, Google Cloud and Cloudflare, is listed in
[going-live.md](going-live.md): the branch ruleset, the `production` environment's branch rule,
the Actions policies (pinned actions required, fork runs approved, read-only tokens), secret
scanning and push protection, code scanning; the state bucket's access; DNSSEC, the registrar's
lock, the API token's scope and expiry.

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
