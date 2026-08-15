# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The packet-level half of "nothing leaves except through the proxy".
#
# services/network/routes removed the ways out. This removes the permission
# to use one — a route is a path, a rule is an authorisation, and closing
# only one leaves the other as the single point of failure.
#
# THE AWS TRAP IS THE MIRROR OF THE GCP ONE. A GCP network with no rules
# permits all egress through an implied rule. An AWS security group created
# without an egress block gets one anyway: the provider adds allow-all
# outbound, because that is what the API does. So "we wrote no egress rule"
# is an open group here too, reached by a different route.
#
# Every group below states its egress explicitly, including the ones whose
# answer is "none".

locals {
  # Interface endpoints put an ENI in the VPC for an AWS service, which is
  # how a private subnet reaches the API without crossing the internet —
  # the counterpart of GCP's private Google access.
  #
  # ssm/ssmmessages/ec2messages are Session Manager: the way an operator
  # reaches an instance under `access.method = control-plane-tunnel`, with
  # no bastion and no port 22 reachable.
  # ecr.api/ecr.dkr and logs are what a node needs to pull an image and say
  # anything about it.
  default_endpoints = [
    "ssm", "ssmmessages", "ec2messages",
    "ecr.api", "ecr.dkr", "logs", "sts",
  ]

  endpoints = var.interface_endpoints == null ? local.default_endpoints : var.interface_endpoints
}

# ── the workload: may reach the proxy, and the endpoints, and nothing ────

resource "aws_security_group" "workload" {
  # checkov:skip=CKV2_AWS_5: Attached by services/k8s/nodes, which depends on
  # this unit — checkov cannot see across the module boundary. The caveat is
  # real and worth stating: nothing HERE forces that consumer to exist, so a
  # group with no members is a possible state. It is also a harmless one, and
  # the reverse arrangement — defining groups next to the things they attach
  # to — is what produces the estate where nobody can answer "who may reach
  # the internet?" without reading every module.
  name        = "${var.name}-workload"
  description = "Nodes pods run on. Egress to the proxy and the VPC endpoints only."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-workload" })

  lifecycle {
    create_before_destroy = true
  }
}

# The workload's ONLY route off its own subnet. The proxy's group, on the
# proxy's port — not a CIDR, so a machine that acquires the address later
# without the group still cannot be reached this way.
resource "aws_vpc_security_group_egress_rule" "workload_to_proxy" {
  security_group_id = aws_security_group.workload.id
  description       = "To the egress proxy, on the proxy port. The only way out."

  referenced_security_group_id = aws_security_group.proxy.id
  ip_protocol                  = "tcp"
  from_port                    = var.proxy_port
  to_port                      = var.proxy_port
}

