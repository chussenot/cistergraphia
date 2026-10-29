variable "project_id" {
  description = "The Google Cloud project that serves the site"
  type        = string
}

variable "region" {
  description = "Where the service and its images live. Belgium is tier 1 pricing; Paris (europe-west9) is tier 2"
  type        = string
  default     = "europe-west1"
}

variable "service_name" {
  description = "The Cloud Run service, the image repository and the service accounts are named after it"
  type        = string
  default     = "cistergraphia"
}

variable "github_repository" {
  description = "The one repository whose Deploy workflow may deploy, as owner/name"
  type        = string
  default     = "chussenot/cistergraphia"
}

variable "domain" {
  description = "The site's domain on Cloudflare, served through the front door (a Worker). Empty: no Cloudflare, the run.app address only"
  type        = string
  default     = ""

  validation {
    condition     = var.domain == "" || (var.cloudflare_account_id != "" && var.cloudflare_zone_id != "")
    error_message = "A domain needs cloudflare_account_id and cloudflare_zone_id: the zone the domain is in, and the account that holds it."
  }
}

variable "cloudflare_account_id" {
  description = "The Cloudflare account the Worker is deployed to (Overview of the zone, API section)"
  type        = string
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "The Cloudflare zone of the domain (Overview of the zone, API section)"
  type        = string
  default     = ""
}

variable "rate_limit_posts_per_10s" {
  description = "Posts (a plate inscribed, read or asked about) one address may make in ten seconds before Cloudflare blocks it for ten; a reader makes a few a minute"
  type        = number
  default     = 10
}
