# Going live: what is set by hand

Terraform (`infra/`) makes what it can. This is the rest: every setting made once, by hand, on
Google Cloud, GitHub and Cloudflare, in the order it is needed, and why each one is there. Done
in this order, the first deploy is the last step. [serving.md](serving.md) explains what the
pieces do; this is the checklist.

Three identities hold everything: your Google account (owner of the project), your GitHub
account (admin of the repository), your Cloudflare account (owner of the zone). Each is the way
in to its part of the site, so each gets two-factor authentication with a passkey or a hardware
key, not SMS, before anything below. Nothing else, no key, no password, is shared between them.

## 1. Google Cloud

**1.1 A project of its own**, on a billing account. Nothing else lives in it: the roles below
are the project's whole policy.

```
gcloud projects create PROJECT_ID
gcloud billing projects link PROJECT_ID --billing-account XXXXXX-XXXXXX-XXXXXX
gcloud config set project PROJECT_ID
gcloud auth application-default login     # what Terraform signs in with
```

**1.2 The state bucket**, the one thing Terraform cannot make for itself. The state holds the
front door's key (the one secret in it), so the bucket is private, versioned, and can never be
made public:

```
gcloud storage buckets create gs://STATE_BUCKET --project PROJECT_ID --location europe-west1 \
  --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets update gs://STATE_BUCKET --versioning
```

Who can read it is who has `roles/viewer` or more on the project (Viewer reads objects). Keep the
project's members to yourself: `gcloud projects get-iam-policy PROJECT_ID`.

**1.3 For the budget** (`billing_account_id` in `terraform.tfvars`): the account applying needs
*Billing Account Costs Manager* on the billing account (Billing, Account management, Add
principal). Without it, leave `billing_account_id` empty and set a budget in the console
instead (Billing, Budgets & alerts): 10 EUR a month, alerts at 50, 90 and 100 percent.

**1.4 Apply**, as the project owner:

```
cd infra
cp terraform.tfvars.example terraform.tfvars   # project_id; alert_email; the domain later (step 3)
terraform init -backend-config="bucket=STATE_BUCKET"
terraform apply
terraform output github_variables              # for step 2.3
```

**1.5 Where the security mail goes.** Google writes about abuse, outages and security to the
project's Essential Contacts; without one, to nobody:

```
gcloud essential-contacts create --email=you@example.com --notification-categories=SECURITY,BILLING,TECHNICAL,SUSPENSION
```

**1.6 If the project is in an organization** (otherwise skip), three organization policies cost
nothing and close doors the project never uses: `iam.disableServiceAccountKeyCreation` (no key
can be made for any account: the deployer is reached by federation alone),
`iam.automaticIamGrantsForDefaultServiceAccounts` (the default compute account stops being
Editor), `storage.publicAccessPrevention`. Do **not** enforce `iam.allowedPolicyMemberDomains`
on this project: the service is open to `allUsers`, which it would forbid.

## 2. GitHub (Settings of the repository)

**2.1 Actions, General.**

| Setting | Value | Why |
|---|---|---|
| Actions permissions | *Allow OWNER, and select non-OWNER, actions*: *Allow actions created by GitHub*, plus `ruby/setup-ruby@*`, `docker/*`, `google-github-actions/*`, `hashicorp/setup-terraform@*` | Only the nine actions the workflows name can run |
| Require actions to be pinned to a full-length commit SHA | on | The workflows pin every action to a commit (a tag can be moved: that is how trivy-action, actions-cool and others were turned against their users in 2026). This refuses a workflow that forgets |
| Fork pull request workflows | *Require approval for all external contributors* | A fork's pull request runs the Dockerfile and the test suite: nobody's code runs on your runners until you have read it |
| Workflow permissions | *Read repository contents and packages permissions*; *Allow GitHub Actions to create and approve pull requests* off | A workflow's token can write nothing; the workflows ask for `contents: read` and, for the deploy alone, `id-token: write` |

**2.2 Environments: `production`.**

- *Deployment branches and tags*: *Selected branches and tags*, `master`. A run of `deploy.yml`
  from any other branch never reaches the environment (and Google would refuse its token: the
  federation reads the branch too).
- *Environment variables*: the five that `terraform output github_variables` prints
  (`GCP_PROJECT_ID`, `GCP_REGION`, `GCP_SERVICE_ACCOUNT`, `GCP_WORKLOAD_IDENTITY_PROVIDER`,
  `SITE_URL`). Variables, not secrets: none of them is secret, and the deploy skips until they
  exist.
- *Required reviewers*: optional. With yourself as reviewer, every deploy waits for a click; a
  stolen GitHub session can then merge, but not ship.

**2.3 Rules, Rulesets: a branch ruleset on `master`.** Target the default branch; bypass list
empty, admins included (a stolen session of yours should not push to master either).

| Rule | Why |
|---|---|
| Restrict deletions, block force pushes | The history CI tested is the history that deployed |
| Require a pull request before merging | Nothing reaches master unread; Dependabot's updates included |
| Require status checks to pass: `test (3.3)`, `test (3.4)`, `test (4.0)`, `cryptanalysis`, `behaviour (chromium)`, `behaviour (firefox)`, `behaviour (webkit)`, `e2e (chromium)`, `e2e (firefox)`, `e2e (webkit)`, `stability`, `container`, `infra` | The deploy already waits for CI; this stops a red master from existing at all |
| Require signed commits | optional: a commit from your machine carries your key |

**2.4 Code security** (Settings, Advanced Security; free on a public repository): Dependabot
alerts and security updates on (the `dependabot.yml` schedules the version updates); secret
scanning and push protection on (a token pasted by mistake is refused at push); code scanning,
*default setup* (CodeQL reads the Ruby and the JavaScript on every pull request, no workflow
file needed); private vulnerability reporting on (a researcher writes to you, not to an issue).

