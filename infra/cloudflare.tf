# The front door, when a domain is given: Cloudflare in front of Cloud Run.
#
# Cloud Run routes by the Host header, and a request for the domain carries
# the domain: sent straight to the service it would be a 404, and rewriting
# the Host at Cloudflare is an Enterprise feature. So the domain is a
# Worker's (worker.js): it re-addresses each request to the service's own
# run.app host, keeps the method, the headers and the body, and names the
# domain the reader used in X-Forwarded-Host, which the app's links read.
#
# With Cloudflare in front come the things Cloud Run has not on its own
# short of a load balancer: a rate limit on the posts (the one rule the free
# plan includes), HTTPS forced, TLS 1.2 at least, the pages and the static
# files cached at the edge. And the Worker shows the service a key that the
# service demands (gcp.tf): the run.app address is no way around any of it.

locals {
  fronted     = var.domain != "" ? 1 : 0
  origin_host = trimprefix(google_cloud_run_v2_service.web.uri, "https://")
}

resource "cloudflare_workers_script" "front_door" {
  count = local.fronted

  account_id         = var.cloudflare_account_id
  script_name        = var.service_name
  content            = file("${path.module}/worker.js")
  main_module        = "worker.js"
  compatibility_date = "2025-01-01"

  bindings = [
    {
      name = "ORIGIN_HOST"
      type = "plain_text"
      text = local.origin_host
    },
    {
      name = "FRONT_DOOR_KEY"
      type = "secret_text"
      text = random_password.front_door_key[0].result
    },
  ]
}

resource "cloudflare_workers_custom_domain" "site" {
  count = local.fronted

  account_id = var.cloudflare_account_id
  zone_id    = var.cloudflare_zone_id
  hostname   = var.domain
  service    = cloudflare_workers_script.front_door[0].script_name
}

# The posts: a plate inscribed (/generate), read (/decode), or its notebook
# asked about (/ask). Each holds a core for up to 1.3 s and answers with the
# plate's page, and a run of them from one address is the cheap way to tie
# the service up and run its egress bill. A reader makes a few a minute; ten
# in ten seconds is a script. (The pages a GET gives are served from the
# edge cache, at no cost to the service: worker.js)
resource "cloudflare_ruleset" "rate_limit_posts" {
  count = local.fronted

  zone_id     = var.cloudflare_zone_id
  name        = "Cistergraphia: the posts, per address"
  description = "A plate inscribed, read or asked about: ${var.rate_limit_posts_per_10s} in ten seconds from one address, then blocked for ten"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [{
    action      = "block"
    description = "Posts to /generate, /decode and /ask"
    enabled     = true
    expression  = "(http.request.method eq \"POST\" and http.request.uri.path in {\"/generate\" \"/decode\" \"/ask\"})"
    ratelimit = {
      characteristics     = ["ip.src", "cf.colo.id"]
      period              = 10
      requests_per_period = var.rate_limit_posts_per_10s
      mitigation_timeout  = 10
    }
  }]
}

# A passphrase travels in the request: never over plain HTTP, never over old TLS
resource "cloudflare_zone_setting" "always_https" {
  count = local.fronted

  zone_id    = var.cloudflare_zone_id
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "min_tls" {
  count = local.fronted

  zone_id    = var.cloudflare_zone_id
  setting_id = "min_tls_version"
  value      = "1.2"
}

# Cloudflare's Free Managed Ruleset: the rules against what is widely
# exploited (Log4j, Shellshock, the known scanners), the one managed ruleset
# the free plan deploys. Not a defence the app relies on, a filter that costs
# nothing in front of it. A zone that already has it must import it first
# (docs/going-live.md): a phase has one entry point ruleset
resource "cloudflare_ruleset" "managed_waf" {
  count = local.fronted * (var.managed_waf ? 1 : 0)

  zone_id     = var.cloudflare_zone_id
  name        = "Cistergraphia: managed WAF"
  description = "Cloudflare Free Managed Ruleset on every request"
  kind        = "zone"
  phase       = "http_request_firewall_managed"

  rules = [{
    ref         = "free_managed_ruleset"
    description = "Cloudflare Free Managed Ruleset"
    expression  = "true"
    action      = "execute"
    action_parameters = {
      id = "77454fe2d30c4220b5701f6fdfb893ba"
    }
  }]
}

# The domain sends no mail, and says so: a receiver that checks refuses a
# message forged in the site's name (a passphrase asked for by "the abbey").
# No MX (the null MX of RFC 7505), SPF that allows no sender, DMARC that
# rejects. Skipped when domain_sends_mail is set
locals {
  mail_locked = local.fronted == 1 && !var.domain_sends_mail ? 1 : 0
}

resource "cloudflare_dns_record" "null_mx" {
  count = local.mail_locked

  zone_id  = var.cloudflare_zone_id
  name     = var.domain
  type     = "MX"
  content  = "."
  priority = 0
  ttl      = 3600
}

resource "cloudflare_dns_record" "spf" {
  count = local.mail_locked

  zone_id = var.cloudflare_zone_id
  name    = var.domain
  type    = "TXT"
  content = "\"v=spf1 -all\""
  ttl     = 3600
}

resource "cloudflare_dns_record" "dmarc" {
  count = local.mail_locked

  zone_id = var.cloudflare_zone_id
  name    = "_dmarc.${var.domain}"
  type    = "TXT"
  content = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s\""
  ttl     = 3600
}
