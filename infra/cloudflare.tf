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