**2.5 Your account**: two-factor with a passkey or hardware key; no classic personal access
tokens (fine-grained ones, scoped to this repository, if any); review SSH keys and authorized
applications (Settings, Applications) once.

## 3. Cloudflare

**3.1 The zone.** The domain on Cloudflare, nameservers switched at the registrar. Then, in the
zone: *DNS, Settings, DNSSEC*: enable, and put the DS record at the registrar. At the registrar:
transfer lock on, two-factor on. A domain is the site: with the name, an attacker serves a copy
of Inscribe and collects passphrases.

**3.2 The ids.** Zone *Overview*, right column, *API*: *Zone ID* and *Account ID*, into
`terraform.tfvars` as `cloudflare_zone_id` and `cloudflare_account_id`, with `domain`.

**3.3 The hostname is free.** The front door is a Workers custom domain, which makes the DNS
record itself and refuses a hostname that has one. Delete any A, AAAA or CNAME record on
`domain` first.

**3.4 An API token** (*My Profile, API Tokens, Create Token, Custom token*), never the Global
API Key:

| Scope | Permission |
|---|---|
| Account, Workers Scripts | Edit |
| Zone, Workers Routes | Edit |
| Zone, Zone WAF | Edit (the rate limit and the managed rules are rulesets) |
| Zone, Zone Settings | Edit (HTTPS forced, TLS 1.2) |
| Zone, DNS | Edit (the mail records, step 3.6) |
| Zone, Zone | Read |

*Account Resources*: the one account. *Zone Resources*: the one zone. *Client IP Address
Filtering*: your address. *TTL*: today. The token is used at apply and at nothing else; give it
to the shell for the apply only, and let it expire:

```
read -rs CLOUDFLARE_API_TOKEN && export CLOUDFLARE_API_TOKEN   # not on the command line: the shell's history keeps that
terraform apply
unset CLOUDFLARE_API_TOKEN
```

**3.5 The managed rules.** Terraform deploys Cloudflare's *Free Managed Ruleset* on the zone
(`managed_waf`). If *Security, WAF, Managed rules* already shows it deployed, Terraform cannot
make a second one: import it first, or set `managed_waf = false`.

```
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/ZONE_ID/rulesets" \
  | jq -r '.result[] | select(.phase == "http_request_firewall_managed") | .id'
terraform import 'cloudflare_ruleset.managed_waf[0]' zone/ZONE_ID/RULESET_ID
```

**3.6 Mail.** By default Terraform tells the world the domain sends no mail (a null MX, SPF
`-all`, DMARC `p=reject`): a message forged in the site's name, asking for a passphrase, is
refused by every receiver that checks. If you do send mail from the domain, set
`domain_sends_mail = true` and publish your own SPF and DMARC.

**3.7 Bot Fight Mode** (*Security, Bots*) is left off on purpose: it challenges every request
that looks scripted, and the deploy's smoke test is `curl`. Turn it on if you accept that the
smoke test then fails, or point `SITE_URL` elsewhere.

**3.8 Notifications** (*Notifications*, at the account): add *Workers* usage alerts and the
*Security Events* digest, to your address.

## 4. The first deploy, and what to check

1. *Actions, Deploy, Run workflow* on `master`, or merge to master. The job builds, pushes,
   deploys and smoke-tests through the front door.
2. From anywhere:

   ```
   deploy/smoke.sh https://DOMAIN                       # every page answers, HSTS is on
   curl -sI https://SERVICE-xxxx.a.run.app/ | head -1   # 403: the back door is shut
   curl -sI https://SERVICE-xxxx.a.run.app/up | head -1 # 200: the probes' door is open
   curl -sI -X PUT https://DOMAIN/ | head -1            # 405: refused at the edge
   for i in $(seq 12); do curl -so /dev/null -w '%{http_code} ' -d message=x https://DOMAIN/generate; done
                                                        # the last ones 429: the rate limit
   dig +short MX DOMAIN; dig +short TXT _dmarc.DOMAIN   # "0 ." and the DMARC record
   ```
3. The logs, if something is wrong: `gcloud run services logs read cistergraphia --region
   europe-west1 --limit 50`.

## 5. What holds a secret, and where

| Secret | Where it lives | Who can read it | Rotation |
|---|---|---|---|
| The front door's key | Secret Manager; the Terraform state; the Worker's secret binding | The runtime account (its one role); readers of the state bucket; the Cloudflare account | `terraform taint 'random_password.front_door_key[0]' && terraform apply`, then one deploy |
| Your Cloudflare API token | Your shell, during an apply | You | Expires the day it is made; make the next one for the next apply |
| Your Google credentials | `gcloud` on your machine | You | `gcloud auth revoke` |
| GitHub | nothing: the deploy proves who it is with a token GitHub mints per run | | |

## 6. Routine

- **Dependabot's pull requests**, weekly: gems (with the lockfile's checksums), the base image
  (tag and digest), the actions (commit and version), the providers. CI proves each; the ruleset
  makes you merge them.
- **A security release of Ruby** arrives as a new base image digest the same way; of a gem, as a
  Dependabot security update; a failing Trivy scan in CI names what neither has caught up with.
- **The budget's mail**, and the kill switch: `gcloud run services update cistergraphia --region
  europe-west1 --ingress internal` closes the service in seconds.
- **Once a quarter**: `gcloud projects get-iam-policy PROJECT_ID`, the repository's collaborators
  and applications, the Cloudflare account's members and tokens.
