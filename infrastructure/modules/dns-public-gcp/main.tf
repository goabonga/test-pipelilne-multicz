# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The public zone — the only thing in this infrastructure that the internet
# is meant to read.
#
# Everything else here is private, so this zone is the one place where a
# mistake is visible to everyone immediately and permanently: DNS is
# cached, and a record published by accident is out there for its TTL
# whatever is done next.
#
# Two guards follow from that. Private addresses are refused, because a
# public zone naming 10.x tells the world the shape of an internal network
# for no benefit — the name does not resolve usefully for anyone outside
# it. And DNSSEC is on, because a zone serving the one public entry point
# to an otherwise private estate is worth being unable to forge.

resource "google_dns_managed_zone" "this" {
  name        = var.name
  project     = var.project
  dns_name    = "${var.domain}."
  description = "Public names for ${var.environment}. Only the load balancer belongs here."

  visibility = "public"

  dnssec_config {
    state = var.dnssec ? "on" : "off"
  }

  labels = merge({ environment = var.environment }, var.tags)
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