# The AWS API over private addresses. Without this a node cannot pull an
# image, cannot log, and cannot be reached by Session Manager — and the
# obvious remedy for those symptoms is a NAT on the workload subnet, which
# is the hole this design exists to avoid.
resource "aws_vpc_security_group_egress_rule" "workload_to_endpoints" {
  security_group_id = aws_security_group.workload.id
  description       = "To the VPC endpoints: image pull, logs, Session Manager."

  referenced_security_group_id = aws_security_group.endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

# Node to node, pod to pod. A cluster whose nodes cannot reach each other
# does not form, and the failure presents as a control plane problem.
resource "aws_vpc_security_group_ingress_rule" "workload_internal" {
  security_group_id = aws_security_group.workload.id
  description       = "Node to node, within the cluster."

  referenced_security_group_id = aws_security_group.workload.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "workload_internal" {
  security_group_id = aws_security_group.workload.id
  description       = "Node to node, within the cluster."

  referenced_security_group_id = aws_security_group.workload.id
  ip_protocol                  = "-1"
}

# From the load balancer only. Not from the VPC, and not from a CIDR: the
# load balancer's group is the boundary, so nothing else that happens to
# sit in the same range can reach a workload port.
resource "aws_vpc_security_group_ingress_rule" "workload_from_lb" {
  security_group_id = aws_security_group.workload.id
  description       = "From the load balancer, to the node port range."

  referenced_security_group_id = aws_security_group.lb.id
  ip_protocol                  = "tcp"
  from_port                    = var.node_port_range[0]
  to_port                      = var.node_port_range[1]
}

# ── the proxy: the one thing that reaches the internet ──────────────────

resource "aws_security_group" "proxy" {
  # checkov:skip=CKV2_AWS_5: Attached by services/vms/proxy. See the workload
  # group above for why the groups live together rather than beside their
  # members.
  name        = "${var.name}-proxy"
  description = "Egress proxy fleet. The only group permitted to reach the internet."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-proxy" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "proxy_from_workload" {
  security_group_id = aws_security_group.proxy.id
  description       = "From the workload nodes, on the proxy port."

  referenced_security_group_id = aws_security_group.workload.id
  ip_protocol                  = "tcp"
  from_port                    = var.proxy_port
  to_port                      = var.proxy_port
}

# Deliberately not "all". A proxy that can open any port is a tunnel out
# for everything that can reach it, which is most of the estate.
resource "aws_vpc_security_group_egress_rule" "proxy_to_internet" {
  for_each = toset([for p in var.proxy_egress_ports : tostring(p)])

  security_group_id = aws_security_group.proxy.id
  description       = "To the internet, on port ${each.value}."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = tonumber(each.value)
  to_port     = tonumber(each.value)
}

# ── the load balancer: the only public-facing thing, in production ──────

resource "aws_security_group" "lb" {
  # checkov:skip=CKV2_AWS_5: Attached by the load balancer the cluster creates
  # from a Service of type LoadBalancer, which terraform never sees at all.
  name        = "${var.name}-lb"
  description = "Load balancer front end. The only inbound path from outside the VPC."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-lb" })

  lifecycle {
    create_before_destroy = true
  }
}

# WHO MAY REACH THE LOAD BALANCER IS A PER-ENVIRONMENT DECISION, and it is
# the one the brief names explicitly: only production is public. Staging
# passes its own ranges, so the same module produces an internal front end
# there without a second code path to keep in step.
resource "aws_vpc_security_group_ingress_rule" "lb_ingress" {
  for_each = { for idx, cidr in var.lb_ingress_cidrs : tostring(idx) => cidr }

  security_group_id = aws_security_group.lb.id
  description       = "Inbound to the load balancer from ${each.value}."

  cidr_ipv4   = each.value
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

resource "aws_vpc_security_group_egress_rule" "lb_to_workload" {
  security_group_id = aws_security_group.lb.id
  description       = "To the workload nodes, on the node port range."

  referenced_security_group_id = aws_security_group.workload.id
  ip_protocol                  = "tcp"
  from_port                    = var.node_port_range[0]
  to_port                      = var.node_port_range[1]
}

# ── the endpoints: how a private subnet reaches AWS ─────────────────────

resource "aws_security_group" "endpoints" {
  name        = "${var.name}-endpoints"
  description = "VPC interface endpoints. Reachable from the workload, reaches nothing."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-endpoints" })

  lifecycle {
    create_before_destroy = true
  }
}

# No egress rule at all, and that is the point: an endpoint ENI answers,
# it does not initiate. The provider would have added allow-all outbound
# had the group been declared with an inline egress block and left empty.
resource "aws_vpc_security_group_ingress_rule" "endpoints_from_workload" {
  security_group_id = aws_security_group.endpoints.id
  description       = "From the workload nodes, HTTPS."

  referenced_security_group_id = aws_security_group.workload.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.endpoints)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.workload_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name}-${each.value}" })
}

# S3 is a gateway endpoint, not an interface one: it attaches to route
# tables rather than putting an ENI in a subnet. It goes on the workload
# tables — the ones with no default route — because without it a node
# cannot reach S3 at all, and ECR stores every image layer there.
resource "aws_vpc_endpoint" "s3" {
  count = var.s3_endpoint_enabled ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.workload_route_table_ids

  tags = merge(var.tags, { Name = "${var.name}-s3" })
}
