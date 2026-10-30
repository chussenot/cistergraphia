output "service_url" {
  description = "The service's own address, which the Deploy workflow smoke-tests"
  value       = google_cloud_run_v2_service.web.uri
}

output "site_url" {
  description = "Where readers go: the domain through the front door, or the service's own address"
  value       = var.domain != "" ? "https://${var.domain}" : google_cloud_run_v2_service.web.uri
}

output "github_variables" {
  description = "Set these on the repository's production environment (Settings, Environments, production, Variables); the Deploy workflow runs once they exist. SITE_URL is where it smoke-tests: through the front door, which the service's own address refuses"
  value = {
    GCP_PROJECT_ID                 = var.project_id
    GCP_REGION                     = var.region
    GCP_SERVICE_ACCOUNT            = google_service_account.deployer.email
    GCP_WORKLOAD_IDENTITY_PROVIDER = google_iam_workload_identity_pool_provider.github.name
    SITE_URL                       = var.domain != "" ? "https://${var.domain}" : google_cloud_run_v2_service.web.uri
  }
}
