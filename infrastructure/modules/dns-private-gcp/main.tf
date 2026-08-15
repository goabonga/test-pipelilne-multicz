# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The internal zone.
#
# A private zone is visible only to the networks named below. That
# association is not a convenience — it is the whole mechanism: a private
# zone with no network attached resolves for nobody, and creates cleanly
# while doing so. The failure surfaces as every internal name being
# NXDOMAIN, which reads as a records problem.

resource "google_dns_managed_zone" "this" {
  name        = var.name
  project     = var.project
  dns_name    = "${var.domain}."
  description = "Internal names for ${var.environment}. Resolves only inside the VPC."

  visibility = "private"

  private_visibility_config {
    dynamic "networks" {
      for_each = var.networks
      content {
        network_url = networks.value
      }
    }
  }

  labels = merge({ environment = var.environment }, var.tags)

  lifecycle {
    precondition {
      condition     = length(var.networks) > 0
      error_message = "A private zone with no network attached resolves for nobody, and creates cleanly while doing so — the failure shows up as every internal name being NXDOMAIN."
    }
  }
}

resource "google_dns_record_set" "this" {
  for_each = var.records

  project      = var.project
  managed_zone = google_dns_managed_zone.this.name
  name         = "${each.key}.${var.domain}."
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.values
}
