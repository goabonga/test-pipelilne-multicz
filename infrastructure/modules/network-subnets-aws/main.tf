# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The same three purposes as the GCP module, with one structural
# difference: an AWS subnet lives in a single availability zone, so each
# purpose becomes one subnet per zone. Staging with one zone gets three
# subnets; production with three gets nine.
#
#   workload   where pods run. No NAT, no route out. Its only way off the
#              network is the proxy, and that is enforced by what
#              services/network/routes does NOT create for it.
#   proxy      the Squid fleet. The one purpose with a path to the internet.
#   lb         the load balancer front-end.

locals {
  # Each purpose's range is split evenly across the zones. One zone takes
  # the range whole (newbits 0); three zones need two extra bits, which
  # yields four blocks of which three are used — the spare is deliberate
  # headroom for a fourth zone rather than a tight fit that forces a
  # renumber the day one is added.
  newbits = var.zones == null ? 0 : (length(var.zones) <= 1 ? 0 : ceil(log(length(var.zones), 2)))

  # One entry per (purpose, zone). The key is what every downstream unit
  # refers to, so it has to be stable: renaming a subnet in the config
  # moves resources, and reordering the zone list must not.
  subnets = merge([
    for name, cfg in var.subnets : {
      for i, zone in var.zones :
      "${name}-${zone}" => {
        short   = name
        purpose = cfg.purpose
        zone    = zone
        cidr    = cidrsubnet(cfg.cidr, local.newbits, i)
      }
    }
  ]...)

  workload_names = [for k, v in var.subnets : k if v.purpose == "workload"]
}

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id            = var.vpc_id
  cidr_block        = each.value.cidr
  availability_zone = each.value.zone

  # NEVER. This is the AWS equivalent of an external IP on a GCP instance:
  # it hands a public address to anything launched here, which is a route
  # to the internet that does not pass the proxy and does not appear in any
  # route table a reviewer reads.
  #
  # AWS defaults it to false for subnets created this way, so this line
  # changes nothing today. It is here because the default is a default —
  # it can be flipped in the console by someone solving an unrelated
  # problem, and terraform would then quietly restore it on the next apply
  # only if the attribute is stated. Unstated, the drift persists.
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name    = "${var.name}-${each.key}"
      Purpose = each.value.purpose
    },
    # EKS finds subnets by tag, not by argument. Without these, a Service of
    # type LoadBalancer fails with "could not find any suitable subnets",
    # and the usual fix found by searching is to make the subnets public.
    #
    # internal-elb on everything private; elb only on the load balancer
    # subnets, which is what keeps an internet-facing load balancer from
    # being placeable in the workload subnet at all.
    each.value.purpose == "public-lb"
    ? { "kubernetes.io/role/elb" = "1" }
    : { "kubernetes.io/role/internal-elb" = "1" },
  )
}
