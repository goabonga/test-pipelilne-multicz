# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The egress proxy fleet, and the only thing in this network permitted to
# reach the internet.
#
# Everything before this unit arranged for traffic to arrive here. This
# decides what happens to it, and the answer is a deny-by-default allow
# list — because a proxy that forwards anything is a router with extra
# steps: it satisfies "traffic leaves through one place" while giving up
# the reason that was worth arranging.
#
# The instances have no external address. They reach the internet through
# the NAT, which is the only reason the reserved egress addresses are what
# the world sees.

locals {
  # Two in production, one in staging. HA here is not about load — one
  # instance serves the traffic — it is about a proxy restart not being an
  # outage for everything behind it.
  size = var.ha ? var.ha_size : 1

  squid_conf = templatefile("${path.module}/templates/squid.conf.tftpl", {
    port            = var.port
    client_cidrs    = var.client_cidrs
    allowed_domains = var.allowed_domains
  })

  # Derived rather than read back from the resource. The format is fixed —
  # <account_id>@<project>.iam.gserviceaccount.com — and the attribute is
  # computed, so building the template from it would make "does the fleet
  # run as its own identity?" unanswerable at plan and in tests.
  sa_email = "${var.name}-sa@${var.project}.iam.gserviceaccount.com"

  startup = templatefile("${path.module}/templates/startup.sh.tftpl", {
    squid_conf = local.squid_conf
    port       = var.port
  })
}

# A dedicated identity with nothing attached. The default compute service
# account carries project editor in most projects, so an instance that
# borrows it can read every bucket and change every resource — from a host
# whose entire job is to talk to the internet on behalf of others.
resource "google_service_account" "proxy" {
  project      = var.project
  account_id   = "${var.name}-sa"
  display_name = "Egress proxy"
  description  = "Runs the Squid fleet. Deliberately holds no project roles."
}

resource "google_compute_instance_template" "proxy" {
  project     = var.project
  region      = var.region
  name_prefix = "${var.name}-"
  description = "Egress proxy. Replaced rather than edited — the config lives in this template."

  machine_type = var.machine_type

  disk {
    source_image = var.image
    auto_delete  = true
    boot         = true
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-balanced"
  }

  network_interface {
    subnetwork = var.subnetwork
    # NO access_config BLOCK. Its presence is what assigns an external
    # address, and an external address is a way to the internet that
    # bypasses the NAT — so the proxies would still work, and the addresses
    # the world sees would silently stop being the reserved ones.
  }

  # The tag is a capability: services/network/routes and
  # services/network/firewall both key on it, so carrying it is what grants
  # this instance the internet.
  tags = [var.proxy_tag]

  service_account {
    email = local.sa_email
    # Least privilege at the scope layer too. cloud-platform would let any
    # process on the box use the full API surface the account is granted;
    # these two cover writing logs and metrics and nothing else.
    scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
  }

  depends_on = [google_service_account.proxy]

  metadata = {
    startup-script = local.startup
    # Password authentication and metadata-managed keys are both ways onto
    # the box that do not pass IAM. The tunnel is the only intended path.
    block-project-ssh-keys = "TRUE"
    enable-oslogin         = "TRUE"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  labels = var.tags

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = length(var.allowed_domains) > 0
      error_message = "The proxy needs an explicit destination allow-list. An empty one denies everything, which is safe and useless; there is no permissive default here on purpose."
    }

    precondition {
      condition     = length(var.client_cidrs) > 0
      error_message = "No client ranges: nothing would be permitted to use the proxy, and the workloads behind it would fail with connection refused rather than with a policy message."
    }
  }
}

resource "google_compute_health_check" "proxy" {
  project = var.project
  name    = "${var.name}-health"

  # TCP against the listener rather than an HTTP probe: Squid answers HTTP
  # only to requests it accepts, so an HTTP check would have to be exempted
  # from the very policy this fleet exists to apply.
  tcp_health_check {
    port = var.port
  }

  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

resource "google_compute_region_instance_group_manager" "proxy" {
  project = var.project
  region  = var.region
  name    = "${var.name}-mig"

  base_instance_name = var.name
  target_size        = local.size

  version {
    instance_template = google_compute_instance_template.proxy.id
  }

  named_port {
    name = "proxy"
    port = var.port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.proxy.id
    initial_delay_sec = 120
  }

  update_policy {
    type           = "PROACTIVE"
    minimal_action = "REPLACE"
    # One at a time, and never below the current size. A rolling replace
    # that takes the fleet to zero briefly is an outage for everything
    # behind it, which in this design is everything.
    max_surge_fixed       = length(var.zones)
    max_unavailable_fixed = 0
  }

  distribution_policy_zones = var.zones
}

# The address the workload's default route points at. Internal, so it is
# reachable only from inside the VPC.
resource "google_compute_region_backend_service" "proxy" {
  project = var.project
  region  = var.region
  name    = "${var.name}-backend"

  load_balancing_scheme = "INTERNAL"
  protocol              = "TCP"
  health_checks         = [google_compute_health_check.proxy.id]

  backend {
    group = google_compute_region_instance_group_manager.proxy.instance_group
  }
}

resource "google_compute_forwarding_rule" "proxy" {
  project = var.project
  region  = var.region
  name    = "${var.name}-ilb"

  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.proxy.id
  network               = var.network_id
  subnetwork            = var.subnetwork
  ports                 = [tostring(var.port)]

  # This is what makes the forwarding rule usable as a route next hop,
  # which is how services/network/routes sends the workload here.
  allow_global_access = false
}
