# The Google Cloud side: the APIs, the image repository, two service accounts,
# the federation that lets GitHub Actions deploy without a key, the Cloud Run
# service itself, and its door open to everyone.
#
# Terraform owns the service's shape (CPU, memory, concurrency, scaling, the
# account it runs as, its environment). The Deploy workflow owns only which
# image runs: it deploys a new revision with the image alone, and every other
# setting carries over. So the image is the one thing Terraform ignores.

locals {
  apis = [
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ]
}

resource "google_project_service" "api" {
  for_each = toset(local.apis)

  service            = each.value
  disable_on_destroy = false
}

# ---------- The images ----------

# One image per deploy, tagged with its commit. The ten most recent are kept;
# older ones go: a plate's image is about 150 MB, and storage is billed
resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = var.service_name
  format        = "DOCKER"
  description   = "Cistergraphia images, pushed by the Deploy workflow"

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-ten"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "drop-old"
    action = "DELETE"
    condition {
      older_than = "2592000s" # 30 days
    }
  }

  depends_on = [google_project_service.api]
}

# ---------- The accounts ----------

# The app runs as this account, which has no role at all: it calls no Google
# API. The default compute account has Editor on the whole project, and a
# server that reads uploaded files must not run as it
resource "google_service_account" "runtime" {
  account_id   = "${var.service_name}-run"
  display_name = "Cistergraphia runtime (no role)"
}

# The Deploy workflow becomes this account. It may do three things: push to
# the one repository, deploy a revision of the one service, and let the
# service run as the runtime account
resource "google_service_account" "deployer" {
  account_id   = "${var.service_name}-deploy"
  display_name = "Cistergraphia deployer (GitHub Actions)"
}

resource "google_artifact_registry_repository_iam_member" "deployer_pushes" {
  location   = google_artifact_registry_repository.images.location
  repository = google_artifact_registry_repository.images.name
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.deployer.member
}

resource "google_cloud_run_v2_service_iam_member" "deployer_deploys" {
  location = google_cloud_run_v2_service.web.location
  name     = google_cloud_run_v2_service.web.name
  role     = "roles/run.developer"
  member   = google_service_account.deployer.member
}

resource "google_service_account_iam_member" "deployer_runs_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.deployer.member
}

# ---------- GitHub Actions, without a key ----------

# A workflow run from the one repository proves who it is with its OpenID
# token and becomes the deployer. Nothing is made, stored or rotated
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.api]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }
  attribute_condition = "assertion.repository == \"${var.github_repository}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_becomes_deployer" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

# ---------- The service ----------

# One vCPU and three threads, as config/puma.rb runs it: a request is
# CPU-bound Ruby for up to 1.3 s, and three share the core inside Puma before
# a second instance starts. No instance when nobody reads; three at most, so
# the bill is bounded. The CPU is given only while a request runs, with a
# boost at startup: the first reader of the day waits a few seconds, and an
# idle instance costs nothing.
resource "google_cloud_run_v2_service" "web" {
  name                = var.service_name
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false # nothing is stored in it: a destroy loses no plate

  template {
    service_account                  = google_service_account.runtime.email
    timeout                          = "60s"
    max_instance_request_concurrency = 3

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    containers {
      # Google's hello image, until the Deploy workflow ships the first real one
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      env {
        name  = "RACK_ENV"
        value = "production"
      }
      env {
        name  = "PUMA_THREADS"
        value = "3"
      }
      env {
        name  = "WEB_CONCURRENCY"
        value = "0"
      }
    }
  }

  lifecycle {
    # The Deploy workflow's: the image it ships, and the marks gcloud leaves
    ignore_changes = [
      template[0].containers[0].image,
      template[0].revision,
      client,
      client_version,
    ]
  }

  depends_on = [google_project_service.api]
}

resource "google_cloud_run_v2_service_iam_member" "everyone_reads" {
  location = google_cloud_run_v2_service.web.location
  name     = google_cloud_run_v2_service.web.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
