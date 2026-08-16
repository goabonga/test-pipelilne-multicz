---
icon: lucide/server-cog
---

# For DevOps

Two environments, two clouds, and one rule that shapes everything else:
**nothing leaves the network except through the egress proxy.**

| | staging | production |
|---|---|---|
| cloud | GCP | AWS |
| region | `europe-west1` | `eu-west-3` |
| zones | 1 | 3 |
| load balancer | internal | **public** |
| Kubernetes API | private | private |
| HA | off | on |

The only asymmetry that is deliberate policy rather than sizing is
`public_load_balancer`. It decides who may reach the load balancer serving
the api and the ssr. It says nothing about the Kubernetes API, which is
private in both — two different front doors, and conflating them is how one
gets opened while somebody is thinking about the other.

## How traffic leaves

```
workload subnet      no default route, no NAT, no public addresses
      │              only permitted destination: the proxy, on 3128
      ▼
egress proxy         Squid, deny-by-default allow-list of destinations
      │
      ▼
NAT                  translates for the proxy subnet ONLY
      │
      ▼
reserved addresses   what external services allow-list
```

Four units, each closing a different half. `routes` removes the path;
`firewall` removes the permission; `vms/proxy` decides what may be reached;
`nat` translates for the egress subnets only. **Any one of them alone can
be undone by a single line elsewhere, and each failure works perfectly
afterwards** — which is why they are separate and why each has tests that
assert an absence.

Both clouds are open by default in their own way: GCP's implied rules allow
all egress, and an AWS security group declared without an egress block is
given allow-all outbound by the provider. On both, "not configured yet" is
an open state that looks exactly like a closed one.

## Deploying

Nothing is applied by pushing. The flow is:

1. A push to `main` runs `ci`.
2. `infra-plan` runs after it, plans each environment, and if anything
   differs, force-pushes to `deploy/<env>-<version>` and opens a PR with
   the plan attached as an artifact.
3. Approving and merging that PR runs `infra-apply`, which applies, tags
   and releases `configs-<env>`.

So the reviewed artefact is the plan, and the thing that applies is the
thing that was reviewed. `configs-<env>` versions describe **what is
actually live**, not what the repository contains — that distinction is the
reason they are versioned separately from everything else.

## First-time setup

Two steps, both run by hand with elevated credentials, both once per cloud:

```bash
make infra-bootstrap CLOUD=gcp BUCKET=shomer-tfstate PROJECT=... LOCATION=EU
make infra-oidc CLOUD=gcp
```

The first creates the state bucket — Terraform cannot keep its state in a
bucket Terraform has not created. The second creates the CI identity and
sets the GitHub variables that point at it.

**Nothing either produces is a secret.** A role ARN, a workload identity
provider path and a service account email are identifiers, useless without
a token GitHub will only mint for this repository. There is no key to
store, rotate or leak.

The two identities are separate on purpose: plan is read-only and runs on
every push with nobody watching; apply runs only after a deploy PR is
merged. Plan is read-only on infrastructure and read-write on **state** —
a plan against a remote backend takes a lock, so a genuinely read-only
identity cannot plan at all.

## What is enabled

The seven network units are on. `vms/proxy`, `k8s/cluster`, `k8s/nodes`
and both DNS zones are off, waiting on four values the apply identity
cannot create for itself:

| config key | needs |
|---|---|
| `vms.proxy.image_id` | a Debian AMI in the region |
| `k8s.cluster.cluster_role_arn` | the EKS control plane role |
| `k8s.nodes.node_role_arn` | the node role |
| `k8s.cluster` KMS key | envelope encryption for secrets |

They are values rather than code because the apply identity deliberately
holds no IAM or KMS rights — granting it those would hand the apply path a
route to privilege escalation that no reviewer of a Terraform plan would
see.

## Parking an environment

See [teardown](teardown.md).
