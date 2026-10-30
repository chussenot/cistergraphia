# What tells you, before the bill does: a budget on the project with
# warnings at half, at nine tenths and at the line, by spend and by forecast;
# an alert when the service answers with errors; an alert when every instance
# has been busy for five minutes, which is either success or abuse. All of it
# goes to one address, and none of it is made without one.
#
# The budget warns; it stops nothing. The caps are elsewhere: max_instances
# (gcp.tf), the rate limit and the Worker's daily allowance (cloudflare.tf).
# The kill switch is one command (docs/serving.md).

locals {
  alerted  = var.alert_email != "" ? 1 : 0
  budgeted = var.alert_email != "" && var.billing_account_id != "" ? 1 : 0
}

resource "google_monitoring_notification_channel" "email" {
  count = local.alerted

  display_name = "Cistergraphia alerts"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }

  depends_on = [google_project_service.api]
}

resource "google_billing_budget" "monthly" {
  count = local.budgeted

  billing_account = var.billing_account_id
  display_name    = "Cistergraphia: ${var.monthly_budget} ${var.budget_currency} a month"

  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.monthly_budget)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.email[0].id]
    disable_default_iam_recipients   = false
  }

  depends_on = [google_project_service.api]
}

resource "google_monitoring_alert_policy" "errors" {
  count = local.alerted

  display_name = "Cistergraphia: the service answers with errors"
  combiner     = "OR"

  conditions {
    display_name = "More than ten 5xx answers in five minutes"
    condition_threshold {
      filter = join(" AND ", [
        "resource.type = \"cloud_run_revision\"",
        "resource.labels.service_name = \"${var.service_name}\"",
        "metric.type = \"run.googleapis.com/request_count\"",
        "metric.labels.response_code_class = \"5xx\"",
      ])
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "0s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.service_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email[0].id]

  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "at_the_cap" {
  count = local.alerted

  display_name = "Cistergraphia: every instance busy for five minutes (success, or abuse)"
  combiner     = "OR"

  conditions {
    display_name = "${var.max_instances} active instances, five minutes running"
    condition_threshold {
      filter = join(" AND ", [
        "resource.type = \"cloud_run_revision\"",
        "resource.labels.service_name = \"${var.service_name}\"",
        "metric.type = \"run.googleapis.com/container/instance_count\"",
        "metric.labels.state = \"active\"",
      ])
      comparison      = "COMPARISON_GT"
      threshold_value = var.max_instances - 1
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MAX"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.service_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email[0].id]

  alert_strategy {
    auto_close = "1800s"
  }
}
