# Cistergraphia's infrastructure, as code (docs/serving.md): the Google Cloud
# project that serves it and, when a domain is given, the Cloudflare front
# door. Apply it once by hand; the Deploy workflow then only ships images.
#
#   cd infra
#   terraform init -backend-config="bucket=STATE_BUCKET"
#   terraform apply -var project_id=PROJECT_ID [-var domain=cistergraphia.example ...]

terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # The state in a bucket of the project (make it once: docs/serving.md),
  # named at init: terraform init -backend-config="bucket=STATE_BUCKET"
  backend "gcs" {
    prefix = "cistergraphia"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Signed in with CLOUDFLARE_API_TOKEN in the environment (docs/serving.md
# lists the token's permissions); used only when a domain is given
provider "cloudflare" {}
